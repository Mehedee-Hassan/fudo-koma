# Phase 2 — Implementation Log

Completed 2026-09-11. This is the record of the work that took Follo Cart from
a front-end prototype to a working app, covering all eight items from the
`txt.md` roadmap.

**Baseline:** 11 Dart files / 1,359 lines, of which `main.dart` was 823.
**Result:** 90 Dart files / 10,831 lines, `main.dart` down to 52.
**Tests:** 2 files / 7 tests → 10 files / **107 tests**, all passing.
`flutter analyze` is clean.

---

## Decisions taken before building

| Decision         | Choice                                                                                                                         |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Backend          | Local-first with a Firestore seam. Both implementations complete; selected at runtime. The app must run with zero credentials. |
| Scope            | All 8 roadmap items.                                                                                                           |
| Alert radius     | 5 km everywhere, from one constant.                                                                                            |
| State management | `provider` + `ChangeNotifier`.                                                                                                 |
| Guest follows    | Gated behind sign-in — see [Deviations](#deviations-from-the-original-spec).                                                   |

---

## 1. Starting state

Three problems shaped everything that followed.

- **The whole app was one file.** `main.dart` held the theme, routing, a God-object
  `_ShellState` with all state as plain fields, all four tabs as private build
  methods, and two hardcoded dashboard screens.
- **`lib/models/` and `lib/services/` were dead code.** Nothing imported them.
  The running app used a _second, incompatible_ `FoodCart` class declared inline
  in `main.dart` with presentation-only fields — a `Color`, a `CustomPainter`
  `Offset`, and a hardcoded `'0.8 km away'` string.
- **`FirestoreService` was a seam with no interface and no second
  implementation** — every method returned a hardcoded list or was an empty
  `return;`.

---

## 2. Platform configuration

- **Added `INTERNET` to the Android manifest.** It was declared only in
  `src/debug/` and `src/profile/`, so **release APKs had no network at all** —
  no map tiles, no Firestore, no FCM — failing silently in the one build nobody
  runs during development. Verified present in the merged release manifest of
  an actual built APK, not just in source.
- Added `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `POST_NOTIFICATIONS`,
  `WAKE_LOCK`, and the opt-in `ACCESS_BACKGROUND_LOCATION`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`.
- Added the five required `NSLocation*` / camera / photo keys plus
  `UIBackgroundModes` to `ios/Runner/Info.plist`. Without these, iOS terminates
  the app on its first location request.
- Enabled core-library desugaring in `android/app/build.gradle.kts`, required by
  `flutter_local_notifications`.
- Added `**/google-services.json` and `**/GoogleService-Info.plist` to
  `.gitignore`, which `SETUP_FIREBASE.md` had always warned about but nothing
  enforced.
- Deliberately **did not** add the `google-services` Gradle plugin: it fails the
  build when `google-services.json` is absent, which would break the
  zero-credential promise. Documented as a setup step instead.

**Deliberately not done:** `android.permission.CAMERA`. `image_picker` launches
the system camera by intent and needs no permission; declaring it would force a
runtime grant flow.

---

## 3. Architecture

### Model layer

- Deleted the inline `FoodCart`. `FoodCartModel` is now the single cart model,
  gaining `description`, `photoRefs`, `scheduleEntries`, `isActive`,
  `lastLocationAt`, `copyWith`, and value equality.
- **Removed `isFollowed` from the cart model.** Follow state is per-user and
  belongs to `FollowRepository`; caching it on a shared cart object is how two
  signed-in users end up seeing each other's follows.
- Colour moved to `CartPalette.colorFor(id, category)` — derived, not stored, so
  every backend round-trips a portable model. Uses FNV-1a rather than
  `String.hashCode`, which is not stable across platforms or SDK versions and
  would have rendered the same cart in different colours on web and Android.
- Distance is computed at render time from the user's real position via a
  `distanceKmFrom` extension.
- New models: `ScheduleEntry` (replaces a free-text schedule string, handles
  windows running past midnight), `CartUpdateModel`, `ReportModel`, `UserRole`.
- `NotificationModel.type` went from a loose `String` to an enum whose
  `fromWire` falls back to `system` on unknown values, so a document written by
  a newer client cannot break an older one.
- One wire format (`toMap`/`fromMap`, ISO-8601 dates, plain doubles) serves both
  backends. Trade-off accepted: no `serverTimestamp()`, no server-side geo
  queries.

### Repository layer — the seam

Six interfaces, each with a complete local **and** Firestore implementation:
`AuthRepository`, `CartRepository`, `FollowRepository`,
`NotificationRepository`, `ModerationRepository`, `MediaRepository`.

- **Reads are `Stream`s, writes are `Future`s** in both backends. This removes
  every manual "reload after write" call site — a whole class of stale-UI bugs.
- `LocalStore` is the entire local reactivity mechanism in ~40 lines:
  JSON-over-SharedPreferences with a broadcast channel, emitting current state
  then re-emitting on change — the same contract as a Firestore snapshot.
- `LocalSeed` ports the original seven carts with their real coordinates, so the
  visual design survived the refactor, plus owner/admin/customer accounts and
  sample reports. Demo credentials are short by design (`demo@demo.com` /
  `owner@demo.com` / `admin@demo.com`, password `demo1234`) because they get
  typed by hand on a phone, and the welcome screen offers one-tap sign-in per
  role in debug builds. The password still satisfies the same 8-character
  minimum the register screen enforces — demo data does not get a special case.
- `RepositoryBundle` replaces `FirestoreService` as the seam, with `.local()`
  and `.firebase()` factories.
- Firestore shape choices: `follows` uses a deterministic composite id
  (`{userId}_{cartId}`) so follow/unfollow need no query; notifications live in
  a per-user subcollection so no composite index is needed and the security rule
  is one line; schedule entries are embedded (bounded at ≤21, always read with
  the cart).
- `MediaRepository.imageFor` is the pivot that lets one interface cover three
  storage strategies — relative file paths locally, Storage URLs in Firebase,
  base64 data URIs on web. Takes `XFile`, not `File`, because web has no
  filesystem path.

### State layer

`provider` + `ChangeNotifier`, eight controllers: `SessionController`,
`CartController`, `FollowController`, `NotificationController`,
`LocationController`, `OwnerController`, `ModerationController`,
`ProximityController`.

Chosen over Riverpod/bloc/get_it because almost every controller depends on
another, and `ChangeNotifierProxyProvider` handles that in three lines per
dependency where hand-rolling means `addListener`/`removeListener` pairs and
disposal ordering by hand. Automatic `dispose()` also matters here: two
controllers hold GPS `StreamSubscription`s that would otherwise leak.

### Runtime backend selection

`resolveBackendMode()` checks `firebase_options.dart` for `REPLACE_WITH` /
`YOUR_` markers, then attempts `initializeApp` with an 8-second timeout,
falling back to local mode on any failure. Three improvements over the previous
blanket `try/catch (_)`:

1. The `UnsupportedError` from `currentPlatform` on desktop is now distinguished
   from an init failure — "not configured here", not "broken".
2. A timeout, so a valid-but-wrong config cannot hang startup.
3. A `--dart-define=FOLLO_BACKEND` override, so QA and CI are reproducible.

**Deleted `lib/firebase_service.dart`.** It held `FirebaseFirestore.instance`
and friends as eager `static final`s, which throw `[core/no-app]` when Firebase
is uninitialised — the app's default state. Firestore repositories are now only
constructed _after_ `initializeApp` succeeds.

---

## 4. The eight roadmap items

### 1. Authentication and role-based access ✅

Email/password register and sign-in; guest browsing; customer / owner / admin
roles; `RootRouter` gating on `AuthStatus`; sessions survive restart. Admin is
never self-service — it appears at registration only with an `ADMIN_CODE` build
flag _and_ requires typing the code. Both backends throw the same
`AuthException` with a neutral `AuthErrorCode`, so no screen ever string-matches
a Firebase error code.

Roles change what Profile offers, never which tabs exist — a role-dependent tab
index would break deep links and muscle memory.

### 2. Backend database ✅

Complete local and Firestore implementations behind the six interfaces above.
Follows, carts, schedules, photos, updates and reports all persist. **Follow
state surviving an app restart** was the headline limitation in the old
`txt.md`; it now has a dedicated test.

### 3. Map integration ✅

`flutter_map` was already real; this was cleanup. `CartMap` extracted and reused
by both Explore and the owner's next-stop picker. `MapboxConfig` became an
instance class reading `--dart-define=MAPBOX_TOKEN`, moved to `streets-v12` at
512px @2x, and gained an injectable `TileProvider` for tests.

### 4. Real GPS for cart owners ✅

`OwnerController` streams position with platform-specific `LocationSettings`, a
50 m distance filter, and a 30-second write bound so a fast-moving cart cannot
hammer the backend. A feed entry is published only after 250 m of real movement
— otherwise every follower would get a "cart moved" item every 30 seconds.
Sharing stops on sign-out, on dispose, and when the owner marks the cart closed.
A prior session's sharing state is persisted but **never auto-resumed** — that
would be a privacy trap and an app-review risk.

### 5. Photo upload and storage ✅

`image_picker` with compression at pick time. Local mode stores **relative**
paths, not absolute: on iOS the app container UUID changes across reinstalls, so
absolute paths silently rot and every photo becomes a broken image. Firebase
mode uploads to Storage and stores the download URL. Web falls back to a capped
base64 data URI.

### 6. Push notifications for followed-cart changes ⚠️ partially open

Fan-out on write: one owner action produces one public `CartUpdateModel` plus
one `NotificationModel` per follower inbox, so the Updates tab reads a single
stream with no client-side join — the same shape a Cloud Function would produce.

**In-app updates work, cross-device, in Firebase mode.** A system push to a
_closed_ app cannot be sent from a client: the legacy server key is retired and
the HTTP v1 API needs service-account credentials that must never ship in an
app. The client half is complete (token registration, foreground/background/
terminated handlers, deeplinks, document shapes); the Cloud Function is written
out in `SETUP_FIREBASE.md` but not deployed. **This is the one item that stays
partially open.**

### 7. Background 5 km proximity alerts ✅ with stated platform limits

`ProximityMonitor` + `AlertCooldownStore` implement the policy: a 6-hour
per-cart cooldown, an exit-reset once the user is seen beyond 7.5 km (kills
boundary flapping without a fixed hysteresis band), and a cap of five alerts per
hour. Three triggers — a new position, a cart-list change (a _cart_ moving
toward a stationary user, which the prototype had no path for at all), and a
10-minute heartbeat that finally gives `checkIntervalMinutes` a consumer.

Android background works via a foreground service, opt-in and off by default.
iOS is honest about its ceiling: alerts work while the app is open or recently
backgrounded, and a suspended iOS app runs no Dart. The settings screen states
the per-platform limit rather than implying a guarantee the OS will not honour.

### 8. Admin moderation ✅

A moderation queue fed by a **real customer-facing report flow** — the previous
queue was hardcoded because nothing could file a report. Admin dashboard with
counts derived from the repositories (the prototype displayed invented totals
like "128" and "12.4k"), a user directory with search, and block/unblock.

Blocking enforces at four layers: refused at sign-in, ejected mid-session via
the profile stream, cascaded so the owner's cart leaves the map, and guarded by
`canWrite` checks. Guards against blocking yourself or the last active admin.
Documented plainly: all four layers are client-side, and `firestore.rules` is
the actual enforcement.

---

## 5. Bugs fixed

| Bug                                                               | Consequence                                                                                                                      | Fix                                                                   |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `INTERNET` only in debug/profile manifests                        | **Release APKs had no network at all**                                                                                           | Declared in the main manifest; verified in a built APK                |
| `notificationMessage` clamped distance _upward_ (`d < 5 ? 5 : d`) | A cart 800 m away announced "within 5.0 km" — least accurate exactly when it mattered most                                       | Reports the real distance, in metres below 1 km                       |
| `checkForNearbyCarts` ignored the follow relationship             | Alerted on **every** cart in range; unusable anywhere dense                                                                      | `followedCartIds` is now a required parameter                         |
| Nothing subscribed to the position stream                         | Proximity alerts **could never fire** in the running app                                                                         | `AppShell` starts/stops tracking to match alert settings              |
| Throttle consumed by no-op startup runs                           | Walking into range was silently swallowed for up to 60 s                                                                         | Throttle is distance-aware: >100 m of movement always re-evaluates    |
| `FollowModel.proximityAlertKm` defaulted to 3                     | Contradicted the 5 km map circle, service and UI copy — in the constructor _and_ the `fromMap` fallback, the latter easy to miss | Both set to 5, with a test pinning it to `AppConstants.alertRadiusKm` |
| `isFollowed` mutable on a shared cart model                       | Two users would see each other's follows                                                                                         | Removed; follow state lives in its repository                         |
| `initialCenter` re-declared inside `build`                        | Map always opened on Dhaka regardless of real location                                                                           | `CartMap` takes it, defaulting to the shared constant                 |
| `fontFamily: 'Avenir'` not bundled                                | Avenir _is_ a system font on iOS, so the app silently rendered in a different typeface per platform                              | Dropped; weights set explicitly                                       |
| `FirebaseService` eager `static final`s                           | `[core/no-app]` crash the moment anything imported it                                                                            | File deleted                                                          |
| Test asserted `notificationMessage` said "within 5 km"            | Locked the bug in                                                                                                                | Rewritten to assert the real distance                                 |
| Test pinned `MapboxConfig.tileUrl` to the OSM branch              | Would break the suite the moment a real token was added                                                                          | Both branches asserted                                                |
| Smoke test called real geolocator                                 | Hit `MissingPluginException`, landed in a catch, still "passed"                                                                  | Fakes injected at the root                                            |
| Dead `MapPainter`, stale `mapboxStyleUrl`, duplicated map centre  | Dead weight                                                                                                                      | Removed                                                               |
| Docs said 3 km in five places                                     | Contradicted the code                                                                                                            | All updated to 5 km                                                   |

---

## 6. Testing

107 tests across 10 files (2,636 lines).

`FolloCartApp` takes its repositories, location service, notification gateway
and tile provider as constructor arguments. `main()` is the only place that
builds the real ones — **which is why no test touches geolocator,
shared_preferences, image_picker or flutter_local_notifications.**

- `test/support/fakes.dart` — hand-rolled fakes over plain lists and
  `StreamController`s; more readable than mock declarations at this size.
- `test/models/` — wire round-trips, `copyWith`, equality, enum fallbacks,
  schedule edge cases, formatters, palette stability, Mapbox both branches,
  placeholder detection.
- `test/repositories/` — store reactivity and corrupt-payload recovery, seeding
  idempotence, follow idempotence, clamped follower counts, auth paths, the
  block cascade, and a regression guard asserting **the raw password never
  appears in persisted JSON**.
- `test/services/` — haversine against known distances, follow filtering,
  per-cart thresholds, cooldown/exit-reset/hourly-cap policy, fan-out targeting.
- `test/widget_test.dart` — 16 end-to-end journeys through the real widget tree.
- `test/local_stack_boot_test.dart` — 7 tests booting against the **real local
  repositories**, i.e. the configuration that actually ships with no
  credentials. Includes a follow surviving a full cold restart.

**Skipped deliberately:** golden tests (font and platform variance, no payoff
yet) and `integration_test` (the manual script in `README.md` covers the
plugin-dependent paths).

---

## 7. Security

`firestore.rules` and `storage.rules` are new and are the real enforcement:

- `role` and `isBlocked` are not client-writable — no self-promotion to admin,
  no clearing your own block.
- A blocked user cannot write anything.
- Only a cart's owner can edit it or upload its photos; admins can hide any cart.
- Only admins can read the report queue.
- A user can only touch their own follows and notifications.

Local credential storage is **demo-grade and labelled as such** in three places
(a file header on `local_password.dart`, the register screen in local mode, and
the README). Passwords are salted SHA-256 digests, never raw — but
SharedPreferences is plaintext at rest and SHA-256 is not a password KDF, so a
leaked store is brute-forceable offline. `flutter_secure_storage` was
deliberately **not** added: it moves the problem without solving it and implies
a guarantee this mode does not have.

---

## 8. Verification performed

| Check                                 | Result                          |
| ------------------------------------- | ------------------------------- |
| `flutter analyze`                     | Clean, no issues                |
| `flutter test`                        | 107 passing                     |
| `flutter build web --release`         | Success                         |
| `flutter build apk --release`         | Success, 59 MB                  |
| `INTERNET` in merged release manifest | Confirmed in the built artifact |

---

## Deviations from the original spec

**Follow now requires sign-in.** The old `README.md` promised guests could
follow carts. A device-scoped follow cannot survive a reinstall and there is no
identity to deliver a push to, and anonymous reports would fill the moderation
queue with unattributable noise. Guests browse, search and open cart details
freely.

Reversing this is roughly 60 lines: a device-id `guest-<id>` identity plus a
follow-migration step on register.

---

## Known limitations

- Local mode is single-device by design. Firebase mode syncs.
- Push to a closed app needs the documented Cloud Function deployed.
- iOS background proximity needs either that server push or a
  `CLCircularRegion` platform channel (Apple caps monitoring at 20 regions, so
  it would track the 20 nearest followed carts).
- Android background sharing is OEM-dependent; some launchers kill the
  foreground service on swipe-away.
- One cart per owner.
- Cart claiming is debug-only; real ownership transfer needs server verification.
- `applicationId` is still `com.example.follo_cart` and must change before any
  store release.

## Suggested next phase

1. Deploy the Cloud Function for cross-device push.
2. iOS geofencing via a `CLCircularRegion` platform channel.
3. Server-side geo queries, so the nearby filter is not client-side.
4. Multi-cart owners.
5. Ratings and reviews.
6. Marker clustering for dense areas.
7. Admin via Firebase custom claims rather than a user-document field.
8. Move `applicationId` off `com.example.*`.

Role Email Password
Customer demo@demo.com demo1234
Cart owner owner@demo.com demo1234
Admin admin@demo.com demo1234
