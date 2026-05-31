library;

import "package:dynamic_color/dynamic_color.dart";
import "package:google_fonts/google_fonts.dart";
import "services/auth_service.dart";

/// Stonepad — Self-hostable markdown notes application.
/// Mobile-first Flutter client with optional sync.
/// See §8 of the Stonepad v1 Implementation Plan.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'constants/strings.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/lifecycle_service.dart';
import 'services/vault_manager.dart';
import 'state/notes_state.dart';
import 'state/sync_state_notifier.dart';
import 'state/settings_state.dart';
import 'state/connectivity_state.dart';
import 'screens/notes_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/vault_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Linux/macOS/Windows desktop: lock to portrait phone size for dev testing.
  // See §8.13 — this exists exclusively for the AI-driven dev feedback loop.
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(412, 915),
        minimumSize: Size(412, 915),
        maximumSize: Size(412, 915),
        center: true,
        title: StonepadStrings.desktopTitle,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      // window_manager may fail in headless/XWayland environments.
      // Continue without window sizing — the app still runs.
      debugPrint('Window manager unavailable (running headless): $e');
    }
  }

  // Resolve vault path. On Android this may return null (need folder picker).
  final vaultPath = await VaultManager.getOrCreateVaultPath();

  // Initialize services — skip storage ops if vault isn't configured yet.
  final storageService = StorageService();
  final settingsState = SettingsState();
  if (vaultPath != null) {
    await settingsState.load();
  }

  runApp(StonepadApp(
    storageService: storageService,
    settingsState: settingsState,
    vaultConfigured: vaultPath != null,
  ));
}

class StonepadApp extends StatefulWidget {
  final StorageService storageService;
  final SettingsState settingsState;
  final bool vaultConfigured;

  const StonepadApp({
    super.key,
    required this.storageService,
    required this.settingsState,
    required this.vaultConfigured,
  });

  @override
  State<StonepadApp> createState() => _StonepadAppState();
}

class _StonepadAppState extends State<StonepadApp> {
  late final NotesState _notesState;
  late final SyncStateNotifier _syncState;
  late final ConnectivityState _connectivityState;
  late final SyncService _syncService;
  late final LifecycleService _lifecycle;
  late bool _vaultConfigured;

  @override
  void initState() {
    super.initState();
    _vaultConfigured = widget.vaultConfigured;
    _notesState = NotesState(widget.storageService);
    _syncState = SyncStateNotifier();
    _connectivityState = ConnectivityState();

    // Initialize sync state from settings
    if (widget.settingsState.settings.syncEnabled) {
      _syncState.setSyncEnabled(true);
    } else {
      _syncState.setSyncEnabled(false);
    }

    _syncService = SyncService(
      notesState: _notesState,
      syncState: _syncState,
      connectivity: _connectivityState,
      settingsState: widget.settingsState,
      storage: widget.storageService,
    );

    // Start polling if sync is enabled and endpoint is configured
    if (widget.settingsState.settings.hasEndpoint &&
        widget.settingsState.settings.syncEnabled) {
      _syncService.startPolling();
    }

    // Wire connectivity changes to SyncService
    _connectivityState.addListener(() {
      _syncService.onConnectivityChanged(_connectivityState.isConnected);
    });

    _lifecycle = LifecycleService(
      notesState: _notesState,
      syncState: _syncState,
    );
    _lifecycle.register();
  }

  @override
  void dispose() {
    _syncService.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  bool _isAuthenticated = false;
  bool _isAuthenticating = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!widget.settingsState.settings.biometricLockEnabled) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isAuthenticating = false;
        });
      }
      return;
    }

    final success = await AuthService.authenticate();
    if (mounted) {
      setState(() {
        _isAuthenticated = success;
        _isAuthenticating = false;
      });
    }
  }

  ThemeData _buildTheme(ColorScheme colorScheme, String? fontFamily) {
    final textTheme = fontFamily != null
        ? GoogleFonts.getTextTheme(
            fontFamily, ThemeData(colorScheme: colorScheme).textTheme)
        : null;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _notesState),
        ChangeNotifierProvider.value(value: _syncState),
        ChangeNotifierProvider.value(value: widget.settingsState),
        ChangeNotifierProvider.value(value: _connectivityState),
        Provider.value(value: _syncService),
      ],
      child: Consumer<SettingsState>(
        builder: (context, settingsState, child) {
          final settings = settingsState.settings;
          final customColor = settings.customSeedColor != null
              ? Color(int.parse(
                  settings.customSeedColor!.replaceFirst('#', '0xFF')))
              : const Color(0xFF8B5A2B); // Default Amber/Earthy tone

          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              ColorScheme lightScheme;
              ColorScheme darkScheme;

              if (settings.useDynamicColor &&
                  lightDynamic != null &&
                  darkDynamic != null) {
                lightScheme = lightDynamic;
                darkScheme = darkDynamic;
              } else {
                lightScheme = ColorScheme.fromSeed(
                    seedColor: customColor, brightness: Brightness.light);
                darkScheme = ColorScheme.fromSeed(
                    seedColor: customColor, brightness: Brightness.dark);
              }

              return MaterialApp(
                title: StonepadStrings.appName,
                debugShowCheckedModeBanner: false,
                theme: _buildTheme(lightScheme, settings.fontFamily),
                darkTheme: _buildTheme(darkScheme, settings.fontFamily),
                home: _buildHome(),
                routes: {
                  '/notes': (_) => const NotesListScreen(),
                  '/settings': (_) => const SettingsScreen(),
                  '/login': (_) => const LoginScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHome() {
    if (_isAuthenticating) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              const Text('App Locked',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _checkAuth,
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      );
    }
    // Android: if vault not configured, show folder picker first.
    if (!_vaultConfigured) {
      return VaultSetupScreen(
        onVaultReady: () {
          setState(() => _vaultConfigured = true);
          // Reload manifest and settings from new vault path.
          _notesState.loadManifest();
          widget.settingsState.load();
        },
      );
    }
    // If the user hasn't configured anything, show onboarding.
    if (!widget.settingsState.settings.isConfigured) {
      return const OnboardingScreen();
    }
    return const NotesListScreen();
  }
}
