import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'services/location_service.dart';

Future<void> main() async {
  try {
    final dependencies = await AppBootstrap.run();
    runApp(FolloCartApp.fromDependencies(
      dependencies: dependencies,
      locationService: const GeolocatorLocationService(),
    ));
  } catch (error, stack) {
    // A failed bootstrap used to mean a white screen with a debugPrint.
    debugPrint('Bootstrap failed: $error\n$stack');
    runApp(BootstrapErrorApp(error: error));
  }
}

class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 14),
                const Text(
                  'Follo Cart could not start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
