import 'package:ffigen/ffigen.dart';
import 'package:path/path.dart';

import 'ffigen_utils.dart';

void main(List<String> args) {
  var [freetypePath, ...] = args;
  freetypePath = absolute(freetypePath);

  final renamer = FfigenRenamer('FT');

  FfiGenerator(
    headers: Headers(
      entryPoints: [
        Uri.file(freetypePath).resolve('ft2build.h'),
        Uri.file(freetypePath).resolve('freetype/freetype.h'),
      ],
      compilerOptions: ["-I$freetypePath"],
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
    typedefs: Typedefs(
      include: (declaration) {
        return renamer.isValidName(declaration) && declaration.originalName != 'FT_PtrDist';
      },
      rename: renamer.fixDeclaration(.upper),
    ),
    output: Output(
      dartFile: Uri.file('lib/src/native/freetype.dart'),
      symbolFile: SymbolFile(Uri.file('freetype.dart'), Uri.file('ffigen/freetype-symbols.yaml')),
      commentType: const CommentType.none(),
      style: NativeExternalBindings(assetId: 'package:braid_ui/freetype'),
    ),
  ).generate();
}
