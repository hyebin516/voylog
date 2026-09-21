import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';
import '../models/support_inquiry_model.dart';
import '../utils/dio_error_handler.dart';

/// FR-13 고객센터 문의. Submitting works logged out; the history does not.
class SupportInquiryRepository {
  final Dio _dio = DioClient().dio;

  Future<SupportInquiryModel> submit({
    required String email,
    required SupportInquiryCategory category,
    required String message,
  }) async {
    try {
      final response = await _dio.post('/support-inquiries', data: {
        'email': email,
        'category': category.code,
        'message': message,
      });
      return SupportInquiryModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throwApiException(e);
    }
  }

  Future<List<SupportInquiryModel>> listMine() async {
    try {
      final response = await _dio.get('/support-inquiries');
      final inquiries = response.data['data']['inquiries'] as List<dynamic>;
      return inquiries.map((e) => SupportInquiryModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throwApiException(e);
    }
  }
}
