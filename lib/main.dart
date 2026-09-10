import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    debugPrint(
      'Firebase is not configured yet. Replace the values in lib/firebase_options.dart with your real Firebase project settings.',
    );
  }

  runApp(const FolloCartApp());
}

class FolloCartApp extends StatelessWidget {
  const FolloCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Follo Cart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F8F4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B5B),
          primary: const Color(0xFF176B5B),
          secondary: const Color(0xFFE66D45),
          surface: const Color(0xFFF7F8F4),
        ),
        fontFamily: 'Avenir',
        useMaterial3: true,
      ),
      home: const Shell(),
    );
  }
}

enum UserRole { customer, owner, admin }

class FoodCart {
  FoodCart({
    required this.name,
    required this.category,
    required this.distance,
    required this.eta,
    required this.color,
    required this.position,
    required this.isOpen,
    required this.followers,
    this.isFollowed = false,
  });

  final String name;
  final String category;
  final String distance;
  final String eta;
  final Color color;
  final Offset position;
  bool isOpen;
  final int followers;
  bool isFollowed;
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int selectedTab = 0;
  UserRole role = UserRole.customer;
  FoodCart? selectedCart;
  bool ownerStopPublished = false;
  bool sampleUserBlocked = false;

  final carts = <FoodCart>[
    FoodCart(
      name: 'Momo House',
      category: 'Nepali street food',
      distance: '0.8 km away',
      eta: 'Open until 9:30 PM',
      color: Color(0xFFE66D45),
      position: Offset(0.29, 0.31),
      isOpen: true,
      followers: 248,
      isFollowed: true,
    ),
    FoodCart(
      name: 'The Green Bowl',
      category: 'Fresh salads & bowls',
      distance: '1.7 km away',
      eta: 'Opens at 11:30 AM',
      color: Color(0xFF3C8B70),
      position: Offset(0.70, 0.48),
      isOpen: false,
      followers: 121,
    ),
    FoodCart(
      name: 'Chai Chapter',
      category: 'Tea, coffee & bites',
      distance: '2.6 km away',
      eta: 'Open until 7:00 PM',
      color: Color(0xFFE1A43A),
      position: Offset(0.49, 0.73),
      isOpen: true,
      followers: 86,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: selectedTab,
          children: [
            _buildExplore(),
            _buildFollowing(),
            _buildUpdates(),
            _buildProfile(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD9EEE6),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Following'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildExplore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good morning, Maya', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    const Text('Find your next bite', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  ],
                ),
              ),
              _roundIcon(Icons.tune_rounded),
              const SizedBox(width: 8),
              CircleAvatar(backgroundColor: const Color(0xFF176B5B), child: const Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: _searchField()),
              const SizedBox(width: 10),
              _roundIcon(Icons.my_location_rounded, background: const Color(0xFFFFE8DE), foreground: const Color(0xFFE66D45)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('Near you now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const Spacer(),
              Text('3 carts', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _mapArea()),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE3E7E1))),
      child: const TextField(
        decoration: InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.search, color: Color(0xFF176B5B)), hintText: 'Search food carts', hintStyle: TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _roundIcon(IconData icon, {Color background = Colors.white, Color foreground = const Color(0xFF24342F)}) {
    return Container(width: 46, height: 46, decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE3E7E1))), child: Icon(icon, color: foreground, size: 21));
  }

  Widget _mapArea() {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: MapPainter(carts: carts))),
        Positioned(top: 18, left: 18, child: _mapPill(Icons.layers_outlined, 'Map view')),
        Positioned(top: 18, right: 18, child: _mapPill(Icons.near_me_outlined, '3 km')),
        ...carts.map((cart) => Positioned(
              left: MediaQuery.of(context).size.width * cart.position.dx - 23,
              top: MediaQuery.of(context).size.height * cart.position.dy - 120,
              child: GestureDetector(onTap: () => setState(() => selectedCart = cart), child: _cartMarker(cart)),
            )),
        if (selectedCart != null) Positioned(left: 14, right: 14, bottom: 14, child: _cartDetail(selectedCart!)),
      ],
    );
  }

  Widget _mapPill(IconData icon, String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: const Color(0xFF176B5B)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]));
  }

  Widget _cartMarker(FoodCart cart) {
    return Column(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: cart.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8)]), child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 23)), Container(width: 2, height: 7, color: cart.color)]);
  }

  Widget _cartDetail(FoodCart cart) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: cart.color.withAlpha(32), borderRadius: BorderRadius.circular(15)), child: Icon(Icons.restaurant_rounded, color: cart.color, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cart.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(cart.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), const SizedBox(height: 7), Row(children: [Icon(Icons.near_me, size: 13, color: cart.color), const SizedBox(width: 4), Text(cart.distance, style: TextStyle(color: cart.color, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(width: 10), Container(width: 7, height: 7, decoration: BoxDecoration(color: cart.isOpen ? const Color(0xFF4AAE7D) : Colors.grey, shape: BoxShape.circle)), const SizedBox(width: 4), Text(cart.isOpen ? 'Open now' : 'Closed', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])])),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => setState(() => cart.isFollowed = !cart.isFollowed), style: FilledButton.styleFrom(backgroundColor: cart.isFollowed ? const Color(0xFFD9EEE6) : const Color(0xFF176B5B), foregroundColor: cart.isFollowed ? const Color(0xFF176B5B) : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11)), child: Text(cart.isFollowed ? 'Following' : 'Follow', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowing() {
    final followed = carts.where((cart) => cart.isFollowed).toList();
    return _simplePage('Your followed carts', 'Get notified when they move, open, or update their schedule.', followed.map((cart) => _cartListTile(cart)).toList());
  }

  Widget _buildUpdates() {
    return _simplePage('Latest updates', 'Your food cart activity in one place.', [
      _updateTile(Icons.near_me, const Color(0xFFE66D45), 'Momo House is 0.8 km away', 'Arrived near Riverside Park · 12 min ago'),
      _updateTile(Icons.schedule, const Color(0xFF3C8B70), 'The Green Bowl changed schedule', 'Today, 11:30 AM – 2:00 PM · Yesterday'),
      _updateTile(Icons.storefront, const Color(0xFFE1A43A), 'Chai Chapter is open', 'Serving near Oak Street · Monday'),
    ]);
  }

  Widget _buildProfile() {
    return _simplePage('Your profile', 'Manage your Follo Cart experience.', [
      const SizedBox(height: 4),
      _roleSwitcher(),
      const SizedBox(height: 12),
      _roleWorkspace(),
      const SizedBox(height: 12),
      _settingTile(Icons.notifications_outlined, 'Notifications', 'Schedule, opening status, and nearby alerts'),
      _settingTile(Icons.location_on_outlined, 'Location alerts', 'Notify me within 3 km of followed carts'),
      _settingTile(Icons.help_outline, 'Help & feedback', 'Tell us how to make Follo Cart better'),
    ]);
  }

  Widget _simplePage(String title, String subtitle, List<Widget> children) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 30), children: [Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.5)), const SizedBox(height: 6), Text(subtitle, style: TextStyle(color: Colors.grey.shade600, height: 1.4)), const SizedBox(height: 22), ...children]);
  }

  Widget _cartListTile(FoodCart cart) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3E7E1))), child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: cart.color.withAlpha(32), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.restaurant_rounded, color: cart.color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cart.name, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${cart.distance} · ${cart.isOpen ? 'Open now' : 'Closed'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])), Icon(Icons.chevron_right, color: Colors.grey.shade500)]));
  }

  Widget _updateTile(IconData icon, Color color, String title, String detail) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3E7E1))), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))]))]));
  }

  Widget _roleSwitcher() {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF176B5B), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Preview role', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Wrap(spacing: 8, children: UserRole.values.map((item) => ChoiceChip(label: Text(_roleLabel(item)), selected: role == item, onSelected: (_) => setState(() => role = item), selectedColor: Colors.white, backgroundColor: Colors.white24, labelStyle: TextStyle(color: role == item ? const Color(0xFF176B5B) : Colors.white, fontWeight: FontWeight.w700))).toList())]));
  }

  Widget _roleWorkspace() {
    if (role == UserRole.customer) {
      return _workspaceCard(
        Icons.explore_outlined,
        'Customer view',
        'Discover nearby carts, follow favorites, and get a 3 km arrival alert.',
        'Open map',
      );
    }
    if (role == UserRole.owner) {
      return _workspaceCard(
        Icons.storefront_outlined,
        'Cart owner studio',
        'Update your live location, set open hours, and publish your next stop.',
        'Manage my cart',
      );
    }
    return _workspaceCard(
      Icons.admin_panel_settings_outlined,
      'Admin console',
      'Review reported accounts, moderate carts, and manage platform activity.',
      'Open console',
    );
  }

  Widget _workspaceCard(IconData icon, String title, String detail, String action) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3E7E1))),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFD9EEE6), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF176B5B))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.35))])),
          const SizedBox(width: 8),
          IconButton(onPressed: () => _openRoleWorkspace(), tooltip: action, icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF176B5B))),
        ],
      ),
    );
  }

  Future<void> _openRoleWorkspace() async {
    if (role == UserRole.customer) {
      setState(() => selectedTab = 0);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F8F4),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: role == UserRole.owner ? _ownerWorkspace() : _adminWorkspace(),
      ),
    );
  }

  Widget _ownerWorkspace() {
    final cart = carts.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('Cart owner studio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('Momo House · Riverside Park', style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 18),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Shop is open', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(cart.isOpen ? 'Customers can see you are open now.' : 'Customers see your shop as closed.'), value: cart.isOpen, onChanged: (value) => setState(() => cart.isOpen = value)),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule, color: Color(0xFF176B5B)), title: const Text('Today\'s hours', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('11:30 AM – 9:30 PM'), trailing: const Icon(Icons.chevron_right)),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.location_on_outlined, color: Color(0xFF176B5B)),
        title: Text(ownerStopPublished ? 'Next stop published' : 'Publish next stop', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(ownerStopPublished ? 'Oak Street · Tomorrow at 12:00 PM' : 'Tell followers where you will be next.'),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            setState(() => ownerStopPublished = true);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OwnerDashboardScreen()),
            );
          },
        ),
      ),
    ]);
  }

  Widget _adminWorkspace() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('Admin console', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      Text('Moderation queue · 1 item', style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 18),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(backgroundColor: Color(0xFFFFE8DE), child: Icon(Icons.person_outline, color: Color(0xFFE66D45))),
        title: const Text('Sample account', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sampleUserBlocked ? 'Blocked from the platform' : 'Reported for review'),
        trailing: sampleUserBlocked
            ? const Icon(Icons.check_circle, color: Color(0xFF3C8B70))
            : TextButton(
                onPressed: () {
                  setState(() => sampleUserBlocked = true);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                  );
                },
                child: const Text('Block'),
              ),
      ),
      const SizedBox(height: 8),
      const Text('Admin actions will connect to real user records and reports when a backend is added.', style: TextStyle(fontSize: 12, height: 1.4)),
    ]);
  }

  String _roleLabel(UserRole value) => switch (value) { UserRole.customer => 'Customer', UserRole.owner => 'Cart owner', UserRole.admin => 'Admin' };

  Widget _settingTile(IconData icon, String title, String detail) {
    return ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 4), leading: Icon(icon, color: const Color(0xFF176B5B)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(detail, style: const TextStyle(fontSize: 12)), trailing: const Icon(Icons.chevron_right));
  }
}

class MapPainter extends CustomPainter {
  MapPainter({required this.carts});
  final List<FoodCart> carts;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFFEAF0E9);
    canvas.drawRect(Offset.zero & size, base);
    final blocks = Paint()..color = const Color(0xFFDCE7DC)..style = PaintingStyle.fill;
    final roads = Paint()..color = const Color(0xFFF7F8F4)..strokeWidth = 17..strokeCap = StrokeCap.round;
    final roadLines = Paint()..color = const Color(0xFFD5DDD2)..strokeWidth = 1.3;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.08 + i * 0.17);
      canvas.drawRect(Rect.fromLTWH(x, size.height * 0.08, size.width * 0.10, size.height * 0.22), blocks);
      canvas.drawRect(Rect.fromLTWH(x + 20, size.height * 0.66, size.width * 0.13, size.height * 0.18), blocks);
    }
    final path = Path()..moveTo(-20, size.height * .62)..cubicTo(size.width * .3, size.height * .4, size.width * .55, size.height * .84, size.width + 20, size.height * .26);
    canvas.drawPath(path, roads);
    canvas.drawPath(path, roadLines);
    final cross = Path()..moveTo(size.width * .12, -20)..cubicTo(size.width * .42, size.height * .25, size.width * .30, size.height * .62, size.width * .84, size.height + 20);
    canvas.drawPath(cross, roads);
    canvas.drawPath(cross, roadLines);
    final park = Paint()..color = const Color(0xFFC9E0C7);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .55, size.height * .12, size.width * .28, size.height * .16), const Radius.circular(24)), park);
    final you = Offset(size.width * .44, size.height * .49);
    canvas.drawCircle(you, 22, Paint()..color = const Color(0x33176B5B));
    canvas.drawCircle(you, 8, Paint()..color = const Color(0xFF176B5B));
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => false;
}

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner dashboard'),
        backgroundColor: const Color(0xFFF7F8F4),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Momo House', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Riverside Park • Street food', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          _ownerMetricCard('Current status', 'Open now', const Color(0xFF3C8B70)),
          const SizedBox(height: 12),
          _ownerMetricCard('Today\'s hours', '11:30 AM – 9:30 PM', const Color(0xFF176B5B)),
          const SizedBox(height: 12),
          _ownerMetricCard('Followers', '248', const Color(0xFFE66D45)),
          const SizedBox(height: 18),
          const Text('Manage your cart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF176B5B)),
            title: const Text('Upload photos'),
            subtitle: const Text('Add menu shots and cart branding'),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.location_on_outlined, color: Color(0xFF176B5B)),
            title: const Text('Set next stop'),
            subtitle: const Text('Oak Street • Tomorrow • 12:00 PM'),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF176B5B)),
            title: const Text('Push notifications'),
            subtitle: const Text('Followers receive open, close, and schedule alerts'),
          ),
        ],
      ),
    );
  }

  Widget _ownerMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withAlpha(35), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.storefront_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        backgroundColor: const Color(0xFFF7F8F4),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Moderation center', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Review reports and protect the marketplace', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          _adminReportCard('Spam report', 'Chef Nabil', 'Auto-suspend candidate', const Color(0xFFE66D45)),
          const SizedBox(height: 12),
          _adminReportCard('Fake listing', 'Green Bites', 'Pending review', const Color(0xFFE1A43A)),
          const SizedBox(height: 12),
          _adminReportCard('Location abuse', 'Momo House', 'Flagged by 3 users', const Color(0xFF3C8B70)),
          const SizedBox(height: 18),
          const Text('Platform stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statTile('Active carts', '128', const Color(0xFF176B5B))),
            const SizedBox(width: 12),
            Expanded(child: _statTile('Followers', '12.4k', const Color(0xFFE66D45))),
          ]),
        ],
      ),
    );
  }

  Widget _adminReportCard(String title, String subject, String note, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7E1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.flag_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subject, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Text(note, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withAlpha(80))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
