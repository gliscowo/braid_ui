import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:math';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/diamond_gl.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math.dart';

import '../context.dart';
import '../core/math.dart';
import '../native/freetype.dart';
import '../native/harfbuzz.dart';
import '../vertex_descriptors.dart';
import 'text.dart';

final freetype = FreetypeLibrary(DynamicLibrary.open('libfreetype.so'));
final harfbuzz = HarfbuzzLibrary(DynamicLibrary.open('libharfbuzz.so.0'));

final Logger _logger = Logger('cutesy.text_handler');

class FontFamily {
  final List<Font> _allFonts = [];

  late final Font defaultFont;
  late final Font boldFont, italicFont, boldItalicFont;

  FontFamily(String familyName, int size) {
    final fontFiles = Directory('resources/font/$familyName')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.otf') || file.path.endsWith('.ttf'));

    for (final font in fontFiles) {
      _allFonts.add(Font(font.absolute.path, size));
    }

    Font Function() defaultAndWarn(String type) {
      return () {
        _logger.warning('Could not find a "$type" font in family $familyName');
        return defaultFont;
      };
    }

    defaultFont = _allFonts.firstWhere((font) => !font.bold && !font.italic, orElse: () => _allFonts.first);
    boldFont = _allFonts.firstWhere((font) => font.bold && !font.italic, orElse: defaultAndWarn('bold'));
    italicFont = _allFonts.firstWhere((font) => !font.bold && font.italic, orElse: defaultAndWarn('italic'));
    boldItalicFont = _allFonts.firstWhere((font) => font.bold && font.italic, orElse: defaultAndWarn('bold & italic'));
  }

  Font fontForStyle(TextStyle style) {
    if (style.bold && !style.italic) return boldFont;
    if (!style.bold && style.italic) return italicFont;
    if (style.bold && style.italic) return boldItalicFont;
    return defaultFont;
  }
}

class Font {
  static FT_Library? _ftInstance;
  static final List<int> _glyphTextures = [];
  static int _nextGlyphX = 1024, _nextGlyphY = 1024;
  static int _currentRowHeight = 0;

  late final Pointer<hb_font> _hbFont;
  late final FT_Face _ftFace;

  final Map<int, Glyph> _glyphs = {};
  final int size;

  late final bool bold, italic;

  Font(String path, this.size) {
    final nativePath = path.toNativeUtf8().cast<Char>();

    final face = malloc<FT_Face>();
    if (freetype.New_Face(_ftLibrary, nativePath, 0, face) != 0) {
      throw ArgumentError.value(path, 'path', 'Could not load font');
    }

    final faceStruct = face.value.ref;
    bold = faceStruct.style_flags & FT_STYLE_FLAG_BOLD != 0;
    italic = faceStruct.style_flags & FT_STYLE_FLAG_ITALIC != 0;

    _ftFace = face.value;
    freetype.Set_Pixel_Sizes(_ftFace, size, size);

    _hbFont = harfbuzz.ft_font_create_referenced(_ftFace);
    harfbuzz.ft_font_set_funcs(_hbFont);
    harfbuzz.font_set_scale(_hbFont, 64, 64);

    malloc.free(nativePath);
  }

  Glyph operator [](int index) => _glyphs[index] ?? _loadGlyph(index);

  // TODO consider switching to SDF rendering
  Glyph _loadGlyph(int index) {
    if (freetype.Load_Glyph(_ftFace, index, FT_LOAD_RENDER | FT_LOAD_TARGET_LCD | FT_LOAD_COLOR) != 0) {
      throw Exception('Failed to load glyph ${String.fromCharCode(index)}');
    }

    final width = _ftFace.ref.glyph.ref.bitmap.width ~/ 3;
    final pitch = _ftFace.ref.glyph.ref.bitmap.pitch;
    final rows = _ftFace.ref.glyph.ref.bitmap.rows;
    final (texture, u, v) = _allocateGlyphPosition(width, rows);

    final glyphPixels = _ftFace.ref.glyph.ref.bitmap.buffer.cast<Uint8>().asTypedList(pitch * rows);
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
      _ftFace.ref.glyph.ref.bitmap_left,
      _ftFace.ref.glyph.ref.bitmap_top,
    );
  }

  static (int, int, int) _allocateGlyphPosition(int width, int height) {
    if (_nextGlyphX + width >= 1024) {
      _nextGlyphX = 0;
      _nextGlyphY += _currentRowHeight + 2;
    }

    if (_nextGlyphY + height >= 1024) {
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
    gl.textureStorage2D(textureId, 8, glRgb8, 1024, 1024);

    // turns out that zero-initializing the texture
    // memory is actually very important to prevent
    // cross-sampling artifacts. why does this not happen
    // when running with renderdoc? who knows
    //
    // glisco, 28.09.2024
    final emptyBuffer = calloc<Char>(1024 * 1024 * 3);
    gl.textureSubImage2D(textureId, 0, 0, 0, 1024, 1024, glRgb, glUnsignedByte, emptyBuffer.cast());
    calloc.free(emptyBuffer);

    gl.textureParameteri(textureId, glTextureWrapS, glClampToEdge);
    gl.textureParameteri(textureId, glTextureWrapT, glClampToEdge);
    gl.textureParameteri(textureId, glTextureMinFilter, glLinear);
    gl.textureParameteri(textureId, glTextureMagFilter, glLinear);

    return textureId;
  }

  Pointer<hb_font> get hbFont => _hbFont;

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

      final u0 = (glyph.u / 1024), u1 = u0 + (glyph.width / 1024);
      final v0 = (glyph.v / 1024), v1 = v0 + (glyph.height / 1024);

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
