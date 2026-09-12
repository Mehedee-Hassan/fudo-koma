import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/food_cart_model.dart';
import '../models/food_cart_x.dart';
import '../repositories/cart_repository.dart';

class CartController extends ChangeNotifier {
  CartController(this._repository) {
    _sub = _repository.watchCarts().listen((carts) {
      _carts = carts;
      _loading = false;
      notifyListeners();
    });
  }

  final CartRepository _repository;
  StreamSubscription<List<FoodCartModel>>? _sub;

  List<FoodCartModel> _carts = const <FoodCartModel>[];
  String _query = '';
  String? _selectedCartId;
  LatLng? _userPosition;
  bool _loading = true;
  bool _openOnly = false;

  bool get isLoading => _loading;
  String get query => _query;
  bool get openOnly => _openOnly;
  String? get selectedCartId => _selectedCartId;
  LatLng? get userPosition => _userPosition;

  /// Everything a customer may see: admin-hidden carts are excluded here, once,
  /// rather than at every call site.
  List<FoodCartModel> get carts =>
      _carts.where((cart) => cart.isActive).toList();

  set userPosition(LatLng? value) {
    if (value == _userPosition) return;
    _userPosition = value;
    notifyListeners();
  }

  FoodCartModel? get selectedCart {
    final id = _selectedCartId;
    if (id == null) return null;
    for (final cart in _carts) {
      if (cart.id == id) return cart;
    }
    return null;
  }

  FoodCartModel? cartById(String id) {
    for (final cart in _carts) {
      if (cart.id == id) return cart;
    }
    return null;
  }

  /// Search + open filter + nearest-first ordering.
  List<FoodCartModel> visibleCarts() {
    final needle = _query.trim().toLowerCase();
    final filtered = carts.where((cart) {
      if (_openOnly && !cart.isOpen) return false;
      if (needle.isEmpty) return true;
      return cart.name.toLowerCase().contains(needle) ||
          cart.category.toLowerCase().contains(needle) ||
          cart.locationLabel.toLowerCase().contains(needle);
    }).toList();

    final user = _userPosition;
    if (user != null) {
      filtered.sort((a, b) {
        final da = a.distanceKmFrom(user) ?? double.infinity;
        final db = b.distanceKmFrom(user) ?? double.infinity;
        return da.compareTo(db);
      });
    }
    return filtered;
  }

  void select(String? cartId) {
    if (_selectedCartId == cartId) return;
    _selectedCartId = cartId;
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setOpenOnly(bool value) {
    if (_openOnly == value) return;
    _openOnly = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
