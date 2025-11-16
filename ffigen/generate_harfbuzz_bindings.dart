import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'ffigen_utils.dart';

void main(List<String> args) {
  var [harfbuzzPath, freetypePath] = args;
  harfbuzzPath = absolute(harfbuzzPath);
  freetypePath = absolute(freetypePath);

  final renamer = FfigenRenamer('hb', patternPrefix: 'hb_|HB_', replacements: {RegExp(r'(.*)_t$'): r'$1'});
  final {'files': {'freetype.dart': {'symbols': YamlMap freetypeSymbols}}} =
      loadYamlDocument(File('ffigen/freetype-symbols.yaml').readAsStringSync()).contents as YamlMap;

  final libraryImport = LibraryImport('ft', 'freetype.dart');

  final importedTypesByUsr = <String, ImportedType>{};
  for (final MapEntry(key: String cType, value: entry) in freetypeSymbols.entries) {
    final name = entry['name'] as String;
    final dartName = entry.containsKey('dart-name') ? entry['dart-name'] as String : null;

    importedTypesByUsr[cType] = ImportedType(
      libraryImport,
      name,
      dartName ?? name,
      cType.substring(cType.lastIndexOf('@') + 1),
      importedDartType: true,
    );
  }

  FfiGenerator(
    headers: Headers(
      entryPoints: [Uri.file(harfbuzzPath).resolve('hb.h'), Uri.file(harfbuzzPath).resolve('hb-ft.h')],
      compilerOptions: ['-I$harfbuzzPath', '-I$freetypePath'],
    ),
    macros: Macros(include: renamer.isValidName, rename: renamer.fixDeclaration(.lower)),
    functions: Functions(include: renamer.isValidName, rename: renamer.fixDeclaration(.lower)),
    structs: Structs(
      include: renamer.isValidName,
      rename: renamer.fixDeclaration(.upper),
      renameMember: (_, member) => renamer.fixName(.none)(member),
    ),
    enums: Enums(
      include: renamer.isValidName,
      rename: renamer.fixDeclaration(.upper),
      renameMember: (_, member) => renamer.fixName(.none)(member),
    ),
    importedTypesByUsr: importedTypesByUsr,
    typedefs: Typedefs(include: renamer.isValidName, rename: renamer.fixDeclaration(.upper)),
    output: Output(
      dartFile: Uri.file('lib/src/native/harfbuzz.dart'),
      commentType: const CommentType.none(),
      style: NativeExternalBindings(assetId: 'package:braid_ui/harfbuzz'),
    ),
  ).generate();
}
