# Connecting Firebase

The app runs without any of this. With placeholder values in
`lib/firebase_options.dart`, `AppBootstrap` detects them and starts in **local
mode** — on-device storage, seeded data, working accounts and alerts. Follow
these steps only when you want cross-device sync and real push.

You can verify which mode is active from the badge on the Welcome and Profile
screens ("Local demo data" vs "Firebase connected").

---

## 1. Create the project

1. Create a project in the [Firebase console](https://console.firebase.google.com).
2. Enable **Authentication → Email/Password**.
3. Create a **Cloud Firestore** database.
4. Enable **Cloud Storage**.
5. Enable **Cloud Messaging**.

## 2. Change the application id first

The project still ships Flutter's template id:

```
android/app/build.gradle.kts   namespace / applicationId = "com.example.follo_cart"
ios/Runner.xcodeproj           PRODUCT_BUNDLE_IDENTIFIER
```

`com.example.*` cannot be published to Google Play, and changing it after
registering apps in Firebase means re-registering them. Change it now.

## 3. Generate the config

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This overwrites `lib/firebase_options.dart` with real values and writes
`android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist`.

Both credential files are already in `.gitignore` — keep them there.

## 4. Add the Gradle plugin

This step is deliberately **not** committed: the `google-services` plugin fails
the build when `google-services.json` is absent, which would break the
"runs with zero credentials" promise for everyone else.

In `android/settings.gradle.kts`, inside the `plugins { }` block:

```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

In `android/app/build.gradle.kts`, add to its `plugins { }` block:

```kotlin
id("com.google.gms.google-services")
```

Core-library desugaring and the location/notification permissions are already
configured.

## 5. Deploy the security rules

`firestore.rules` and `storage.rules` ship with this repo. **Deploy them before
letting anyone in** — without rules, the client-side checks are all that stand
between a patched client and your data.

```bash
firebase deploy --only firestore:rules,storage:rules
```

They enforce:
- `role` and `isBlocked` are never client-writable (no self-promotion to admin,
  no clearing your own block).
- A blocked user cannot write anything.
- Only a cart's owner can edit it or upload its photos; admins can hide any cart.
- Only admins can read the report queue.
- A user can only read and write their own notifications and follows.

## 6. Verify the switch

```bash
flutter run                                     # should show "Firebase connected"
flutter run --dart-define=FOLLO_BACKEND=local   # force local mode back
```

---

## Collection layout

| Path | Model | Notes |
|---|---|---|
| `users/{uid}` | `UserProfileModel` | role, isBlocked, fcmToken |
| `carts/{cartId}` | `FoodCartModel` | `scheduleEntries` embedded as an array — bounded (≤ 21) and always read with the cart, so one read instead of two |
| `carts/{cartId}/updates/{id}` | `CartUpdateModel` | public activity log |
| `follows/{userId}_{cartId}` | `FollowModel` | deterministic composite id, so follow/unfollow are idempotent set/delete with no query |
| `users/{uid}/notifications/{id}` | `NotificationModel` | a subcollection, not a root collection with a `userId` field: no composite index, and the rule is one line |
| `reports/{reportId}` | `ReportModel` | admin-read-only |

Dates are ISO-8601 strings rather than Firestore `Timestamp`s, and coordinates
are two doubles rather than a `GeoPoint`. That is deliberate: one wire format
serves both backends. ISO-8601 sorts correctly lexicographically, so
`orderBy('updatedAt')` still works. The trade-off is no
`FieldValue.serverTimestamp()` and no server-side geo queries — the 5 km filter
is client-side today.

### Indexes

The queries in use are single-field and covered by automatic indexes. If
Firestore asks for a composite index, the console error contains a direct
creation link.

---

## The remaining gap: push to a closed app

**A client cannot send FCM.** The legacy server-key API is retired, and the
HTTP v1 API requires OAuth service-account credentials that must never ship
inside an app.

What is implemented on the client:
- FCM token registration, persisted to `users/{uid}.fcmToken`.
- Foreground, background, and terminated message handlers.
- Tap-to-route deeplinks (`cart/{cartId}`).
- The exact document shapes the function below reads.

What works without the function: **in-app** updates are live cross-device in
Firebase mode, because `users/{uid}/notifications` is a Firestore stream. What
does not work: a system notification to a follower whose app is closed.

### The Cloud Function to deploy

```js
// functions/index.js
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();

exports.notifyFollowersOnCartChange = onDocumentUpdated(
  'carts/{cartId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.isOpen === after.isOpen) return;          // only status flips

    const cartId = event.params.cartId;
    const message = after.isOpen
      ? `${after.name} is open now at ${after.locationLabel}.`
      : `${after.name} has closed for now.`;

    const follows = await admin.firestore()
      .collection('follows')
      .where('cartId', '==', cartId)
      .where('notificationsEnabled', '==', true)
      .get();

    const userIds = follows.docs.map((d) => d.data().userId);
    if (!userIds.length) return;

    const users = await admin.firestore().getAll(
      ...userIds.map((id) => admin.firestore().doc(`users/${id}`))
    );

    const tokens = users
      .filter((u) => u.exists && u.data().fcmToken && !u.data().isBlocked)
      .map((u) => u.data().fcmToken);

    if (tokens.length) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title: after.name, body: message },
        data: { deeplink: `cart/${cartId}` },
      });
    }

    // Mirror into each inbox so the in-app feed matches the push.
    const batch = admin.firestore().batch();
    for (const userId of userIds) {
      batch.set(
        admin.firestore().collection(`users/${userId}/notifications`).doc(),
        {
          userId,
          cartId,
          cartName: after.name,
          type: after.isOpen ? 'opened' : 'closed',
          message,
          createdAt: new Date().toISOString(),
          isRead: false,
        }
      );
    }
    await batch.commit();
  }
);
```

The same pattern covers proximity: a function would need each user's
last-known location to push when a followed cart enters their radius. That is
the correct long-term answer for **iOS background alerts**, since a suspended
iOS app runs no Dart at all.

---

## Production notes

- **Admin via a user-document field is a compromise.** The rules stop a client
  from writing `role`, but the real answer is a Firebase **custom claim** set
  from the console or a function. Do that before launch.
- Never commit `google-services.json` or `GoogleService-Info.plist`.
- Add your release SHA-1 and SHA-256 to the Android app in the console.
- Background location requires a Play Store declaration and a demo video.
