import 'dart:ffi' hide Size;
import 'dart:math';
import 'dart:typed_data';

import 'package:braid_ui/src/resources.dart';
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
import '../vertex_descriptors.dart';
import 'text.dart';

final freetype = FreetypeLibrary(DynamicLibrary.open(BraidNatives.activeLibraries.freetype));
final harfbuzz = HarfbuzzLibrary(DynamicLibrary.open(BraidNatives.activeLibraries.harfbuzz));

final Logger _logger = Logger('cutesy.text_handler');

class FontFamily {
  final Font defaultFont;
  final Font boldFont, italicFont, boldItalicFont;

  FontFamily(
    this.defaultFont,
    this.boldFont,
    this.italicFont,
    this.boldItalicFont,
  );

  @factory
  static Future<FontFamily> load(BraidResources resources, String familyName, int size) async {
    final fonts = await resources.loadFontFamily(familyName).map((fontBytes) => Font(fontBytes, size)).toList();

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

  Font fontForStyle(TextStyle style) {
    if (style.bold && !style.italic) return boldFont;
    if (!style.bold && style.italic) return italicFont;
    if (style.bold && style.italic) return boldItalicFont;
    return defaultFont;
  }
}

typedef _NativeFontResources = ({
  Pointer<hb_font> hbFont,
  FT_Face ftFace,
  Pointer<Uint8> fontMemory,
});

class Font {
  static const atlasSize = 1024;

  static final _finalizer = Finalizer<_NativeFontResources>((resources) {
    freetype.Done_Face(resources.ftFace);
    malloc.free(resources.ftFace);
    malloc.free(resources.fontMemory);
  });

  static FT_Library? _ftInstance;
  static final List<int> _glyphTextures = [];
  static int _nextGlyphX = atlasSize, _nextGlyphY = atlasSize;
  static int _currentRowHeight = 0;

  late final _NativeFontResources _nativeResources;

  final Map<int, Glyph> _glyphs = {};
  final int size;

  late final bool bold, italic;

  Font(Uint8List fontBytes, this.size) {
    final fontMemory = malloc<Uint8>(fontBytes.lengthInBytes);
    fontMemory.asTypedList(fontBytes.lengthInBytes).setRange(0, fontBytes.lengthInBytes, fontBytes);

    final face = malloc<FT_Face>();
    if (freetype.New_Memory_Face(_ftLibrary, fontMemory.cast(), fontBytes.lengthInBytes, 0, face) != 0) {
      throw ArgumentError('could not load font', 'fontBytes');
    }

    final faceStruct = face.value.ref;
    bold = faceStruct.style_flags & FT_STYLE_FLAG_BOLD != 0;
    italic = faceStruct.style_flags & FT_STYLE_FLAG_ITALIC != 0;

    final ftFace = face.value;
    freetype.Set_Pixel_Sizes(ftFace, size, size);

    final hbFont = harfbuzz.ft_font_create_referenced(ftFace);
    harfbuzz.ft_font_set_funcs(hbFont);
    harfbuzz.font_set_scale(hbFont, 64, 64);

    _nativeResources = (
      hbFont: hbFont,
      ftFace: ftFace,
      fontMemory: fontMemory,
    );

    _finalizer.attach(this, _nativeResources);
  }

  Glyph operator [](int index) => _glyphs[index] ?? _loadGlyph(index);

  // TODO consider switching to SDF rendering
  Glyph _loadGlyph(int index) {
    final ftFace = _nativeResources.ftFace;

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

    return _glyphs[index] = Glyph(
      texture,
      u,
      v,
      width,
      rows,
      ftFace.ref.glyph.ref.bitmap_left,
      ftFace.ref.glyph.ref.bitmap_top,
    );
  }

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
    gl.textureStorage2D(textureId, 8, glRgb8, atlasSize, atlasSize);

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

  Pointer<hb_font> get hbFont => _nativeResources.hbFont;

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
  final _cachedBuffers = <int, MeshBuffer<TextVertexFunction>>{};
  final GlProgram _program;

  final FontFamily _defaultFont;
  final Map<String, FontFamily> _fontStorage;

  TextRenderer(RenderContext context, this._defaultFont, Map<String, FontFamily> fontStorage)
      : _program = context.findProgram('text'),
        _fontStorage = Map.unmodifiable(fontStorage);

  FontFamily getFont(String? familyName) =>
      familyName == null ? _defaultFont : _fontStorage[familyName] ?? _defaultFont;

  Size sizeOf(Text text, double size) {
    if (!text.isShaped) text.shape(getFont);
    if (text.glyphs.isEmpty) return Size.zero;

    return Size(
      text.glyphs.map((e) => _hbToPixels(e.position.x + e.advance.x) * (size / e.font.size)).reduce(max),
      size,
    );
  }

  // TODO potentially include size in text style, actually do text layout :dies:
  void drawText(Text text, double size, Matrix4 transform, Matrix4 projection, {Color? color}) {
    if (!text.isShaped) text.shape(getFont);

    color ??= Color.white;
    _program
      ..uniformMat4('uTransform', transform)
      ..uniformMat4('uProjection', projection)
      ..use();

    final buffers = <int, MeshBuffer<TextVertexFunction>>{};
    MeshBuffer<TextVertexFunction> buffer(int texture) {
      return buffers[texture] ??= ((_cachedBuffers[texture]?..clear()) ??
          (_cachedBuffers[texture] = MeshBuffer(textVertexDescriptor, _program)));
    }

    final baseline = (size * .875).floor();
    for (final shapedGlyph in text.glyphs) {
      final glyph = shapedGlyph.font[shapedGlyph.index];
      final glyphColor = shapedGlyph.style.color ?? color;

      final scale = size / shapedGlyph.font.size, glyphScale = shapedGlyph.style.scale;

      final xPos = _hbToPixels(shapedGlyph.position.x) * scale + glyph.bearingX * scale;
      final yPos = _hbToPixels(shapedGlyph.position.y) * scale + baseline - glyph.bearingY * scale * glyphScale;

      final width = glyph.width * scale * glyphScale;
      final height = glyph.height * scale * glyphScale;

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

  int _hbToPixels(double hbUnits) => (hbUnits / 64).round();
}
