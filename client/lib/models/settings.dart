/// User-configurable settings, persisted to settings.json.
class StonepadSettings {
  String? serverEndpoint;
  String authMode; // ***, "token", "users", "s3"
  String? authToken; // Shared token for "token" mode
  String? sessionToken; // Session token for "users" mode (from login)
  String? s3AccessKey;
  String? s3SecretKey;
  String workspaceId;
  bool syncEnabled;
  bool endpointVerified; // set true after successful Test Connection
  // Relay (optional)
  bool relayEnabled;
  String? relayEndpoint;
  String? relayAccessKey;
  String? relaySecretKey;

  bool onboardingCompleted;
  bool useDynamicColor;
  String? customSeedColor; // Hex string, e.g. "#FF9800"
  String? fontFamily; // null means default system font
  bool biometricLockEnabled;

  StonepadSettings({
    this.serverEndpoint,
    this.authMode = 'n' 'one',
    this.authToken,
    this.sessionToken,
    this.s3AccessKey,
    this.s3SecretKey,
    this.workspaceId = 'default',
    this.syncEnabled = false,
    this.endpointVerified = false,
    this.relayEnabled = false,
    this.relayEndpoint,
    this.relayAccessKey,
    this.relaySecretKey,
    this.onboardingCompleted = false,
    this.useDynamicColor = true,
    this.customSeedColor,
    this.fontFamily,
    this.biometricLockEnabled = false,
  });

  factory StonepadSettings.fromJson(Map<String, dynamic> json) {
    return StonepadSettings(
      serverEndpoint: json['server_endpoint'],
      authMode: json['auth_mode'] ?? 'n' 'one',
      authToken: json['auth_token'],
      sessionToken: json['session_token'],
      s3AccessKey: json['s3_access_key'],
      s3SecretKey: json['s3_secret_key'],
      workspaceId: json['workspace_id'] ?? 'default',
      syncEnabled: json['sync_enabled'] ?? false,
      endpointVerified: json['endpoint_verified'] ?? false,
      relayEnabled: json['relay_enabled'] ?? false,
      relayEndpoint: json['relay_endpoint'],
      relayAccessKey: json['relay_access_key'],
      relaySecretKey: json['relay_secret_key'],
      onboardingCompleted: json['onboarding_completed'] ?? false,
      useDynamicColor: json['use_dynamic_color'] ?? true,
      customSeedColor: json['custom_seed_color'],
      fontFamily: json['font_family'],
      biometricLockEnabled: json['biometric_lock_enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'server_endpoint': serverEndpoint,
      'auth_mode': authMode,
      'auth_token': authToken,
      'session_token': sessionToken,
      's3_access_key': s3AccessKey,
      's3_secret_key': s3SecretKey,
      'workspace_id': workspaceId,
      'sync_enabled': syncEnabled,
      'endpoint_verified': endpointVerified,
      'relay_enabled': relayEnabled,
      'relay_endpoint': relayEndpoint,
      'relay_access_key': relayAccessKey,
      'relay_secret_key': relaySecretKey,
      'onboarding_completed': onboardingCompleted,
      'use_dynamic_color': useDynamicColor,
      'custom_seed_color': customSeedColor,
      'font_family': fontFamily,
      'biometric_lock_enabled': biometricLockEnabled,
    };
  }

  /// Whether any sync endpoint is configured.
  bool get hasEndpoint => serverEndpoint != null && serverEndpoint!.isNotEmpty;

  /// Whether the user has configured the app at all (onboarding check).
  bool get isConfigured => onboardingCompleted;
}
