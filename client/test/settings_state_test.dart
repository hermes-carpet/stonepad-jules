import 'package:flutter_test/flutter_test.dart';
import 'package:stonepad/state/settings_state.dart';
import 'package:stonepad/models/settings.dart';

void main() {
  group('SettingsState tests', () {
    test('Initializes with default values', () {
      final state = SettingsState();
      expect(state.settings.onboardingCompleted, isFalse);
      expect(state.settings.useDynamicColor, isTrue);
      expect(state.settings.customSeedColor, isNull);
      expect(state.settings.fontFamily, isNull);
      expect(state.settings.biometricLockEnabled, isFalse);
    });

    test('toJson/fromJson handles new fields', () {
      final settings = StonepadSettings(
        onboardingCompleted: true,
        useDynamicColor: false,
        customSeedColor: '#FF0000',
        fontFamily: 'Inter',
        biometricLockEnabled: true,
      );

      final json = settings.toJson();
      expect(json['onboarding_completed'], isTrue);
      expect(json['use_dynamic_color'], isFalse);
      expect(json['custom_seed_color'], '#FF0000');
      expect(json['font_family'], 'Inter');
      expect(json['biometric_lock_enabled'], isTrue);

      final decoded = StonepadSettings.fromJson(json);
      expect(decoded.onboardingCompleted, isTrue);
      expect(decoded.useDynamicColor, isFalse);
      expect(decoded.customSeedColor, '#FF0000');
      expect(decoded.fontFamily, 'Inter');
      expect(decoded.biometricLockEnabled, isTrue);
    });
  });
}
