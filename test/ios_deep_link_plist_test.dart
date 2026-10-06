import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('iOS Info.plist registers edupulse URL scheme', () {
    final plistPath = 'ios/Runner/Info.plist';
    final file = File(plistPath);
    expect(file.existsSync(), isTrue, reason: 'Info.plist not found');

    final root = XmlDocument.parse(file.readAsStringSync());

    final urlTypes = root
        .findAllElements('key')
        .where((el) => el.innerText == 'CFBundleURLTypes')
        .map((keyEl) => keyEl.nextElementSibling)
        .whereType<XmlElement>()
        .toList();
    expect(urlTypes.isNotEmpty, isTrue,
        reason: 'CFBundleURLTypes not found in Info.plist');

    final urlType = urlTypes.first;
    final urlSchemes = urlType
        .findAllElements('string')
        .where((el) => el.innerText == 'edupulse')
        .toList();
    expect(urlSchemes.isNotEmpty, isTrue,
        reason: 'edupulse scheme not found in CFBundleURLSchemes');
  });
}