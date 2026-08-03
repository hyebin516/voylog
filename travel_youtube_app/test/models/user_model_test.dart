import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('parses a full profile', () {
      final user = UserModel.fromJson({
        'userId': 'u1',
        'email': 'a@b.com',
        'nickname': 'Nagyeong',
        'profileImage': 'http://img',
      });

      expect(user.userId, 'u1');
      expect(user.email, 'a@b.com');
      expect(user.nickname, 'Nagyeong');
      expect(user.profileImage, 'http://img');
    });

    test('email and profileImage may be null (Kakao account without them)', () {
      final user = UserModel.fromJson({
        'userId': 'u1',
        'email': null,
        'nickname': 'Kakao User',
        'profileImage': null,
      });

      expect(user.email, isNull);
      expect(user.profileImage, isNull);
    });
  });
}
