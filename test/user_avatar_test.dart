import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_nemshi/widgets/user_avatar.dart';

void main() {
  group('UserAvatar.initialsFor', () {
    test('uses first letters of the first two words', () {
      expect(UserAvatar.initialsFor('sara omar khalil'), 'SO');
    });

    test('single name gives one letter', () {
      expect(UserAvatar.initialsFor('  layla '), 'L');
    });

    test('empty name falls back to ?', () {
      expect(UserAvatar.initialsFor('   '), '?');
    });

    test('handles non-Latin names', () {
      expect(UserAvatar.initialsFor('سارة عمر'), 'سع');
    });
  });
}
