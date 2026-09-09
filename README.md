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
- Customers can follow carts and review schedule, opening, and nearby updates.
- Profile includes customer, cart owner, and admin role previews for the next role-specific flows.
- `FoodCart` is the local model boundary for later API, GPS, photo, and notification integrations.
