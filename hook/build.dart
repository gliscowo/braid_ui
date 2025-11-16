import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const supportedOperatingSystems = {OS.windows, OS.linux};
const supportedArchitectures = {Architecture.x64};

const librariesToInclude = ['freetype', 'harfbuzz'];

void main(List<String> args) {
  build(args, (input, output) async {
    final os = input.config.code.targetOS;
    final arch = input.config.code.targetArchitecture;

    if (!supportedOperatingSystems.contains(os)) {
      throw Exception('${input.packageName} does not support ${os.name}');
    }

    if (!supportedArchitectures.contains(arch)) {
      throw Exception('${input.packageName} does not support ${arch.name}');
    }

    for (final library in librariesToInclude) {
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: library,
          linkMode: DynamicLoadingBundled(),
          file: input.packageRoot.resolve('natives/${os.name}_${arch.name}/${os.dylibFileName(library)}'),
        ),
      );
    }
  });
}
