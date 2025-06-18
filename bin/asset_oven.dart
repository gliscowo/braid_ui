import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:source_helper/source_helper.dart';

Future<void> main(List<String> args) async {
  final out = File('lib/src/baked_assets.g.dart').openWrite();
  out.writeln('''
// dart format off
// ignore_for_file: constant_identifier_names
''');

  final segments = await Future.wait(segmentBuilders.map((builder) => builder()));

  final imports = segments.expand((element) => element.imports).toSet();
  for (final import in imports) {
    out.writeln('import \'$import\';');
  }

  out.writeln();

  for (final (imports: _, :code) in segments) {
    out.writeln(code);
  }
  out.writeln(r'''
// ---

class _BakedAssetError extends Error {
  final String message;
  _BakedAssetError(this.message);

  @override
  String toString() => 'baked asset error: $message';
}
''');
}

// ---

typedef SegmentResult = ({List<String> imports, String code});
typedef SegmentBuilder = Future<SegmentResult> Function();

const inputBaseDir = 'resources';

File openAsset(String asset) {
  final assetFile = File(join(inputBaseDir, asset));
  if (!assetFile.existsSync()) {
    stderr.writeln('missing asset for bundling: $asset');
    exit(1);
  }

  return assetFile;
}

Stream<File> openAssetClass(String assetClass) {
  final classDirectory = Directory(join(inputBaseDir, assetClass));
  if (!classDirectory.existsSync()) {
    stderr.writeln('missing asset class for bundling: $assetClass');
    exit(1);
  }

  return classDirectory.list(recursive: true).where((event) => event is File).cast();
}

// ---

final quotesPattern = RegExp(r'^"|"$');
final whitespacePattern = RegExp('\\s{2,}');

final segmentBuilders = <SegmentBuilder>[
  () async {
    final iconBytes = await openAsset('braid_icon.png').readAsBytes();

    return (
      imports: const ['dart:convert', 'package:image/image.dart'],
      code:
          '''
const _braidIconBase64 = '${base64Encode(iconBytes)}';
final braidIcon = decodePng(base64Decode(_braidIconBase64))!;
''',
    );
  },
  () async {
    final shaders = openAssetClass('shader').asyncMap((event) => (Future.value(event.path), event.readAsString()).wait);
    final codeOut = StringBuffer();

    codeOut.writeln('const _shaderSources = {');

    await for (final shader in shaders) {
      final shaderPath = relative(shader.$1, from: join(inputBaseDir, 'shader'));
      if (shaderPath.startsWith('unused/')) {
        continue;
      }

      final shaderName = shaderPath.quoted;
      final shaderCode = shader.$2
          .replaceAllMapped(whitespacePattern, (match) => match[0]![0])
          .split('\n')
          .map((e) => e.trim())
          .where((e) => !e.startsWith('//'))
          .map((e) => e.startsWith('#') ? '$e\n' : e)
          .join()
          .quoted;

      codeOut.writeln('  $shaderName: $shaderCode,');
    }

    codeOut.writeln('};');
    codeOut.write(r'''

String getShaderSource(String shaderName) {
  if (!_shaderSources.containsKey(shaderName)) {
    throw _BakedAssetError('missing shader source for \'$shaderName\'');
  }

  return _shaderSources[shaderName]!;
}

class BakedAssetResources implements BraidResources {
  final BraidResources _fontDelegate;
  BakedAssetResources({required BraidResources fontDelegate}) : _fontDelegate = fontDelegate;

  @override
  Future<String> loadShader(String path) => Future.value(getShaderSource(path));

  @override
  Stream<Uint8List> loadFontFamily(String familyName) => _fontDelegate.loadFontFamily(familyName);
}
''');

    return (imports: const <String>['dart:typed_data', 'resources.dart'], code: codeOut.toString());
  },
  () async {
    final lines = await openAsset('icon_mappings.codepoints').readAsLines();
    final result = StringBuffer()..writeln('final class Icons {');
    final mappedIconNames = <String>{};

    for (final line in lines) {
      final [name, codepoint, ...] = line.split(' ');

      if (mappedIconNames.contains(name)) continue;
      mappedIconNames.add(name);

      var safeName = name;
      if (safeName.startsWith(RegExp(r'\d'))) {
        safeName = 'n_$safeName';
      }

      if (const {'try', 'switch', 'class'}.contains(safeName)) {
        safeName = 'k_$safeName';
      }

      result.writeln('  static const $safeName = IconSpec(0x$codepoint);');
    }

    result.writeln('}');

    return (imports: const <String>['widgets/icon.dart'], code: result.toString());
  },
];

// ---

extension on String {
  String get quoted => escapeDartString(this).replaceAll(quotesPattern, '\'');
}
