import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('AndroidManifest has task deep-link intent filter', () {
    final manifestPath = 'android/app/src/main/AndroidManifest.xml';
    
    final file = File(manifestPath);
    if (!file.existsSync()) {
      throw Exception('AndroidManifest.xml not found');
    }
    
    final content = file.readAsStringSync();
    final document = XmlDocument.parse(content);
    
    // Find intent-filter with action VIEW, category BROWSABLE, scheme edupulse, host task.
    final intentFilters = document.findAllElements('intent-filter');
    bool found = false;
    
    for (final filter in intentFilters) {
      final actions = filter.findElements('action');
      final categories = filter.findElements('category');
      final datas = filter.findElements('data');
      
      bool hasView = false;
      bool hasBrowsable = false;
      bool hasEdupulseScheme = false;
      bool hasTaskHost = false;
      
      for (final action in actions) {
        final name = action.getAttribute('android:name');
        if (name == 'android.intent.action.VIEW') {
          hasView = true;
        }
      }
      
      for (final category in categories) {
        final name = category.getAttribute('android:name');
        if (name == 'android.intent.category.BROWSABLE') {
          hasBrowsable = true;
        }
      }
      
      for (final data in datas) {
        final scheme = data.getAttribute('android:scheme');
        final host = data.getAttribute('android:host');
        
        if (scheme == 'edupulse') {
          hasEdupulseScheme = true;
        }
        if (host == 'task') {
          hasTaskHost = true;
        }
      }
      
      if (hasView && hasBrowsable && hasEdupulseScheme && hasTaskHost) {
        found = true;
        break;
      }
    }
    
    expect(found, isTrue, reason: 'AndroidManifest should have deep-link intent filter for task/<id>');
  });
}
