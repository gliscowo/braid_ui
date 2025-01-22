import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import 'core/app.dart';

/// Load the native libraries required for braid to function,
/// fetching ones shipped with the application from [baseDirectory]
///
/// This function **must** be called before any other braid
/// features can be used
///
/// In case of failure, a [BraidInitializationException] is thrown
void loadNatives(
  String baseDirectory, {
  BraidNatives? natives,
}) {
  natives ??= BraidNatives.defaultForPlatform;
  natives.load(baseDirectory);

  BraidNatives._activeLibraries = natives;
}

// ---

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

  static BraidNatives? _activeLibraries;

  final String glfw, freetype, harfbuzz;
  final String subdirectory;

  const BraidNatives({
    required this.glfw,
    required this.freetype,
    required this.harfbuzz,
    required this.subdirectory,
  });

  BraidNatives copy({
    String? glfw,
    String? freetype,
    String? harfbuzz,
    String? subdirectory,
  }) =>
      BraidNatives(
        glfw: glfw ?? this.glfw,
        freetype: freetype ?? this.freetype,
        harfbuzz: harfbuzz ?? this.harfbuzz,
        subdirectory: subdirectory ?? this.subdirectory,
      );

  /// Load the natives declared by this bundle,
  /// using [baseDirectory] for locating ones which
  /// are shipped with the application
  void load(String baseDirectory) {
    final prevDir = Directory.current;
    try {
      Directory.current = absolute(join(baseDirectory, subdirectory));

      DynamicLibrary.open(glfw);
      DynamicLibrary.open(freetype);
      DynamicLibrary.open(harfbuzz);
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
  static BraidNatives get activeLibraries {
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

  factory BraidResources.filesystem({
    required String fontDirectory,
    required String shaderDirectory,
  }) = FilesystemResources;
}

class FilesystemResources implements BraidResources {
  final String fontDirectory;
  final String shaderDirectory;

  FilesystemResources({
    required this.fontDirectory,
    required this.shaderDirectory,
  }) {
    if (!FileSystemEntity.isDirectorySync(fontDirectory)) {
      throw BraidInitializationException('shader directory $shaderDirectory does not exist');
    }

    if (!FileSystemEntity.isDirectorySync(shaderDirectory)) {
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
  Future<String> loadShader(String path) => File(join(shaderDirectory, path)).readAsString();
}
