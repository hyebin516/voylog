import 'package:flutter/foundation.dart';

import '../models/api_exception.dart';
import '../models/shared_route_model.dart';
import '../repositories/shared_route_repository.dart';
import '../utils/view_state.dart';

class SharedRouteProvider extends ChangeNotifier {
  final SharedRouteRepository _repository;

  SharedRouteProvider({SharedRouteRepository? repository}) : _repository = repository ?? SharedRouteRepository();

  ViewState _state = ViewState.idle;
  List<SharedRouteModel> _routes = [];
  String? _errorMessage;

  ViewState get state => _state;
  List<SharedRouteModel> get routes => _routes;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == ViewState.loading;

  Future<void> load() async {
    _state = ViewState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _routes = await _repository.getFeed();
      _state = ViewState.success;
    } on ApiException catch (e) {
      _state = ViewState.error;
      _errorMessage = e.friendlyMessage;
    }

    notifyListeners();
  }

  /// Optimistically flips the like state before the request resolves, then
  /// rolls back if it fails -- likes should feel instant.
  Future<void> toggleLike(String sharedRouteId) async {
    final index = _routes.indexWhere((r) => r.sharedRouteId == sharedRouteId);
    if (index == -1) return;

    final before = _routes[index];
    final optimistic = before.copyWith(
      likedByMe: !before.likedByMe,
      likeCount: before.likedByMe ? before.likeCount - 1 : before.likeCount + 1,
    );
    _routes = [..._routes]..[index] = optimistic;
    notifyListeners();

    try {
      if (optimistic.likedByMe) {
        await _repository.like(sharedRouteId);
      } else {
        await _repository.unlike(sharedRouteId);
      }
    } on ApiException catch (e) {
      _routes = [..._routes]..[index] = before;
      _errorMessage = e.friendlyMessage;
      notifyListeners();
    }
  }

  Future<bool> updateTitle(String sharedRouteId, String title) async {
    final index = _routes.indexWhere((r) => r.sharedRouteId == sharedRouteId);
    if (index == -1) return false;

    try {
      await _repository.updateTitle(sharedRouteId, title);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    _routes = [..._routes]..[index] = _routes[index].copyWith(title: title);
    notifyListeners();
    return true;
  }

  Future<bool> unpublish(String sharedRouteId) async {
    try {
      await _repository.unpublish(sharedRouteId);
    } on ApiException catch (e) {
      _errorMessage = e.friendlyMessage;
      notifyListeners();
      return false;
    }

    _routes = _routes.where((r) => r.sharedRouteId != sharedRouteId).toList();
    notifyListeners();
    return true;
  }
}
