import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:follo_cart/core/app_exception.dart';
import 'package:follo_cart/core/backend_mode.dart';
import 'package:follo_cart/models/cart_update_model.dart';
import 'package:follo_cart/models/follow_model.dart';
import 'package:follo_cart/models/food_cart_model.dart';
import 'package:follo_cart/models/notification_model.dart';
import 'package:follo_cart/models/report_model.dart';
import 'package:follo_cart/models/schedule_entry_model.dart';
import 'package:follo_cart/models/user_profile_model.dart';
import 'package:follo_cart/models/user_role.dart';
import 'package:follo_cart/repositories/auth_repository.dart';
import 'package:follo_cart/repositories/cart_repository.dart';
import 'package:follo_cart/repositories/follow_repository.dart';
import 'package:follo_cart/repositories/media_repository.dart';
import 'package:follo_cart/repositories/moderation_repository.dart';
import 'package:follo_cart/repositories/notification_repository.dart';
import 'package:follo_cart/repositories/repository_bundle.dart';
import 'package:follo_cart/services/location_service.dart';
import 'package:follo_cart/services/notification_gateway.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

/// Hand-rolled fakes over plain lists and StreamControllers.
///
/// At this size they read better than mock declarations, and they are the
/// reason widget tests never reach geolocator, shared_preferences,
/// image_picker or flutter_local_notifications.

FoodCartModel testCart({
  required String id,
  String? name,
  double latitude = 23.8103,
  double longitude = 90.4125,
  bool isOpen = true,
  bool isActive = true,
  String ownerId = 'owner-1',
  int followersCount = 0,
  List<String> photoRefs = const <String>[],
  List<ScheduleEntry> scheduleEntries = const <ScheduleEntry>[],
}) {
  return FoodCartModel(
    id: id,
    name: name ?? 'Cart $id',
    category: 'Street food',
    locationLabel: 'Test Park',
    ownerId: ownerId,
    latitude: latitude,
    longitude: longitude,
    isOpen: isOpen,
    isActive: isActive,
    followersCount: followersCount,
    photoRefs: photoRefs,
    scheduleEntries: scheduleEntries,
    updatedAt: DateTime(2026, 1, 1),
  );
}

UserProfileModel testUser({
  required String id,
  String name = 'Test User',
  String email = 'test@example.com',
  UserRole role = UserRole.customer,
  bool isBlocked = false,
  String? ownedCartId,
}) {
  return UserProfileModel(
    id: id,
    name: name,
    email: email,
    role: role,
    isBlocked: isBlocked,
    ownedCartId: ownedCartId,
    createdAt: DateTime(2026, 1, 1),
  );
}

class FakeCartRepository implements CartRepository {
  FakeCartRepository([List<FoodCartModel> seed = const <FoodCartModel>[]]) {
    _carts.addAll(seed);
    _controller.add(List.of(_carts));
  }

  final List<FoodCartModel> _carts = <FoodCartModel>[];
  final StreamController<List<FoodCartModel>> _controller =
      StreamController<List<FoodCartModel>>.broadcast();

  List<FoodCartModel> get current => List.unmodifiable(_carts);

  void _emit() => _controller.add(List.of(_carts));

  @override
  Stream<List<FoodCartModel>> watchCarts() async* {
    yield List.of(_carts);
    yield* _controller.stream;
  }

  @override
  Stream<FoodCartModel?> watchCart(String cartId) =>
      watchCarts().map((carts) {
        for (final cart in carts) {
          if (cart.id == cartId) return cart;
        }
        return null;
      });

  @override
  Stream<FoodCartModel?> watchCartByOwner(String ownerId) =>
      watchCarts().map((carts) {
        for (final cart in carts) {
          if (cart.ownerId == ownerId) return cart;
        }
        return null;
      });

  @override
  Future<List<FoodCartModel>> fetchCarts() async => List.of(_carts);

  @override
  Future<FoodCartModel?> fetchCart(String cartId) async {
    for (final cart in _carts) {
      if (cart.id == cartId) return cart;
    }
    return null;
  }

  @override
  Future<FoodCartModel> createCart(FoodCartModel cart) async {
    _carts.add(cart);
    _emit();
    return cart;
  }

  @override
  Future<void> updateCart(FoodCartModel cart) async =>
      _replace(cart.id, (_) => cart);

  @override
  Future<void> setOpen({required String cartId, required bool isOpen}) async =>
      _replace(cartId, (cart) => cart.copyWith(isOpen: isOpen));

  @override
  Future<void> updateLocation({
    required String cartId,
    required double latitude,
    required double longitude,
    String? locationLabel,
  }) async =>
      _replace(
        cartId,
        (cart) => cart.copyWith(
          latitude: latitude,
          longitude: longitude,
          lastLocationAt: DateTime.now(),
          locationLabel: locationLabel,
        ),
      );

  @override
  Future<void> replaceSchedule({
    required String cartId,
    required List<ScheduleEntry> entries,
  }) async =>
      _replace(cartId, (cart) => cart.copyWith(scheduleEntries: entries));

  @override
  Future<void> setPhotos({
    required String cartId,
    required List<String> photoRefs,
  }) async =>
      _replace(cartId, (cart) => cart.copyWith(photoRefs: photoRefs));

  @override
  Future<void> setVisibility({
    required String cartId,
    required bool isActive,
  }) async =>
      _replace(cartId, (cart) => cart.copyWith(isActive: isActive));

  @override
  Future<void> adjustFollowerCount({
    required String cartId,
    required int delta,
  }) async =>
      _replace(
        cartId,
        (cart) => cart.copyWith(
          followersCount: (cart.followersCount + delta).clamp(0, 1 << 30),
        ),
      );

  void _replace(String id, FoodCartModel Function(FoodCartModel) transform) {
    for (var i = 0; i < _carts.length; i++) {
      if (_carts[i].id == id) {
        _carts[i] = transform(_carts[i]);
        _emit();
        return;
      }
    }
  }
}

class FakeFollowRepository implements FollowRepository {
  FakeFollowRepository(this._carts);

  final CartRepository _carts;
  final List<FollowModel> _follows = <FollowModel>[];
  final StreamController<List<FollowModel>> _controller =
      StreamController<List<FollowModel>>.broadcast();

  List<FollowModel> get current => List.unmodifiable(_follows);

  void _emit() => _controller.add(List.of(_follows));

  @override
  Stream<List<FollowModel>> watchFollows(String userId) async* {
    yield _forUser(userId);
    yield* _controller.stream.map((_) => _forUser(userId));
  }

  List<FollowModel> _forUser(String userId) =>
      _follows.where((f) => f.userId == userId).toList();

  @override
  Future<List<FollowModel>> fetchFollows(String userId) async =>
      _forUser(userId);

  @override
  Future<FollowModel> follow({
    required String userId,
    required String cartId,
    bool notificationsEnabled = true,
    int? proximityAlertKm,
  }) async {
    final existing = _follows.indexWhere(
      (f) => f.userId == userId && f.cartId == cartId,
    );
    final follow = FollowModel(
      id: FollowModel.idFor(userId, cartId),
      userId: userId,
      cartId: cartId,
      followedAt: DateTime.now(),
      notificationsEnabled: notificationsEnabled,
      proximityAlertKm: proximityAlertKm ?? FollowRepository.defaultRadiusKm,
    );

    if (existing >= 0) {
      _follows[existing] = follow;
    } else {
      _follows.add(follow);
      await _carts.adjustFollowerCount(cartId: cartId, delta: 1);
    }
    _emit();
    return follow;
  }

  @override
  Future<void> unfollow({
    required String userId,
    required String cartId,
  }) async {
    final before = _follows.length;
    _follows.removeWhere((f) => f.userId == userId && f.cartId == cartId);
    if (_follows.length != before) {
      await _carts.adjustFollowerCount(cartId: cartId, delta: -1);
    }
    _emit();
  }

  @override
  Future<void> updateFollow(FollowModel follow) async {
    final index = _follows.indexWhere((f) => f.id == follow.id);
    if (index >= 0) _follows[index] = follow;
    _emit();
  }

  @override
  Future<List<String>> followerIdsForCart(String cartId) async =>
      _follows.where((f) => f.cartId == cartId).map((f) => f.userId).toList();
}

class FakeNotificationRepository implements NotificationRepository {
  final List<NotificationModel> items = <NotificationModel>[];
  final List<CartUpdateModel> updates = <CartUpdateModel>[];
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  List<NotificationModel> feedFor(String userId) =>
      items.where((n) => n.userId == userId).toList();

  @override
  Stream<List<NotificationModel>> watchFeed(String userId) async* {
    yield feedFor(userId);
    yield* _controller.stream.map((_) => feedFor(userId));
  }

  @override
  Stream<int> watchUnreadCount(String userId) =>
      watchFeed(userId).map((f) => f.where((n) => !n.isRead).length);

  @override
  Future<void> push(NotificationModel notification) =>
      pushAll(<NotificationModel>[notification]);

  @override
  Future<void> pushAll(List<NotificationModel> notifications) async {
    items.addAll(notifications);
    _controller.add(null);
  }

  @override
  Future<void> markRead(String notificationId) async {
    final id = notificationId.split('/').last;
    for (var i = 0; i < items.length; i++) {
      if (items[i].id == id) items[i] = items[i].copyWith(isRead: true);
    }
    _controller.add(null);
  }

  @override
  Future<void> markAllRead(String userId) async {
    for (var i = 0; i < items.length; i++) {
      if (items[i].userId == userId) {
        items[i] = items[i].copyWith(isRead: true);
      }
    }
    _controller.add(null);
  }

  @override
  Future<void> recordCartUpdate(CartUpdateModel update) async {
    updates.add(update);
    _controller.add(null);
  }

  @override
  Stream<List<CartUpdateModel>> watchCartUpdates(String cartId) async* {
    yield updates.where((u) => u.cartId == cartId).toList();
    yield* _controller.stream
        .map((_) => updates.where((u) => u.cartId == cartId).toList());
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({UserProfileModel? signedInAs}) : _current = signedInAs;

  final Map<String, ({UserProfileModel profile, String password})> _accounts =
      <String, ({UserProfileModel profile, String password})>{};
  final StreamController<UserProfileModel?> _controller =
      StreamController<UserProfileModel?>.broadcast();

  UserProfileModel? _current;

  void seedAccount(UserProfileModel profile, String password) {
    _accounts[profile.email.toLowerCase()] =
        (profile: profile, password: password);
  }

  @override
  UserProfileModel? get currentUser => _current;

  @override
  Stream<UserProfileModel?> watchCurrentUser() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<UserProfileModel> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final key = email.toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AuthException(AuthErrorCode.emailInUse, 'Email in use.');
    }
    final profile = testUser(
      id: 'user-${_accounts.length + 1}',
      name: displayName,
      email: key,
      role: role,
    );
    _accounts[key] = (profile: profile, password: password);
    _current = profile;
    _controller.add(profile);
    return profile;
  }

  @override
  Future<UserProfileModel> signIn({
    required String email,
    required String password,
  }) async {
    final account = _accounts[email.toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthException(
        AuthErrorCode.invalidCredentials,
        'That email and password do not match.',
      );
    }
    if (account.profile.isBlocked) {
      throw const AuthException(AuthErrorCode.userBlocked, 'Blocked.');
    }
    _current = account.profile;
    _controller.add(account.profile);
    return account.profile;
  }

  @override
  Future<UserProfileModel?> restoreSession() async => _current;

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> updateProfile(UserProfileModel profile) async {
    _accounts[profile.email.toLowerCase()] = (
      profile: profile,
      password: _accounts[profile.email.toLowerCase()]?.password ?? '',
    );
    if (_current?.id == profile.id) {
      _current = profile;
      _controller.add(profile);
    }
  }

  @override
  Future<void> updateFcmToken({
    required String userId,
    String? token,
  }) async {}

  @override
  void dispose() => _controller.close();
}

class FakeModerationRepository implements ModerationRepository {
  FakeModerationRepository({
    required CartRepository carts,
    List<UserProfileModel> users = const <UserProfileModel>[],
    List<ReportModel> reports = const <ReportModel>[],
  }) : _carts = carts {
    _users.addAll(users);
    _reports.addAll(reports);
  }

  final CartRepository _carts;
  final List<UserProfileModel> _users = <UserProfileModel>[];
  final List<ReportModel> _reports = <ReportModel>[];
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  List<ReportModel> get reports => List.unmodifiable(_reports);
  List<UserProfileModel> get users => List.unmodifiable(_users);

  @override
  Stream<List<ReportModel>> watchReports({ReportStatus? status}) async* {
    List<ReportModel> snapshot() => _reports
        .where((r) => status == null || r.status == status)
        .toList();
    yield snapshot();
    yield* _controller.stream.map((_) => snapshot());
  }

  @override
  Future<void> submitReport(ReportModel report) async {
    _reports.add(report);
    _controller.add(null);
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String adminId,
    String? note,
  }) async {
    for (var i = 0; i < _reports.length; i++) {
      if (_reports[i].id == reportId) {
        _reports[i] = _reports[i].copyWith(
          status: status,
          resolvedBy: adminId,
          resolutionNote: note,
          resolvedAt: DateTime.now(),
        );
      }
    }
    _controller.add(null);
  }

  @override
  Stream<List<UserProfileModel>> watchUsers({String? query}) async* {
    yield List.of(_users);
    yield* _controller.stream.map((_) => List.of(_users));
  }

  @override
  Future<List<UserProfileModel>> fetchUsers() async => List.of(_users);

  @override
  Future<void> setUserBlocked({
    required String userId,
    required bool isBlocked,
    required String adminId,
    String? reason,
  }) async {
    for (var i = 0; i < _users.length; i++) {
      if (_users[i].id == userId) {
        _users[i] = _users[i].copyWith(
          isBlocked: isBlocked,
          blockedBy: isBlocked ? adminId : null,
          blockedReason: isBlocked ? reason : null,
          blockedAt: isBlocked ? DateTime.now() : null,
          clearBlockDetails: !isBlocked,
        );
      }
    }
    for (final cart in await _carts.fetchCarts()) {
      if (cart.ownerId == userId) {
        await _carts.setVisibility(cartId: cart.id, isActive: !isBlocked);
      }
    }
    _controller.add(null);
  }
}

class FakeMediaRepository implements MediaRepository {
  final List<String> uploaded = <String>[];

  @override
  Future<String> uploadCartPhoto({
    required String cartId,
    required XFile file,
  }) async {
    final ref = 'cart_photos/$cartId/${uploaded.length}.jpg';
    uploaded.add(ref);
    return ref;
  }

  @override
  Future<void> deleteCartPhoto(String reference) async =>
      uploaded.remove(reference);

  @override
  ImageProvider imageFor(String reference) =>
      const AssetImage('test_placeholder');
}

class FakeLocationService implements LocationService {
  FakeLocationService({
    LatLng? initial,
    this.permissionGranted = true,
  }) : _position = initial ?? const LatLng(23.8103, 90.4125);

  final bool permissionGranted;
  final StreamController<LatLng> _controller =
      StreamController<LatLng>.broadcast();

  LatLng _position;
  int ensurePermissionCalls = 0;
  bool lastBackgroundRequest = false;

  void emit(LatLng position) {
    _position = position;
    _controller.add(position);
  }

  @override
  Future<bool> ensurePermission({bool background = false}) async {
    ensurePermissionCalls++;
    lastBackgroundRequest = background;
    if (!permissionGranted) {
      throw const LocationException(
        LocationFailure.permissionDenied,
        'Location permission was not granted.',
      );
    }
    return true;
  }

  @override
  Future<LatLng> currentPosition() async {
    await ensurePermission();
    return _position;
  }

  @override
  Stream<LatLng> watchPosition({bool background = false}) =>
      _controller.stream;
}

class RecordingNotificationGateway implements NotificationGateway {
  final List<({String title, String body, String? deeplink})> shown =
      <({String title, String body, String? deeplink})>[];
  final StreamController<String> _taps = StreamController<String>.broadcast();

  int permissionRequests = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    String? deeplink,
  }) async {
    shown.add((title: title, body: body, deeplink: deeplink));
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  void dispose() => _taps.close();
}

/// Assembles a complete fake backend in one call.
({
  RepositoryBundle bundle,
  FakeCartRepository carts,
  FakeFollowRepository follows,
  FakeNotificationRepository notifications,
  FakeAuthRepository auth,
  FakeModerationRepository moderation,
  FakeMediaRepository media,
}) fakeBundle({
  List<FoodCartModel>? carts,
  List<UserProfileModel>? users,
  List<ReportModel>? reports,
  UserProfileModel? signedInAs,
}) {
  final cartRepo = FakeCartRepository(carts ?? const <FoodCartModel>[]);
  final followRepo = FakeFollowRepository(cartRepo);
  final notificationRepo = FakeNotificationRepository();
  final authRepo = FakeAuthRepository(signedInAs: signedInAs);
  final moderationRepo = FakeModerationRepository(
    carts: cartRepo,
    users: users ?? const <UserProfileModel>[],
    reports: reports ?? const <ReportModel>[],
  );
  final mediaRepo = FakeMediaRepository();

  return (
    bundle: RepositoryBundle(
      mode: BackendMode.local,
      auth: authRepo,
      carts: cartRepo,
      follows: followRepo,
      notifications: notificationRepo,
      moderation: moderationRepo,
      media: mediaRepo,
    ),
    carts: cartRepo,
    follows: followRepo,
    notifications: notificationRepo,
    auth: authRepo,
    moderation: moderationRepo,
    media: mediaRepo,
  );
}
