import 'dart:io';

import 'package:handoff_dart/run.dart';

Future<void> main(List<String> args) async {
  final code = run(args);
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
