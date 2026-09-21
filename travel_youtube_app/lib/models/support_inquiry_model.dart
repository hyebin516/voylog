/// FR-13 문의 분류. The `code` is what the backend stores and validates
/// (`support_inquiries.category`); the label is what the form shows.
enum SupportInquiryCategory {
  analysis('analysis', '영상 분석'),
  route('route', '동선/여행'),
  account('account', '계정'),
  bug('bug', '오류 신고'),
  other('other', '기타');

  const SupportInquiryCategory(this.code, this.label);

  final String code;
  final String label;

  static SupportInquiryCategory fromCode(String code) {
    return SupportInquiryCategory.values.firstWhere(
      (category) => category.code == code,
      orElse: () => SupportInquiryCategory.other,
    );
  }
}

class SupportInquiryModel {
  final String inquiryId;
  final String email;
  final SupportInquiryCategory category;
  final String message;
  final DateTime createdAt;

  const SupportInquiryModel({
    required this.inquiryId,
    required this.email,
    required this.category,
    required this.message,
    required this.createdAt,
  });

  factory SupportInquiryModel.fromJson(Map<String, dynamic> json) {
    return SupportInquiryModel(
      inquiryId: json['inquiryId'] as String,
      email: json['email'] as String,
      category: SupportInquiryCategory.fromCode(json['category'] as String),
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
