import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/support_inquiry_model.dart';
import '../repositories/support_inquiry_repository.dart';
import '../utils/view_state.dart';

class SupportInquiryProvider extends ChangeNotifier {
  final SupportInquiryRepository _repository;

  SupportInquiryProvider({SupportInquiryRepository? repository})
      : _repository = repository ?? SupportInquiryRepository();

  ViewState _state = ViewState.idle;
  List<SupportInquiryModel> _inquiries = [];
  String? _errorMessage;
  bool _isSubmitting = false;

  ViewState get state => _state;
  List<SupportInquiryModel> get inquiries => List.unmodifiable(_inquiries);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;
  bool get isSubmitting => _isSubmitting;

  Future<void> loadInquiries() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _inquiries = await _repository.listMine();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  /// Returns whether it was sent, so the screen can close and confirm.
  Future<bool> submit({
    required String email,
    required SupportInquiryCategory category,
    required String message,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    var sent = false;
    try {
      final inquiry = await _repository.submit(email: email, category: category, message: message);
      // Newest first, matching the backend's ordering, so the history is
      // right without a second round trip.
      _inquiries = [inquiry, ..._inquiries];
      sent = true;
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
    }

    _isSubmitting = false;
    notifyListeners();
    return sent;
  }
}
