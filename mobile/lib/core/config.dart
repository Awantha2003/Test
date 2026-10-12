/// Build-time configuration, passed with --dart-define (see mobile/README.md).
/// Nothing here is secret: Firebase client config is public by design and
/// protected by App Check + security rules.
class AppConfig {
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'rakawala-dev');
  static const functionsRegion = String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'asia-south1');

  /// Production must use a commercial tile provider (OSM tile policy forbids heavy use).
  static const mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const mapAttribution = String.fromEnvironment('MAP_ATTRIBUTION', defaultValue: '© OpenStreetMap contributors');

  /// OSRM-compatible routing server for the road route on Live track. The public demo
  /// server is fine for testing only; production should self-host OSRM or use a provider.
  /// Empty = show a straight line instead of a road route.
  static const routingUrl = String.fromEnvironment('ROUTING_URL', defaultValue: 'https://router.project-osrm.org');

  static const useEmulators = bool.fromEnvironment('USE_EMULATORS');
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

  static const supportPhone = String.fromEnvironment('SUPPORT_PHONE', defaultValue: '+94110000000');
  static const webUrl = String.fromEnvironment('WEB_URL', defaultValue: 'https://rakawala.lk');

  /// Sri Lanka Police emergency and the National Child Protection Authority hotline.
  static const policeEmergency = '119';
  static const childHelpline = '1929';
}
