import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../core/id_generator.dart';
import '../models/cart_update_model.dart';
import '../models/food_cart_model.dart';
import '../models/schedule_entry_model.dart';
import '../repositories/cart_repository.dart';
import '../repositories/media_repository.dart';
import '../repositories/local/local_keys.dart';
import '../repositories/local/local_store.dart';
import '../services/cart_update_publisher.dart';
import '../services/location_service.dart';
import '../services/proximity_service.dart';

class OwnerController extends ChangeNotifier {
  OwnerController({
    required CartRepository carts,
    required MediaRepository media,
    required CartUpdatePublisher publisher,
    required LocationService location,
    LocalStore? store,
  })  : _carts = carts,
        _media = media,
        _publisher = publisher,
        _location = location,
        _store = store;

  final CartRepository _carts;
  final MediaRepository _media;
  final CartUpdatePublisher _publisher;
  final LocationService _location;
  final LocalStore? _store;

  StreamSubscription<FoodCartModel?>? _cartSub;
  StreamSubscription<LatLng>? _positionSub;

  String? _ownerId;
  FoodCartModel? _cart;
  bool _loading = true;
  bool _broadcasting = false;
  bool _busy = false;
  String? _error;

  DateTime? _lastWriteAt;
  LatLng? _lastPublishedPoint;

  FoodCartModel? get cart => _cart;
  bool get isLoading => _loading;
  bool get isBroadcasting => _broadcasting;
  bool get busy => _busy;
  String? get error => _error;
  bool get hasCart => _cart != null;

  /// True when a previous session left sharing on. The UI asks before resuming;
  /// silently restarting a GPS stream is a privacy trap and an app-review risk.
  bool get wantsBroadcastResume =>
      _store?.getBool(LocalKeys.broadcasting) ?? false;

  void bindOwner(String? ownerId) {
    if (_ownerId == ownerId) return;
    _ownerId = ownerId;
    _cartSub?.cancel();
    _cartSub = null;
    unawaited(stopBroadcast(persist: false));

    if (ownerId == null) {
      _cart = null;
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _cartSub = _carts.watchCartByOwner(ownerId).listen((cart) {
      _cart = cart;
      _loading = false;
      notifyListeners();
    });
  }

  Future<FoodCartModel?> createCart({
    required String name,
    required String category,
    required String locationLabel,
    required String description,
    LatLng? position,
  }) =>
      _runValue(() async {
        final ownerId = _ownerId;
        if (ownerId == null) return null;

        final point = position ?? AppConstants.defaultMapCenter;
        final created = await _carts.createCart(FoodCartModel(
          id: newId('cart'),
          name: name.trim(),
          category: category.trim(),
          locationLabel: locationLabel.trim(),
          ownerId: ownerId,
          description: description.trim(),
          latitude: point.latitude,
          longitude: point.longitude,
          updatedAt: DateTime.now(),
        ));
        _cart = created;
        return created;
      });

  Future<void> saveDetails({
    required String name,
    required String category,
    required String locationLabel,
    required String description,
  }) =>
      _run(() async {
        final current = _cart;
        if (current == null) return;
        await _carts.updateCart(current.copyWith(
          name: name.trim(),
          category: category.trim(),
          locationLabel: locationLabel.trim(),
          description: description.trim(),
        ));
      });

  Future<void> setOpen(bool isOpen) => _run(() async {
        final current = _cart;
        if (current == null) return;

        await _carts.setOpen(cartId: current.id, isOpen: isOpen);
        await _publisher.publish(
          cart: current,
          type: isOpen ? CartUpdateType.opened : CartUpdateType.closed,
          message: isOpen
              ? '${current.name} is open now at ${current.locationLabel}.'
              : '${current.name} has closed for now.',
          locationLabel: current.locationLabel,
        );

        // Closing ends live sharing: a closed cart broadcasting its position is
        // a privacy leak with no product value.
        if (!isOpen && _broadcasting) await stopBroadcast();
      });

  Future<void> saveSchedule(List<ScheduleEntry> entries) => _run(() async {
        final current = _cart;
        if (current == null) return;

        await _carts.replaceSchedule(cartId: current.id, entries: entries);
        await _publisher.publish(
          cart: current,
          type: CartUpdateType.scheduleChanged,
          message: '${current.name} updated its schedule.',
        );
      });

  Future<void> publishAnnouncement(String message) => _run(() async {
        final current = _cart;
        if (current == null || message.trim().isEmpty) return;
        await _publisher.publish(
          cart: current,
          type: CartUpdateType.announcement,
          message: message.trim(),
          locationLabel: current.locationLabel,
        );
      });

  Future<void> addPhoto(XFile file) => _run(() async {
        final current = _cart;
        if (current == null) return;

        final ref = await _media.uploadCartPhoto(cartId: current.id, file: file);
        await _carts.setPhotos(
          cartId: current.id,
          photoRefs: <String>[...current.photoRefs, ref],
        );
        await _publisher.publish(
          cart: current,
          type: CartUpdateType.photoAdded,
          message: '${current.name} added a new photo.',
        );
      });

  Future<void> removePhoto(String reference) => _run(() async {
        final current = _cart;
        if (current == null) return;

        await _carts.setPhotos(
          cartId: current.id,
          photoRefs: current.photoRefs.where((r) => r != reference).toList(),
        );
        await _media.deleteCartPhoto(reference);
      });

  /// Claims one of the seeded demo carts. Debug + local mode only - real
  /// ownership needs server-side verification.
  Future<void> claimCart(String cartId) => _run(() async {
        final ownerId = _ownerId;
        if (ownerId == null) return;
        final cart = await _carts.fetchCart(cartId);
        if (cart == null) return;
        await _carts.updateCart(cart.copyWith(ownerId: ownerId));
      });

  Future<void> startBroadcast({bool background = false}) async {
    final current = _cart;
    if (current == null || _broadcasting) return;

    try {
      await _location.ensurePermission(background: background);
      _positionSub = _location
          .watchPosition(background: background)
          .listen(_onPosition, onError: (Object error) {
        _error = 'Location sharing stopped: $error';
        notifyListeners();
      });
      _broadcasting = true;
      _error = null;
      await _store?.setBool(LocalKeys.broadcasting, true);
    } on LocationException catch (error) {
      _error = error.message;
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopBroadcast({bool persist = true}) async {
    await _positionSub?.cancel();
    _positionSub = null;
    _broadcasting = false;
    _lastPublishedPoint = null;
    _lastWriteAt = null;
    if (persist) await _store?.setBool(LocalKeys.broadcasting, false);
    notifyListeners();
  }

  Future<void> _onPosition(LatLng position) async {
    final current = _cart;
    if (current == null) return;

    // `distanceFilter` already suppresses jitter; this second guard bounds how
    // often a fast-moving cart can write.
    final now = DateTime.now();
    if (_lastWriteAt != null &&
        now.difference(_lastWriteAt!) < AppConstants.broadcastMinWriteInterval) {
      return;
    }
    _lastWriteAt = now;

    await _carts.updateLocation(
      cartId: current.id,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    // Only real movement earns a feed entry. Without this every follower would
    // get a "cart moved" item every 30 seconds.
    final last = _lastPublishedPoint;
    final movedMeters = last == null
        ? double.infinity
        : ProximityService.calculateDistanceKm(
              lat1: last.latitude,
              lon1: last.longitude,
              lat2: position.latitude,
              lon2: position.longitude,
            ) *
            1000;

    if (movedMeters >= AppConstants.movedUpdateThresholdMeters) {
      _lastPublishedPoint = position;
      await _publisher.publish(
        cart: current,
        type: CartUpdateType.moved,
        message: '${current.name} is on the move to a new spot.',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    await _runValue<void>(() async => action());
  }

  Future<T?> _runValue<T>(Future<T?> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
