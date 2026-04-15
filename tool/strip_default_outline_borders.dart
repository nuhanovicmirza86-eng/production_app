// ignore_for_file: avoid_print

import 'dart:io';

Future<void> main() async {
  final lib = Directory('lib');
  var n = 0;
  await for (final f in lib.list(recursive: true, followLinks: false)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;

    var text = await f.readAsString();
    final orig = text;
    const patterns = [
      r',\s*border:\s*const\s+OutlineInputBorder\(\)',
      r',\s*border:\s*OutlineInputBorder\(\)',
      r'border:\s*const\s+OutlineInputBorder\(\)\s*,',
      r'border:\s*OutlineInputBorder\(\)\s*,',
      r'border:\s*const\s+OutlineInputBorder\(\)',
      r'border:\s*OutlineInputBorder\(\)',
    ];
    for (final pat in patterns) {
      text = text.replaceAll(RegExp(pat), '');
    }
    for (var i = 0; i < 8; i++) {
      final next = text.replaceAll(RegExp(r',\s*,'), ',');
      if (next == text) break;
      text = next;
    }
    text = text.replaceAll(RegExp(r'InputDecoration\(\s*,'), 'InputDecoration(');

    if (text != orig) {
      await f.writeAsString(text);
      n++;
    }
  }
  print('updated $n files');
}
