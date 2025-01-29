import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';

void main(List<String> args) async {
  stdout.writeln();

  if (args.isEmpty) {
    print('install braid\'s required native libraries into <natives path>');
    print('usage: dart run braid_ui:install_natives <natives path>');
    return;
  }

  final nativesPath = args[0];
  final nativesDir = Directory(nativesPath);

  if (nativesDir.existsSync() && nativesDir.listSync().isNotEmpty) {
    print('specified natives directory already exists and is not empty, aborting');
    return;
  }

  print('installing natives into: ${absolute(nativesPath)}');

  final bundleUri = Uri.https('github.com', 'gliscowo/braid_ui/releases/download/natives/braid_natives.tar.gz');

  final client = HttpClient();
  final response = await client.getUrl(bundleUri).then((request) => request.close());

  print('downloading...');

  final archiveBytes = await response.transform(gzip.decoder).expand((element) => element).toList();
  final archive = TarDecoder().decodeBytes(archiveBytes);

  print('extracting...');

  await extractArchiveToDisk(archive, nativesPath);
  print('success');

  client.close();
}
