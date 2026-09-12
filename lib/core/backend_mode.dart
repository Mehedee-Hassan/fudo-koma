/// Which persistence layer the running app is wired to.
enum BackendMode {
  /// On-device storage. Works with zero credentials; single device only.
  local,

  /// Firebase Auth + Firestore + Storage + Messaging.
  firebase;

  bool get isLocal => this == BackendMode.local;
  bool get isFirebase => this == BackendMode.firebase;

  String get label => switch (this) {
        BackendMode.local => 'Local demo data',
        BackendMode.firebase => 'Firebase connected',
      };
}
