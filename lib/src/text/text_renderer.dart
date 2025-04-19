import 'dart:collection';
import 'dart:ffi' hide Size;
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../core/math.dart';
import '../native/freetype.dart';
import '../native/harfbuzz.dart';
import '../resources.dart';
import '../vertex_descriptors.dart';
import '../widgets/basic.dart';
import 'text_layout.dart';

final freetype = FreetypeLibrary(BraidNatives.activeLibraries.freetype);
final harfbuzz = HarfbuzzLibrary(BraidNatives.activeLibraries.harfbuzz);

final Logger _logger = Logger('cutesy.text_handler');
const _hbScale = 64;

@internal
int hbToPixels(num hbUnits) => (hbUnits / _hbScale).round();

class FontFamily {
  final Font defaultFont;
  final Font boldFont, italicFont, boldItalicFont;

  FontFamily(this.defaultFont, this.boldFont, this.italicFont, this.boldItalicFont);

  @factory
  static Future<FontFamily> load(BraidResources resources, String familyName) async {
    final fonts = await resources.loadFontFamily(familyName).map((fontBytes) => Font(fontBytes)).toList();

    Font warn(String type, Font font) {
      _logger.warning('Could not find a "$type" font in family $familyName');
      return font;
    }

    return FontFamily(
      fonts.firstWhere((font) => !font.bold && !font.italic, orElse: () => fonts.first),
      fonts.firstWhere((font) => font.bold && !font.italic, orElse: () => warn('bold', fonts.first)),
      fonts.firstWhere((font) => !font.bold && font.italic, orElse: () => warn('italic', fonts.first)),
      fonts.firstWhere((font) => font.bold && font.italic, orElse: () => warn('bold & italic', fonts.first)),
    );
  }

  Font fontForStyle(SpanStyle style) {
    final (bold, italic) = (style.bold, style.italic);

    if (bold && !italic) return boldFont;
    if (!bold && italic) return italicFont;
    if (bold && italic) return boldItalicFont;
    return defaultFont;
  }
}

typedef _NativeFontResources = ({Map<int, Pointer<hb_font>> hbFonts, FT_Face ftFace, Pointer<Uint8> fontMemory});

class Font {
  static const atlasSize = 2048;

  static final _finalizer = Finalizer<_NativeFontResources>((resources) {
    freetype.Done_Face(resources.ftFace);
    malloc.free(resources.fontMemory);

    for (final hbFont in resources.hbFonts.values) {
      harfbuzz.font_destroy(hbFont);
    }
  });

  static FT_Library? _ftInstance;
  static final List<int> _glyphTextures = [];
  static int _nextGlyphX = atlasSize, _nextGlyphY = atlasSize;
  static int _currentRowHeight = 0;

  // --- instance fields ---

  late final _NativeFontResources _nativeResources;

  final Map<(int, int), Glyph> _glyphs = {};

  late final bool bold, italic;

  Font(Uint8List fontBytes) {
    final fontMemory = malloc<Uint8>(fontBytes.lengthInBytes);
    fontMemory.asTypedList(fontBytes.lengthInBytes).setRange(0, fontBytes.lengthInBytes, fontBytes);

    final face = malloc<FT_Face>();
    if (freetype.New_Memory_Face(_ftLibrary, fontMemory.cast(), fontBytes.lengthInBytes, 0, face) != 0) {
      throw ArgumentError('could not load font', 'fontBytes');
    }

    final faceStruct = face.value.ref;
    bold = faceStruct.style_flags & FT_STYLE_FLAG_BOLD != 0;
    italic = faceStruct.style_flags & FT_STYLE_FLAG_ITALIC != 0;

    _nativeResources = (hbFonts: {}, ftFace: face.value, fontMemory: fontMemory);

    _finalizer.attach(this, _nativeResources);
  }

  double get lineHeight => _nativeResources.ftFace.ref.height / _nativeResources.ftFace.ref.units_per_EM;

  double get ascender => _nativeResources.ftFace.ref.ascender / _nativeResources.ftFace.ref.units_per_EM;
  double get descender => _nativeResources.ftFace.ref.descender / _nativeResources.ftFace.ref.units_per_EM;

  Glyph getGlyph(int index, double size) {
    final pixelSize = toPixelSize(size);
    return _glyphs[(index, pixelSize)] ?? _loadGlyph(index, pixelSize);
  }

  /// Retrieve a harfbuzz font instance configured
  /// for use at [size]
  Pointer<hb_font> getHbFont(double size) {
    final pixelSize = toPixelSize(size);
    return _nativeResources.hbFonts[pixelSize] ??= _createHbFont(pixelSize);
  }

  // TODO consider switching to SDF rendering
  Glyph _loadGlyph(int index, int size) {
    final ftFace = _nativeResources.ftFace;

    freetype.Set_Pixel_Sizes(ftFace, size, size);
    if (freetype.Load_Glyph(ftFace, index, FT_LOAD_RENDER | FT_LOAD_TARGET_LCD | FT_LOAD_COLOR) != 0) {
      throw Exception('Failed to load glyph ${String.fromCharCode(index)}');
    }

    final width = ftFace.ref.glyph.ref.bitmap.width ~/ 3;
    final pitch = ftFace.ref.glyph.ref.bitmap.pitch;
    final rows = ftFace.ref.glyph.ref.bitmap.rows;
    final (texture, u, v) = _allocateGlyphPosition(width, rows);

    final glyphPixels = ftFace.ref.glyph.ref.bitmap.buffer.cast<Uint8>().asTypedList(pitch * rows);
    final pixelBuffer = malloc<Uint8>(width * rows * 3);
    final pixels = pixelBuffer.asTypedList(width * rows * 3);

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < width; x++) {
        pixels[y * width * 3 + x * 3] = glyphPixels[y * pitch + x * 3];
        pixels[y * width * 3 + x * 3 + 1] = glyphPixels[y * pitch + x * 3 + 1];
        pixels[y * width * 3 + x * 3 + 2] = glyphPixels[y * pitch + x * 3 + 2];
      }
    }

    gl.pixelStorei(glUnpackAlignment, 1);
    gl.textureSubImage2D(texture, 0, u, v, width, rows, glRgb, glUnsignedByte, pixelBuffer.cast());

    malloc.free(pixelBuffer);

    return _glyphs[(index, size)] = Glyph(
      texture,
      u,
      v,
      width,
      rows,
      ftFace.ref.glyph.ref.bitmap_left,
      ftFace.ref.glyph.ref.bitmap_top,
    );
  }

  // ---

  /// Determine the pixel size at which glyphs for
  /// rendering at [renderSize] are baked
  // old impl for sadness:
  // ```dart
  // renderSize <= 12
  // ? renderSize.ceil()
  // : renderSize <= 20
  //     ? (renderSize / 2).ceil() * 2
  //     : (renderSize / 4).ceil() * 4
  // ```
  static int toPixelSize(double renderSize) => renderSize.ceil();

  static double compensateForGlyphSize(double renderSize) => renderSize / toPixelSize(renderSize);

  static (int, int, int) _allocateGlyphPosition(int width, int height) {
    if (_nextGlyphX + width >= atlasSize) {
      _nextGlyphX = 0;
      _nextGlyphY += _currentRowHeight + 2;
    }

    if (_nextGlyphY + height >= atlasSize) {
      _glyphTextures.add(_createGlyphAtlasTexture());
      _nextGlyphX = 0;
      _nextGlyphY = 0;
    }

    final textureId = _glyphTextures.last;
    final location = (textureId, _nextGlyphX, _nextGlyphY);

    _nextGlyphX += width + 2;
    _currentRowHeight = max(_currentRowHeight, height);

    return location;
  }

  static int _createGlyphAtlasTexture() {
    final texture = malloc<UnsignedInt>();
    gl.createTextures(glTexture2d, 1, texture);
    final textureId = texture.value;
    malloc.free(texture);

    gl.pixelStorei(glUnpackAlignment, 1);
    gl.textureStorage2D(textureId, 1, glRgb8, atlasSize, atlasSize);

    // turns out that zero-initializing the texture
    // memory is actually very important to prevent
    // cross-sampling artifacts. why does this not happen
    // when running with renderdoc? who knows
    //
    // glisco, 28.09.2024

    final emptyBuffer = calloc<Char>(atlasSize * atlasSize * 3);
    gl.textureSubImage2D(textureId, 0, 0, 0, atlasSize, atlasSize, glRgb, glUnsignedByte, emptyBuffer.cast());
    calloc.free(emptyBuffer);

    gl.textureParameteri(textureId, glTextureWrapS, glClampToEdge);
    gl.textureParameteri(textureId, glTextureWrapT, glClampToEdge);
    gl.textureParameteri(textureId, glTextureMinFilter, glLinear);
    gl.textureParameteri(textureId, glTextureMagFilter, glLinear);

    return textureId;
  }

  Pointer<hb_font> _createHbFont(int pixelSize) {
    freetype.Set_Pixel_Sizes(_nativeResources.ftFace, pixelSize, pixelSize);
    final hbFont = harfbuzz.ft_font_create_referenced(_nativeResources.ftFace);
    harfbuzz.ft_font_set_funcs(hbFont);
    harfbuzz.font_set_scale(hbFont, _hbScale, _hbScale);

    return hbFont;
  }

  static FT_Library get _ftLibrary {
    if (_ftInstance != null) return _ftInstance!;

    final ft = malloc<FT_Library>();
    if (freetype.Init_FreeType(ft) != 0) {
      throw 'Failed to initialize FreeType library';
    }

    return _ftInstance = ft.value;
  }
}

class Glyph {
  final int textureId;
  final int u, v;
  final int width, height;
  final int bearingX, bearingY;
  Glyph(this.textureId, this.u, this.v, this.width, this.height, this.bearingX, this.bearingY);
}

class TextRenderer {
  final _cachedBuffers = HashMap<int, MeshBuffer<TextVertexFunction>>();
  final GlProgram _textProgram;

  final Map<String, FontFamily> _fontStorage;
  FontFamily _defaultFont;
  int _fontStorageGeneration = 0;

  TextRenderer(RenderContext context, this._defaultFont, Map<String, FontFamily> fontStorage)
    : _textProgram = context.findProgram('text'),
      _fontStorage = fontStorage;

  /// Fetch the font family stored under [familyName], or return
  /// the default font if no such family exists
  FontFamily getFamily(String? familyName) =>
      familyName == null ? _defaultFont : _fontStorage[familyName] ?? _defaultFont;

  /// Add [family] to this renderer's repository of fonts
  /// and register it under [name].
  ///
  /// {@template braid.text.layout_invalidation}
  /// **This method can potentially invalidate the layout and
  /// shaping caches of paragraphs laid out using this renderer.**
  /// Thus, to prevent seeing outdated fonts in the application, it
  /// is important that all relevant paragraphs are subsequently
  /// updated using [layoutParagraph].
  /// {@endtemplate}
  void addFamily(String name, FontFamily family) {
    if (_fontStorage.containsKey(name)) throw ArgumentError.value(name, 'name', 'duplicate font name');

    _fontStorage[name] = family;
    _fontStorageGeneration++;
  }

  /// Update the default font of this text renderer
  ///
  /// {@macro braid.text.layout_invalidation}
  set defaultFont(FontFamily family) {
    _defaultFont = family;
    _fontStorageGeneration++;
  }

  // ---

  /// Lay out (and thus prepare for rendering) [text], wrapping lines
  /// longer than [maxWidth]. If infinite max width is given, only hard
  /// line breaks in the input text are wrapped.
  ///
  /// The returned [ParagraphMetrics] describe the computed size
  /// and baseline metrics
  ParagraphMetrics layoutParagraph(Paragraph text, double maxWidth) {
    if (!text.isLayoutCacheValid(_fontStorageGeneration, maxWidth)) {
      text.layout(getFamily, maxWidth, _fontStorageGeneration);
    }

    return text.metrics;
  }

  void drawText(
    Paragraph text,
    Alignment alignment,
    Size drawSpace,
    Matrix4 transform,
    Matrix4 projection, {
    DrawContext? debugCtx,
  }) {
    if (text.metrics.lineMetrics.isEmpty) return;

    final initialY =
        text.metrics.initialBaselineY.floor() + alignment.alignVertical(drawSpace.height, text.metrics.height);
    final lineOffsets =
        text.metrics.lineMetrics.map((e) => alignment.alignHorizontal(drawSpace.width, e.width)).toList();

    if (debugCtx != null) {
      final textSize = text.metrics;
      debugCtx.primitives.rect(textSize.width, textSize.height, Color.black.copyWith(a: .25), transform, projection);

      debugCtx.transform.scope((mat4) {
        mat4.translate(0.0, initialY.toDouble());
        debugCtx.primitives.rect(textSize.width, 1, Color.red, mat4, projection);
      });
    }

    _textProgram
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..use();

    final buffers = <int, MeshBuffer<TextVertexFunction>>{};
    MeshBuffer<TextVertexFunction> buffer(int texture) {
      return buffers[texture] ??=
          ((_cachedBuffers[texture]?..clear()) ??
              (_cachedBuffers[texture] = MeshBuffer(textVertexDescriptor, _textProgram)));
    }

    for (final shapedGlyph in text.glyphs) {
      // if (shapedGlyph.line >= lineOffsets.length) continue;

      final glyphStyle = text.styleFor(shapedGlyph);
      final glyph = shapedGlyph.font.getGlyph(shapedGlyph.index, glyphStyle.fontSize);
      final glyphColor = glyphStyle.color;

      final renderScale = Font.compensateForGlyphSize(glyphStyle.fontSize);

      final xPos = shapedGlyph.position.x * renderScale + glyph.bearingX * renderScale + lineOffsets[shapedGlyph.line];
      final yPos = shapedGlyph.position.y * renderScale + initialY - glyph.bearingY * renderScale;

      final width = glyph.width * renderScale;
      final height = glyph.height * renderScale;

      final u0 = (glyph.u / Font.atlasSize), u1 = u0 + (glyph.width / Font.atlasSize);
      final v0 = (glyph.v / Font.atlasSize), v1 = v0 + (glyph.height / Font.atlasSize);

      buffer(glyph.textureId)
        ..vertex(xPos, yPos, u0, v0, glyphColor)
        ..vertex(xPos, yPos + height, u0, v1, glyphColor)
        ..vertex(xPos + width, yPos, u1, v0, glyphColor)
        ..vertex(xPos + width, yPos, u1, v0, glyphColor)
        ..vertex(xPos, yPos + height, u0, v1, glyphColor)
        ..vertex(xPos + width, yPos + height, u1, v1, glyphColor);
    }

    gl.blendFunc(glSrc1Color, glOneMinusSrc1Color);

    buffers.forEach((texture, mesh) {
      mesh.program.uniformSampler('sText', texture, 0);
      mesh
        ..upload(dynamic: true)
        ..draw();
    });

    gl.blendFunc(glSrcAlpha, glOneMinusSrcAlpha);
  }
}
