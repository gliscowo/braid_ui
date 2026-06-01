import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import 'baked_assets.g.dart';
import 'errors.dart';

abstract interface class BraidResources {
  Future<String>? loadShader(String path);
  Stream<Uint8List>? loadFontFamily(String familyName);

  factory BraidResources.layered(List<BraidResources> layers) = _LayeredResources;

  const factory BraidResources.bakedShaders() = BakedShaderResources;
  factory BraidResources.filesystem({String? fontDirectory, String? shaderDirectory}) = FilesystemResources;
}

class _LayeredResources implements BraidResources {
  final List<BraidResources> layers;

  _LayeredResources(this.layers);

  @override
  Future<String>? loadShader(String path) =>
      layers.map((e) => e.loadShader(path)).whereType<Future<String>>().firstOrNull;

  @override
  Stream<Uint8List>? loadFontFamily(String familyName) =>
      layers.map((e) => e.loadFontFamily(familyName)).whereType<Stream<Uint8List>>().firstOrNull;
}

class FilesystemResources implements BraidResources {
  final String? shaderDirectory;
  final String? fontDirectory;

  FilesystemResources({this.shaderDirectory, this.fontDirectory}) {
    if (shaderDirectory != null && !FileSystemEntity.isDirectorySync(shaderDirectory!)) {
      throw BraidInitializationException('shader directory $shaderDirectory does not exist');
    }

    if (fontDirectory != null && !FileSystemEntity.isDirectorySync(fontDirectory!)) {
      throw BraidInitializationException('font directory $shaderDirectory does not exist');
    }
  }

  @override
  Future<String>? loadShader(String path) {
    if (shaderDirectory == null) {
      return null;
    }

    final file = File(join(shaderDirectory!, path));
    if (!file.existsSync()) {
      return null;
    }

    return file.readAsString();
  }

  @override
  Stream<Uint8List>? loadFontFamily(String familyName) {
    if (fontDirectory == null) {
      return null;
    }

    final directory = Directory(join(fontDirectory!, familyName));
    if (!directory.existsSync()) {
      return null;
    }

    return directory
        .list()
        .where((event) => event is File && const ['.otf', '.ttf'].contains(extension(event.path)))
        .cast<File>()
        .asyncMap((event) => event.readAsBytes());
  }
}
