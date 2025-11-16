import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import 'errors.dart';

abstract interface class BraidResources {
  Future<String> loadShader(String path);
  Stream<Uint8List> loadFontFamily(String familyName);

  factory BraidResources.fonts(String fontDirectory) = _FontOnlyResources;
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
