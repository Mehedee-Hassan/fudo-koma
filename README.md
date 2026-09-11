# Follo Cart

A Flutter prototype for discovering and following mobile food carts.

## Run

```bash
flutter pub get
flutter run
```

The map uses `flutter_map`. It shows OpenStreetMap tiles while `YOUR_MAPBOX_ACCESS_TOKEN` is still configured, and switches to Mapbox streets automatically after a real token is added in `lib/config/mapbox_config.dart`.

The map requests the user's location, centers on it when permission is granted, and draws the 5 km alert radius around that location.

## Product foundation

- Explore opens on a local map with live/open status and 3 km context.
- Normal users can browse without login and follow carts for updates.
- Customers can follow carts and review schedule, opening, and nearby updates.
- Food cart owners can publish location updates and store open/closed status.
- Admins can review reported users and block abusive accounts.
- `FoodCart` is the local model boundary for later API, GPS, photo, and notification integrations.



<img width="504" height="934" alt="Screenshot from 2026-09-09 20-25-56" src="https://github.com/user-attachments/assets/37bb1531-af55-4225-a731-95906a7e2bc5" />
=======
## Firebase-ready architecture

- `lib/models/` contains the core data models for users, carts, follows, and notifications.
- `lib/services/firestore_service.dart` provides the replacement seam for Firestore-backed business logic.
- `lib/firebase_options.dart` is the config file intended to be replaced by `flutterfire configure` output.
- `SETUP_FIREBASE.md` explains how to enable Firebase for this app.
