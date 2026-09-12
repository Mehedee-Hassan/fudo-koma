# Follo Cart

A map-first Flutter app for discovering and following mobile food carts.

## Run

```bash
flutter pub get
flutter run
```

**It runs with zero credentials.** With no Firebase project configured, the app
starts in local mode: a seeded dataset of seven carts, working accounts, real
follows, and real proximity alerts — all stored on the device. Add Firebase
(see `SETUP_FIREBASE.md`) and it switches automatically.

### Build flags

| Flag | Purpose |
|---|---|
| `--dart-define=FOLLO_BACKEND=local` | Force local mode even with real credentials present (useful for QA and CI). |
| `--dart-define=FOLLO_BACKEND=firebase` | Force Firebase mode. Default is `auto`. |
| `--dart-define=MAPBOX_TOKEN=pk.…` | Use Mapbox tiles. Without it the map uses OpenStreetMap. |
| `--dart-define=ADMIN_CODE=…` | Make "Admin" selectable at registration, gated on this code. |

### Demo accounts (debug builds, local mode)

The welcome screen shows three **one-tap sign-in** buttons — Customer, Owner,
Admin — so you never have to type credentials on a device. To sign in manually:

| Role | Email | Password |
|---|---|---|
| Customer | `demo@demo.com` | `demo1234` |
| Cart owner | `owner@demo.com` | `demo1234` |
| Admin | `admin@demo.com` | `demo1234` |

The customer account starts out following two carts, and the owner account owns
Momo House (248 followers, with activity history) so the owner screens have real
data to show. Release builds hide this panel entirely.

## Architecture

```
lib/
  core/          constants, build config, backend detection, formatters
  models/        the data layer — one FoodCartModel, schedules, reports, …
  repositories/  abstract interfaces + local/ and firestore/ implementations
  state/         ChangeNotifier controllers, composed with provider
  services/      location, proximity, notification gateways, fan-out
  screens/       auth, shell, explore, following, updates, profile, owner, admin
  widgets/       shared presentation
```

**The seam is `RepositoryBundle`.** Six interfaces (`AuthRepository`,
`CartRepository`, `FollowRepository`, `NotificationRepository`,
`ModerationRepository`, `MediaRepository`) each have a local and a Firebase
implementation. `AppBootstrap` picks a set at startup based on whether
`firebase_options.dart` holds real values, and the UI never knows which is
active.

Reads are `Stream`s and writes are `Future`s in both backends, so no screen
ever has to reload after a write.

`FolloCartApp` takes its repositories, location service, and notification
gateway as constructor arguments. `main()` is the only place that builds the
real ones — which is how the widget tests run without touching geolocator,
shared_preferences, image_picker, or flutter_local_notifications.

## The 5 km radius

One constant, `AppConstants.alertRadiusKm`, drives the map circle, the
proximity monitor, the per-follow default, and all UI copy.

Alert policy: a 6-hour cooldown per cart, cleared early once the user is seen
beyond 7.5 km (so a genuine return alerts again), and capped at five proximity
notifications per hour.

## What needs a server

Delivering a push to a **closed** app cannot be done from a client — the FCM
HTTP v1 API needs service-account credentials that must never ship in an app.
The client half (token registration, foreground/background/terminated handlers,
document shapes) is implemented; `SETUP_FIREBASE.md` carries the Cloud Function
sketch. Cross-device *in-app* updates work today in Firebase mode.

## Security

`firestore.rules` and `storage.rules` are the real enforcement: they deny
client writes to `role` and `isBlocked`, block writes from blocked users, and
restrict photo uploads to a cart's owner. The app's own checks are a UX
convenience on top.

Local mode stores salted SHA-256 password digests — never raw passwords — but
SharedPreferences is plaintext at rest and SHA-256 is not a password KDF. It is
demo-grade by design; see the note at the top of `local_password.dart`.

## Test

```bash
flutter analyze
flutter test
```

90 tests: repository behaviour, proximity maths and cooldown policy, model wire
codecs, and widget tests covering guest browsing, registration, role gating,
following, admin moderation, and proximity alerts end to end.

<img width="504" height="934" alt="Follo Cart explore screen" src="https://github.com/user-attachments/assets/37bb1531-af55-4225-a731-95906a7e2bc5" />
