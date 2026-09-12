import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/backend_mode.dart';
import 'core/firebase_bootstrap.dart';
import 'repositories/local/local_media_repository.dart';
import 'repositories/local/local_seed.dart';
import 'repositories/local/local_store.dart';
import 'repositories/repository_bundle.dart';
import 'services/alert_cooldown_store.dart';
import 'services/local_notification_gateway.dart';
import 'services/notification_gateway.dart';

class AppDependencies {
  const AppDependencies({
    required this.bundle,
    required this.notifications,
    required this.cooldowns,
    required this.store,
  });

  final RepositoryBundle bundle;
  final NotificationGateway notifications;
  final AlertCooldownStore cooldowns;
  final LocalStore store;
}

abstract final class AppBootstrap {
  static Future<AppDependencies> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    final mode = await resolveBackendMode();

    // The cooldown ledger is device-local in both modes: it describes what this
    // device has already told this user, which is not shared state.
    final cooldowns = AlertCooldownStore(store);

    final NotificationGateway notifications =
        kIsWeb ? NoopNotificationGateway() : LocalNotificationGateway();
    await notifications.initialize();

    if (mode == BackendMode.firebase) {
      return AppDependencies(
        bundle: RepositoryBundle.firebase(),
        notifications: notifications,
        cooldowns: cooldowns,
        store: store,
      );
    }

    await LocalSeed.ensureSeeded(store);
    final bundle = RepositoryBundle.local(store);
    await (bundle.media as LocalMediaRepository).prefetch();

    return AppDependencies(
      bundle: bundle,
      notifications: notifications,
      cooldowns: cooldowns,
      store: store,
    );
  }
}
