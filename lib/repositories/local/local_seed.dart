import '../../core/app_constants.dart';
import '../../models/cart_update_model.dart';
import '../../models/follow_model.dart';
import '../../models/food_cart_model.dart';
import '../../models/report_model.dart';
import '../../models/schedule_entry_model.dart';
import '../../models/user_profile_model.dart';
import '../../models/user_role.dart';
import 'local_keys.dart';
import 'local_password.dart';
import 'local_store.dart';

/// Seeds the demo dataset on first launch.
///
/// Ports the seven carts that were hardcoded in `main.dart` - same names, same
/// real coordinates - so the visual design and the existing smoke test survive
/// the refactor, while the data now lives behind a repository.
abstract final class LocalSeed {
  /// Demo credentials, offered as one-tap sign-in on the Welcome screen in
  /// debug builds. Kept deliberately short: these get typed by hand on a phone.
  ///
  /// One password for all three roles, and it satisfies the same 8-character
  /// minimum the register screen enforces - no special-casing for demo data.
  static const String demoPassword = 'demo1234';
  static const String customerEmail = 'demo@demo.com';
  static const String ownerEmail = 'owner@demo.com';
  static const String adminEmail = 'admin@demo.com';

  static Future<void> ensureSeeded(LocalStore store) async {
    await store.migrate();
    if (store.containsKey(LocalKeys.carts)) return;

    final now = DateTime.now();

    final users = <String, Map<String, dynamic>>{};
    void addUser(
      String id,
      String name,
      String email,
      UserRole role, {
      String? ownedCartId,
      bool isBlocked = false,
      int createdDaysAgo = 30,
    }) {
      final salt = LocalPassword.newSalt();
      users[id] = <String, dynamic>{
        ...UserProfileModel(
          id: id,
          name: name,
          email: email,
          role: role,
          isBlocked: isBlocked,
          ownedCartId: ownedCartId,
          createdAt: now.subtract(Duration(days: createdDaysAgo)),
        ).toMap(),
        'salt': salt,
        'passwordHash': LocalPassword.hash(demoPassword, salt),
      };
    }

    addUser('user-admin', 'Ada Admin', adminEmail, UserRole.admin,
        createdDaysAgo: 120);
    addUser('user-maya', 'Maya Chowdhury', customerEmail, UserRole.customer,
        createdDaysAgo: 45);
    addUser('owner-1', 'Nabil Rahman', ownerEmail, UserRole.owner,
        ownedCartId: 'cart-1', createdDaysAgo: 90);
    addUser('user-samir', 'Samir Ahmed', 'samir@demo.com', UserRole.customer,
        createdDaysAgo: 6);

    for (var i = 2; i <= 7; i++) {
      addUser('owner-$i', _ownerNames[i - 2], 'owner$i@demo.com',
          UserRole.owner,
          ownedCartId: 'cart-$i', createdDaysAgo: 60 + i);
    }

    final carts = <String, Map<String, dynamic>>{};
    for (final spec in _cartSpecs) {
      carts[spec.id] = FoodCartModel(
        id: spec.id,
        name: spec.name,
        category: spec.category,
        locationLabel: spec.locationLabel,
        ownerId: spec.ownerId,
        description: spec.description,
        latitude: spec.latitude,
        longitude: spec.longitude,
        isOpen: spec.isOpen,
        isFeatured: spec.id == 'cart-1',
        followersCount: spec.followers,
        scheduleEntries: _weeklySchedule(
          spec.id,
          openMinute: spec.openMinute,
          closeMinute: spec.closeMinute,
          locationLabel: spec.locationLabel,
        ),
        lastLocationAt: now.subtract(Duration(minutes: 12 * spec.followers % 90)),
        updatedAt: now.subtract(Duration(hours: spec.followers % 12)),
      ).toMap();
    }

    // Maya already follows Momo House, matching the prototype's initial state.
    final follows = <String, Map<String, dynamic>>{
      FollowModel.idFor('user-maya', 'cart-1'): FollowModel(
        id: FollowModel.idFor('user-maya', 'cart-1'),
        userId: 'user-maya',
        cartId: 'cart-1',
        followedAt: now.subtract(const Duration(days: 2)),
        proximityAlertKm: AppConstants.alertRadiusKm.round(),
      ).toMap(),
      FollowModel.idFor('user-maya', 'cart-3'): FollowModel(
        id: FollowModel.idFor('user-maya', 'cart-3'),
        userId: 'user-maya',
        cartId: 'cart-3',
        followedAt: now.subtract(const Duration(days: 5)),
        proximityAlertKm: AppConstants.alertRadiusKm.round(),
      ).toMap(),
    };

    final updates = <String, Map<String, dynamic>>{
      'update-1': CartUpdateModel(
        id: 'update-1',
        cartId: 'cart-1',
        cartName: 'Momo House',
        ownerId: 'owner-1',
        type: CartUpdateType.moved,
        message: 'Momo House is now serving near Riverside Park.',
        locationLabel: 'Riverside Park',
        latitude: 23.8103,
        longitude: 90.4125,
        createdAt: now.subtract(const Duration(minutes: 12)),
      ).toMap(),
      'update-2': CartUpdateModel(
        id: 'update-2',
        cartId: 'cart-2',
        cartName: 'The Green Bowl',
        ownerId: 'owner-2',
        type: CartUpdateType.scheduleChanged,
        message: 'The Green Bowl updated its weekly schedule.',
        createdAt: now.subtract(const Duration(hours: 20)),
      ).toMap(),
      'update-3': CartUpdateModel(
        id: 'update-3',
        cartId: 'cart-3',
        cartName: 'Chai Chapter',
        ownerId: 'owner-3',
        type: CartUpdateType.opened,
        message: 'Chai Chapter is open now.',
        locationLabel: 'Oak Street',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ).toMap(),
    };

    final reports = <String, Map<String, dynamic>>{
      'report-1': ReportModel(
        id: 'report-1',
        targetType: ReportTargetType.cart,
        targetId: 'cart-5',
        targetName: 'Dosa Dash',
        reporterId: 'user-samir',
        reporterName: 'Samir Ahmed',
        reason: ReportReason.wrongLocation,
        note: 'The pin has been two streets off all week.',
        createdAt: now.subtract(const Duration(hours: 30)),
      ).toMap(),
      'report-2': ReportModel(
        id: 'report-2',
        targetType: ReportTargetType.cart,
        targetId: 'cart-6',
        targetName: 'Noodle Van',
        reporterId: 'user-maya',
        reporterName: 'Maya Chowdhury',
        reason: ReportReason.fakeListing,
        note: 'Listed as open but the cart has not appeared in days.',
        createdAt: now.subtract(const Duration(days: 3)),
      ).toMap(),
    };

    await store.writeCollection(LocalKeys.users, users);
    await store.writeCollection(LocalKeys.carts, carts);
    await store.writeCollection(LocalKeys.follows, follows);
    await store.writeCollection(LocalKeys.cartUpdates, updates);
    await store.writeCollection(LocalKeys.reports, reports);
    await store.writeCollection(
      LocalKeys.notifications,
      <String, Map<String, dynamic>>{},
    );
  }

  static List<ScheduleEntry> _weeklySchedule(
    String cartId, {
    required int openMinute,
    required int closeMinute,
    required String locationLabel,
  }) {
    return <ScheduleEntry>[
      for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
        ScheduleEntry(
          id: '$cartId-day-$weekday',
          weekday: weekday,
          openMinute: openMinute,
          closeMinute: closeMinute,
          locationLabel: locationLabel,
        ),
    ];
  }

  static const List<String> _ownerNames = <String>[
    'Priya Das',
    'Tanvir Islam',
    'Rosa Martinez',
    'Imran Hossain',
    'Lina Park',
    'Farah Noor',
  ];

  static const List<_CartSpec> _cartSpecs = <_CartSpec>[
    _CartSpec(
      id: 'cart-1',
      name: 'Momo House',
      category: 'Nepali street food',
      locationLabel: 'Riverside Park',
      ownerId: 'owner-1',
      description: 'Hand-folded steamed and fried momos with house chutney.',
      latitude: 23.8103,
      longitude: 90.4125,
      isOpen: true,
      followers: 248,
      openMinute: 690,
      closeMinute: 1290,
    ),
    _CartSpec(
      id: 'cart-2',
      name: 'The Green Bowl',
      category: 'Fresh salads & bowls',
      locationLabel: 'Gulshan Avenue',
      ownerId: 'owner-2',
      description: 'Cold-pressed dressings and grain bowls made to order.',
      latitude: 23.8125,
      longitude: 90.4160,
      isOpen: false,
      followers: 121,
      openMinute: 690,
      closeMinute: 840,
    ),
    _CartSpec(
      id: 'cart-3',
      name: 'Chai Chapter',
      category: 'Tea, coffee & bites',
      locationLabel: 'Oak Street',
      ownerId: 'owner-3',
      description: 'Masala chai brewed to order, plus samosas and biscuits.',
      latitude: 23.8065,
      longitude: 90.4099,
      isOpen: true,
      followers: 86,
      openMinute: 420,
      closeMinute: 1140,
    ),
    _CartSpec(
      id: 'cart-4',
      name: 'Taco Tuk',
      category: 'Loaded tacos & street corn',
      locationLabel: 'Banani Field',
      ownerId: 'owner-4',
      description: 'Corn tortillas pressed on the cart, three salsas daily.',
      latitude: 23.8180,
      longitude: 90.4078,
      isOpen: true,
      followers: 74,
      openMinute: 720,
      closeMinute: 1320,
    ),
    _CartSpec(
      id: 'cart-5',
      name: 'Dosa Dash',
      category: 'Crispy dosas & chutney',
      locationLabel: 'Dhanmondi Lake',
      ownerId: 'owner-5',
      description: 'Paper-thin dosas off a 24-inch griddle.',
      latitude: 23.8008,
      longitude: 90.4192,
      isOpen: false,
      followers: 59,
      openMinute: 1020,
      closeMinute: 1290,
    ),
    _CartSpec(
      id: 'cart-6',
      name: 'Noodle Van',
      category: 'Wok noodles & dumplings',
      locationLabel: 'Mohakhali Circle',
      ownerId: 'owner-6',
      description: 'High-heat wok noodles and pan-fried dumplings.',
      latitude: 23.8195,
      longitude: 90.4180,
      isOpen: true,
      followers: 103,
      openMinute: 660,
      closeMinute: 1230,
    ),
    _CartSpec(
      id: 'cart-7',
      name: 'Sweet Wheels',
      category: 'Waffles, crepes & shakes',
      locationLabel: 'Hatirjheel Promenade',
      ownerId: 'owner-7',
      description: 'Belgian waffles, thin crepes and thick shakes.',
      latitude: 23.7978,
      longitude: 90.4055,
      isOpen: true,
      followers: 132,
      openMinute: 900,
      closeMinute: 1380,
    ),
  ];
}

class _CartSpec {
  const _CartSpec({
    required this.id,
    required this.name,
    required this.category,
    required this.locationLabel,
    required this.ownerId,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.isOpen,
    required this.followers,
    required this.openMinute,
    required this.closeMinute,
  });

  final String id;
  final String name;
  final String category;
  final String locationLabel;
  final String ownerId;
  final String description;
  final double latitude;
  final double longitude;
  final bool isOpen;
  final int followers;
  final int openMinute;
  final int closeMinute;
}
