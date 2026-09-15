class UserModel {
  final String userId;
  final String? email;
  final String nickname;
  final String? profileImage;
  final String? provider;

  const UserModel({
    required this.userId,
    required this.email,
    required this.nickname,
    required this.profileImage,
    this.provider,
  });

  bool get isKakaoAccount => provider == 'kakao';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      nickname: json['nickname'] as String,
      profileImage: json['profileImage'] as String?,
      provider: json['provider'] as String?,
    );
  }
}
