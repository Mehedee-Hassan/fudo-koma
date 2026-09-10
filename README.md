# Follo Cart

A Flutter prototype for discovering and following mobile food carts.

## Run

```bash
flutter pub get
flutter run
```

The first pass is intentionally package-free. The map is a custom-painted interaction surface so the map-first experience works without API keys. Replace `MapPainter` with Google Maps, Mapbox, or Apple MapKit when the backend and platform keys are ready.

## Product foundation

- Explore opens on a local map with live/open status and 3 km context.
- Normal users can browse without login and follow carts for updates.
- Customers can follow carts and review schedule, opening, and nearby updates.
- Food cart owners can publish location updates and store open/closed status.
- Admins can review reported users and block abusive accounts.
- `FoodCart` is the local model boundary for later API, GPS, photo, and notification integrations.

<<<<<<< HEAD

<img width="504" height="934" alt="Screenshot from 2026-09-09 20-25-56" src="https://github.com/user-attachments/assets/37bb1531-af55-4225-a731-95906a7e2bc5" />
=======
## Firebase-ready architecture

- `lib/models/` contains the core data models for users, carts, follows, and notifications.
- `lib/services/firestore_service.dart` provides the replacement seam for Firestore-backed business logic.
- `lib/firebase_options.dart` is the config file intended to be replaced by `flutterfire configure` output.
- `SETUP_FIREBASE.md` explains how to enable Firebase for this app.
>>>>>>> 4b73832 (data mock)
