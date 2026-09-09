# Follo Cart App

## What currently works

This is a functional Flutter prototype for a food cart follow app.

- Runs as a Flutter web demo.
- Builds as an Android debug APK.
- Opens on a map-first Explore screen.
- Shows nearby food carts with names, categories, distance, and open/closed status.
- Allows users to select a food cart marker.
- Allows users to follow and unfollow food carts.
- Shows followed carts in the Following tab.
- Shows schedule, location, and open/closed updates in the Updates tab.
- Includes Customer, Cart Owner, and Admin role previews.
- Includes Android and iOS Flutter platform scaffolding.
- Includes a widget smoke test and passes Flutter analysis.

## Current limitations

This is currently a front-end prototype, not a production-ready app.

- The map is a custom visual demo, not a real GPS map.
- Cart locations use sample data and do not update live.
- Follow state is temporary and is lost when the app closes.
- There is no login, registration, or real user account system.
- Customer, cart owner, and admin roles are UI previews only.
- Cart owners cannot yet upload photos.
- Cart owners cannot publish real schedules or live locations.
- There is no backend database.
- There are no push notifications.
- There are no real 3 km geofence alerts.
- Admin users cannot actually block or manage users yet.
- The app does not request location permissions.
- Background location tracking is not implemented.
- iOS files are generated, but iOS build testing requires macOS and Xcode.

## Next development phase

The next phase should add:

1. Authentication and role-based access.
2. A backend database for users, carts, schedules, follows, and updates.
3. Google Maps, Mapbox, or Apple MapKit integration.
4. Real GPS location updates for cart owners.
5. Photo upload and cloud storage.
6. Push notifications for followed cart changes.
7. Background 3 km proximity alerts.
8. Admin tools for moderation and blocking users.
