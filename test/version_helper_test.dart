import 'package:flutter_test/flutter_test.dart';
import 'package:cofrenuvem/utils/version_helper.dart';

void main() {
  group('VersionHelper', () {
    test('parses dotted version strings', () {
      expect(VersionHelper.parse('v.0.0.30'), orderedEquals([0, 0, 30]));
      expect(VersionHelper.parse('1.2.3'), orderedEquals([1, 2, 3]));
      expect(VersionHelper.parse('v2.10.0-beta'), orderedEquals([2, 10, 0]));
    });

    test('compares versions correctly', () {
      expect(VersionHelper.isNewer('0.0.31', '0.0.30'), isTrue);
      expect(VersionHelper.isNewer('0.0.30', '0.0.30'), isFalse);
      expect(VersionHelper.isNewer('0.0.29', '0.0.30'), isFalse);
      expect(VersionHelper.isNewer('1.0.0', '0.0.30'), isTrue);
      expect(VersionHelper.isNewer('0.10.0', '0.9.99'), isTrue);
    });
  });
}
