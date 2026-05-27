import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('game, map, and core layers have no imports from features/ads/', () {
    final dirsToCheck = [
      'lib/features/game',
      'lib/features/map',
      'lib/core',
    ];

    final violations = <String>[];

    for (final dirPath in dirsToCheck) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (content.contains('features/ads/')) {
          violations.add(entity.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found illegal imports of features/ads/ in: ${violations.join(', ')}',
    );
  });
}
