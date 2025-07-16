import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import 'errors.dart';

/// Load the native libraries required for braid to function,
/// fetching ones shipped with the application from [baseDirectory]
///
/// This function **must** be called before any other braid
/// features can be used
///
/// In case of failure, a [BraidInitializationException] is thrown
void loadNatives(String baseDirectory, {BraidNatives? natives}) {
  natives ??= BraidNatives.defaultForPlatform;
  BraidNatives._activeLibraries = natives._load(baseDirectory);
}

// ---

typedef NativesBundle = ({BraidNatives spec, DynamicLibrary glfw, DynamicLibrary freetype, DynamicLibrary harfbuzz});

class BraidNatives {
  static const linux = BraidNatives(
    glfw: './libglfw.so.3',
    freetype: 'libfreetype.so',
    harfbuzz: 'libharfbuzz.so.0',
    subdirectory: 'linux',
  );

  static const windows = BraidNatives(
    glfw: './glfw3.dll',
    freetype: './freetype-6.dll',
    harfbuzz: './harfbuzz.dll',
    subdirectory: 'windows',
  );

  static NativesBundle? _activeLibraries;

  final String glfw, freetype, harfbuzz;
  final String _subdirectory;

  const BraidNatives({required this.glfw, required this.freetype, required this.harfbuzz, required String subdirectory})
    : _subdirectory = subdirectory;

  BraidNatives copy({String? glfw, String? freetype, String? harfbuzz}) => BraidNatives(
    glfw: glfw ?? this.glfw,
    freetype: freetype ?? this.freetype,
    harfbuzz: harfbuzz ?? this.harfbuzz,
    subdirectory: _subdirectory,
  );

  NativesBundle _load(String baseDirectory) {
    final prevDir = Directory.current;
    try {
      Directory.current = absolute(join(baseDirectory, _subdirectory));

      return (
        spec: this,
        glfw: DynamicLibrary.open(glfw),
        freetype: DynamicLibrary.open(freetype),
        harfbuzz: DynamicLibrary.open(harfbuzz),
      );
    } on ArgumentError catch (error) {
      throw BraidInitializationException('failed to load natives', cause: error);
    } on PathNotFoundException catch (error) {
      throw BraidInitializationException('failed to load natives', cause: error);
    } finally {
      Directory.current = prevDir;
    }
  }

  /// Fetch the default set of natives to load for
  /// the current platform, or throw a [BraidInitializationException]
  /// if this platform is not supported
  static BraidNatives get defaultForPlatform {
    if (Platform.isLinux) return linux;
    if (Platform.isWindows) return windows;
    throw BraidInitializationException('unsupported platform: ${Platform.operatingSystem}');
  }

  /// The active set of native libraries used by braid
  static NativesBundle get activeLibraries {
    if (_activeLibraries case var activeLibraries?) {
      return activeLibraries;
    }

    throw BraidInitializationException('braid natives were not loaded');
  }
}

// ---

abstract interface class BraidResources {
  Future<String> loadShader(String path);
  Stream<Uint8List> loadFontFamily(String familyName);

  factory BraidResources.fonts(String fontDirectpry) = _FontOnlyResources;
  factory BraidResources.filesystem({required String fontDirectory, required String shaderDirectory}) =
      FilesystemResources;
}

class _FontOnlyResources implements BraidResources {
  final String fontDirectory;

  _FontOnlyResources(this.fontDirectory) {
    if (!FileSystemEntity.isDirectorySync(fontDirectory)) {
      throw BraidInitializationException('font directory $fontDirectory does not exist');
    }
  }

  @override
  Stream<Uint8List> loadFontFamily(String familyName) => Directory(join(fontDirectory, familyName))
      .list()
      .where((event) => event is File && const ['.otf', '.ttf'].contains(extension(event.path)))
      .cast<File>()
      .asyncMap((event) => event.readAsBytes());

  @override
  Future<String> loadShader(String path) =>
      throw UnimplementedError('font-only resources do not provide a way to load shaders');
}

class FilesystemResources extends _FontOnlyResources {
  final String shaderDirectory;

  FilesystemResources({required String fontDirectory, required this.shaderDirectory}) : super(fontDirectory) {
    if (!FileSystemEntity.isDirectorySync(shaderDirectory)) {
      throw BraidInitializationException('shader directory $shaderDirectory does not exist');
    }
  }

  @override
  Future<String> loadShader(String path) => File(join(shaderDirectory, path)).readAsString();
}
