# Follo Cart App

## What currently works

A working food cart discovery and follow app. It runs today with **zero
credentials** against on-device storage, and switches to Firebase once a real
project is configured.

### Accounts and roles
- Email and password registration and sign-in.
- Seeded demo accounts with one-tap sign-in per role in debug builds.
- Browse-without-login guest mode; following requires an account.
- Customer, cart owner, and admin roles, chosen at registration.
- Admin is never self-service — it needs an `ADMIN_CODE` build flag.
- Sessions survive an app restart.
- Blocked accounts are refused at sign-in and ejected mid-session.

### Data
- A repository layer with two complete implementations: on-device
  (SharedPreferences) and Firestore, chosen automatically at startup.
- Follows, carts, schedules, photos, updates, and reports all persist.
- Reads are live streams, so every screen reacts to a write with no manual
  refresh.

### Map and location
- Real `flutter_map` with OpenStreetMap tiles, switching to Mapbox when a
  `MAPBOX_TOKEN` is supplied.
- Live GPS: the map centres on the user and draws the 5 km alert radius.
- Distances are computed from the user's actual position, in metres below a
  kilometre.
- Search and an open-now filter, sorted nearest-first.

### Cart owners
- Create and edit a cart; upload photos from camera or gallery.
- Open/closed toggle, a weekly schedule editor, and a dated "next stop" with an
  optional map-picked pin.
- Live location sharing from a GPS stream, with an Android foreground service.
- Post announcements to followers.

### Notifications and alerts
- System notifications for followed carts within 5 km, reporting the real
  distance.
- A 6-hour per-cart cooldown, an exit-reset, and a 5-per-hour cap.
- Owner actions fan out to every follower's inbox.
- A per-cart alert radius (1–10 km) and per-cart notification toggle.

### Admin
- A moderation queue fed by a real customer-facing report flow.
- User directory with search, block, and unblock.
- Blocking cascades: the account cannot sign in and its cart leaves the map.
- Guards against blocking yourself or the last remaining admin.

### Engineering
- Clean `flutter analyze`; 90 passing tests (unit and widget).
- Widget tests inject fake repositories, so no plugin is touched under test.
- Firestore and Storage security rules included.

## Current limitations

- **Local mode is single-device.** Follows and updates persist across restarts
  but do not sync between devices. Firebase mode syncs.
- **Local credential storage is demo-grade.** Passwords are salted and hashed,
  never stored raw, but SharedPreferences is plaintext at rest and SHA-256 is
  not a password KDF. Use Firebase mode for anything real.
- **Push to a closed app needs a server.** A client cannot send FCM securely.
  Token registration and all client handlers are in place; the Cloud Function
  that reads follows and sends is documented in `SETUP_FIREBASE.md` but not
  deployed.
- **iOS background proximity is limited.** Alerts work while the app is open or
  recently backgrounded. A fully suspended iOS app runs no Dart; true
  geofencing needs `CLCircularRegion` (20-region cap) or server push.
- **Android background sharing is opt-in and OEM-dependent.** Some launchers
  kill the foreground service on swipe-away.
- Firebase requires `flutterfire configure` plus `google-services.json` /
  `GoogleService-Info.plist` — see `SETUP_FIREBASE.md`.
- One cart per owner.
- Cart ownership claiming is debug-only; real transfer needs server verification.
- iOS build testing requires macOS and Xcode.

## Next development phase

1. Deploy the Cloud Function for cross-device push on followed-cart changes.
2. iOS geofencing via a `CLCircularRegion` platform channel for the 20 nearest
   followed carts.
3. Server-side geo queries so the nearby filter is not client-side.
4. Multi-cart owners.
5. Ratings and reviews.
6. Marker clustering for dense areas.
7. Admin custom claims instead of a role field on the user document.
8. Move `applicationId` off `com.example.*` before any store release.
