enum UserRole {
  customer,
  owner,
  admin;

  static UserRole fromWire(String? value) => switch (value) {
        'owner' => UserRole.owner,
        'admin' => UserRole.admin,
        _ => UserRole.customer,
      };

  String get wire => name;

  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.owner => 'Cart owner',
        UserRole.admin => 'Admin',
      };

  String get blurb => switch (this) {
        UserRole.customer =>
          'Discover nearby carts, follow favourites, and get a 5 km arrival alert.',
        UserRole.owner =>
          'Update your live location, set open hours, and publish your next stop.',
        UserRole.admin =>
          'Review reported accounts, moderate carts, and manage platform activity.',
      };
}
