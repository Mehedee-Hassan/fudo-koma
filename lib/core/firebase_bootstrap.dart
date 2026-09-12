import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_config.dart';
import 'backend_mode.dart';

const List<String> _placeholderMarkers = <String>[
  'REPLACE_WITH',
  'YOUR_',
  'CHANGEME',
  'XXX',
];

/// True when a config value is still a template stand-in.
bool looksPlaceholder(String? value) {
  if (value == null) return true;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  final upper = trimmed.toUpperCase();
  return _placeholderMarkers.any(upper.contains);
}

/// Pure, so it can be unit-tested without Firebase present.
bool optionsLookReal({
  String? apiKey,
  String? appId,
  String? projectId,
  String? messagingSenderId,
}) {
  return !looksPlaceholder(apiKey) &&
      !looksPlaceholder(appId) &&
      !looksPlaceholder(projectId) &&
      !looksPlaceholder(messagingSenderId);
}

bool firebaseOptionsLookReal() {
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    return optionsLookReal(
      apiKey: options.apiKey,
      appId: options.appId,
      projectId: options.projectId,
      messagingSenderId: options.messagingSenderId,
    );
  } catch (_) {
    // `currentPlatform` throws UnsupportedError on platforms the generated
    // file has no branch for (desktop). That is "not configured here", not a
    // failure - the previous blanket catch conflated the two.
    return false;
  }
}

Future<BackendMode> resolveBackendMode() async {
  switch (AppConfig.backendOverride) {
    case 'local':
      return BackendMode.local;
    case 'firebase':
      break;
    default:
      if (!firebaseOptionsLookReal()) return BackendMode.local;
  }

  try {
    // A syntactically valid but wrong config can leave initializeApp hanging
    // on some platforms; the bound keeps startup deterministic.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    return BackendMode.firebase;
  } catch (error) {
    debugPrint(
      'Firebase unavailable ($error). Falling back to local mode - see '
      'SETUP_FIREBASE.md to connect a project.',
    );
    return BackendMode.local;
  }
}
