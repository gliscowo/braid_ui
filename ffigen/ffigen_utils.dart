import 'package:ffigen/ffigen.dart';

enum Prefix { upper, lower, none }

class FfigenRenamer {
  final String prefix;
  final String prefixUpper;
  final String prefixLower;

  final RegExp namePattern;

  final Map<RegExp, String> replacements;

  FfigenRenamer(this.prefix, {String? patternPrefix, this.replacements = const {}})
    : prefixUpper = prefix.toUpperCase(),
      prefixLower = prefix.toLowerCase(),
      namePattern = RegExp('${patternPrefix != null ? '(?:$patternPrefix)' : '${prefix}_'}(.*)');

  bool isValidName(Declaration declaration) => namePattern.hasMatch(declaration.originalName);

  String Function(Declaration) fixDeclaration(Prefix prefix) {
    final fixer = fixName(prefix);
    return (declaration) => fixer(declaration.originalName);
  }

  String Function(String) fixName(Prefix prefix) => (name) {
    for (final MapEntry(key: pattern, value: replacement) in replacements.entries) {
      var match = pattern.matchAsPrefix(name);
      if (match == null) continue;

      name = replacement.replaceAllMapped(argPattern, (argMatch) => match[int.parse(argMatch[1]!)]!);
    }

    final match = namePattern.matchAsPrefix(name);
    final camel = (match?[1] ?? name).toLowerCase().replaceAllMapped(
      underscorePattern,
      (match) => match[1]!.toUpperCase(),
    );
    return switch (prefix) {
      .upper => '$prefixUpper${camel[0].toUpperCase() + camel.substring(1)}',
      .lower => '$prefixLower${camel[0].toUpperCase() + camel.substring(1)}',
      .none => camel,
    };
  };

  // ---

  static final underscorePattern = RegExp('_(.)');
  static final argPattern = RegExp(r'\$(\d+)');
}
