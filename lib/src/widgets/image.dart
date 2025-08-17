import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/opengl.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';
import 'package:path/path.dart';

import '../context.dart';
import '../core/constraints.dart';
import '../core/math.dart';
import '../framework/instance.dart';
import '../framework/widget.dart';
import '../native/arena.dart';
import '../vertex_descriptors.dart';
import 'basic.dart';

abstract interface class ImageProvider {
  Object get cacheKey;
  Future<Image?> load();
}

// for now, intentionally only support png, jpeg and webp
Decoder? _decoderForBytes(Uint8List imageBytes) {
  final png = PngDecoder();
  if (png.isValidFile(imageBytes)) {
    return png;
  }

  final jpeg = JpegDecoder();
  if (jpeg.isValidFile(imageBytes)) {
    return jpeg;
  }

  final webp = WebPDecoder();
  if (webp.isValidFile(imageBytes)) {
    return webp;
  }

  return null;
}

class FileImageProvider implements ImageProvider {
  final File file;
  FileImageProvider(this.file);

  @override
  Object get cacheKey => absolute(file.path);

  @override
  Future<Image?> load() async {
    final imageBytes = await file.readAsBytes();

    final decoder = _decoderForBytes(imageBytes);
    if (decoder == null) {
      print('failed to decode image at ${absolute(file.path)}');
      return null;
    }

    return decoder.decode(imageBytes);
  }
}

class NetworkImageProvider implements ImageProvider {
  final Uri uri;
  NetworkImageProvider(this.uri);

  @override
  Object get cacheKey => uri;

  @override
  Future<Image?> load() async {
    final client = HttpClient();
    final response = await client.getUrl(uri).then((value) => value.close());

    final imageBytes = Uint8List.fromList(await response.expand((element) => element).toList());
    client.close();

    final decoder = _decoderForBytes(imageBytes);
    if (decoder == null) {
      print('failed to decode image from $uri');
      return null;
    }

    return decoder.decode(imageBytes);
  }
}

// ---

class ImageCache {
  final Map<Object, RenderImage> _cache = {};
  final Set<Object> _loadingKeys = {};

  final void Function(GlCall) _callScheduler;

  ImageCache(this._callScheduler);

  RenderImage? get(Object key) => _cache[key];
  bool isLoading(Object key) => _loadingKeys.contains(key);

  Future<void> load(ImageProvider provider) async {
    final key = provider.cacheKey;
    final added = _loadingKeys.add(key);
    assert(added, 'attempted to load the same image provider twice');

    var data = (await provider.load());
    if (data != null && (data.numChannels != 4 || data.format != Format.uint8)) {
      data =
          await (Command()
                ..image(data)
                ..convert(numChannels: 4, format: Format.uint8))
              .getImageThread();
    }

    final completer = Completer<void>();
    _callScheduler(
      GlCall(() {
        _cache[key] = RenderImage.allocate(data!);
        _loadingKeys.remove(key);

        completer.complete();
      }),
    );

    return completer.future;
  }
}

class RenderImage {
  final int textureId;
  final int width;
  final int height;

  RenderImage._({required this.textureId, required this.width, required this.height});

  factory RenderImage.allocate(Image data) {
    assert(data.numChannels == 4, 'RenderImage data must have 4 channels');
    assert(data.format == Format.uint8, 'RenderImage data must be in uint8 format');

    int textureId = 0;
    malloc.arena((arena) {
      final textureIdBuffer = arena<ffi.UnsignedInt>();
      gl.createTextures(glTexture2d, 1, textureIdBuffer);

      textureId = textureIdBuffer.value;

      final pixelBuffer = arena<ffi.Uint8>(data.lengthInBytes);
      pixelBuffer.asTypedList(data.lengthInBytes).setRange(0, data.lengthInBytes, data.buffer.asUint8List());

      // TODO: image wrapping behavior
      // gl.textureParameteri(textureId, glTextureWrapS, glRepeat);
      // gl.textureParameteri(textureId, glTextureWrapS, glRepeat);

      gl.textureStorage2D(textureId, 1, glRgba8, data.width, data.height);
      gl.textureSubImage2D(textureId, 0, 0, 0, data.width, data.height, glRgba, glUnsignedByte, pixelBuffer.cast());
    });

    return RenderImage._(textureId: textureId, width: data.width, height: data.height);
  }

  void draw(DrawContext ctx, double drawWidth, double drawHeight, ImageFilter filter, ImageWrap wrap) {
    final buffer = ctx.primitives.getBuffer(#renderImage, posUvVertexDescriptor, 'texture_fill');

    final filterMode = switch (filter) {
      ImageFilter.nearest => glNearest,
      ImageFilter.linear => glLinear,
    };

    gl.textureParameteri(textureId, glTextureMagFilter, filterMode);
    gl.textureParameteri(textureId, glTextureMinFilter, filterMode);

    buffer.program
      ..uniformMat4('uTransform', ctx.transform)
      ..uniformMat4('uProjection', ctx.projection)
      ..uniformSampler('uTexture', textureId, 0)
      ..use();

    final (uMax, vMax) = switch (wrap) {
      ImageWrap.stretch || ImageWrap.none => (1.0, 1.0),
      _ => (drawWidth / width, drawHeight / height),
    };

    final (quadWidth, quadHeight) = switch (wrap) {
      ImageWrap.none => (width.toDouble(), height.toDouble()),
      _ => (drawWidth, drawHeight),
    };

    final wrapMode = switch (wrap) {
      ImageWrap.none || ImageWrap.stretch || ImageWrap.clamp => glClampToEdge,
      ImageWrap.repeat => glRepeat,
      ImageWrap.mirroredRepeat => glMirroredRepeat,
    };

    gl.textureParameteri(textureId, glTextureWrapS, wrapMode);
    gl.textureParameteri(textureId, glTextureWrapT, wrapMode);

    buffer.clear();
    ctx.primitives.buildUvRect(buffer.vertex, quadWidth, quadHeight, uMax: max(uMax, 1), vMax: max(vMax, 1));

    buffer
      ..upload(dynamic: true)
      ..draw();
  }
}

enum ImageFilter { linear, nearest }

enum ImageWrap { none, stretch, clamp, repeat, mirroredRepeat }

class RawImage extends LeafInstanceWidget {
  final ImageProvider provider;
  final ImageFilter filter;
  final ImageWrap wrap;

  RawImage({super.key, required this.provider, this.filter = ImageFilter.nearest, this.wrap = ImageWrap.stretch});

  @override
  LeafWidgetInstance<InstanceWidget> instantiate() => RawImageInstance(widget: this);
}

class RawImageInstance extends LeafWidgetInstance<RawImage> {
  RenderImage? image;

  RawImageInstance({required super.widget});

  @override
  set widget(RawImage value) {
    if (widget.provider.cacheKey != value.provider.cacheKey) {
      markNeedsLayout();
    }

    super.widget = value;
  }

  @override
  void doLayout(Constraints constraints) {
    final cache = host!.imageCache;
    image = cache.get(widget.provider.cacheKey);

    if (image != null) {
      final size = AspectRatio.applyAspectRatio(constraints, Size(image!.width.toDouble(), image!.height.toDouble()));
      transform.setSize(size);
    } else {
      if (!cache.isLoading(widget.provider.cacheKey)) {
        cache.load(widget.provider).then((value) => markNeedsLayout());
      }

      transform.setSize(constraints.minSize);
    }
  }

  @override
  void draw(DrawContext ctx) {
    image?.draw(ctx, transform.width, transform.height, widget.filter, widget.wrap);
  }

  @override
  double measureIntrinsicWidth(double height) => image?.width.toDouble() ?? 0;

  @override
  double measureIntrinsicHeight(double width) => image?.height.toDouble() ?? 0;

  @override
  double? measureBaselineOffset() => null;
}
