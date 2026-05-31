import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flex_color_picker/flex_color_picker.dart';
import '../models/settings.dart';
import '../state/settings_state.dart';
import '../state/notes_state.dart';
import '../state/sync_state_notifier.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _endpointController = TextEditingController();
  final _tokenController = TextEditingController();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _workspaceController = TextEditingController();
  final _relayEndpointController = TextEditingController();
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsState>().settings;
    _endpointController.text = settings.serverEndpoint ?? '';
    _tokenController.text = settings.authToken ?? '';
    _accessKeyController.text = settings.s3AccessKey ?? '';
    _secretKeyController.text = settings.s3SecretKey ?? '';
    _workspaceController.text = settings.workspaceId;
    _relayEndpointController.text = settings.relayEndpoint ?? '';
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _tokenController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _workspaceController.dispose();
    _relayEndpointController.dispose();
    super.dispose();
  }

  Future<void> _pickThemeColor(SettingsState settingsState) async {
    final currentColor = settingsState.settings.customSeedColor != null
        ? Color(int.parse(
            settingsState.settings.customSeedColor!.replaceFirst('#', '0xFF')))
        : const Color(0xFF8B5A2B);

    final Color newColor = await showColorPickerDialog(
      context,
      currentColor,
      title: Text('App Theme Color',
          style: Theme.of(context).textTheme.titleLarge),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 20,
      wheelDiameter: 165,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      actionButtons: const ColorPickerActionButtons(
        okButton: true,
        closeButton: true,
        dialogActionButtons: false,
      ),
    );

    settingsState.setCustomSeedColor(
        '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer3<SettingsState, NotesState, SyncStateNotifier>(
        builder: (context, settingsState, notesState, syncState, child) {
          final settings = settingsState.settings;
          final theme = Theme.of(context);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // --- Appearance & Security ---
              _sectionHeader('Appearance & Security'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dynamic Color (Android)'),
                subtitle: const Text('Use system colors if available'),
                value: settings.useDynamicColor,
                onChanged: (v) => settingsState.setUseDynamicColor(v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App Theme Color'),
                subtitle: const Text('Tap to pick a custom accent color'),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: settings.customSeedColor != null
                        ? Color(int.parse(settings.customSeedColor!
                            .replaceFirst('#', '0xFF')))
                        : const Color(0xFF8B5A2B),
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: () => _pickThemeColor(settingsState),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App Font'),
                subtitle: Text(settings.fontFamily ?? 'System Default'),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Select Font'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                              title: const Text('System Default'),
                              onTap: () {
                                settingsState.setFontFamily(null);
                                Navigator.pop(context);
                              }),
                          ListTile(
                              title: const Text('Inter'),
                              onTap: () {
                                settingsState.setFontFamily('Inter');
                                Navigator.pop(context);
                              }),
                          ListTile(
                              title: const Text('Roboto'),
                              onTap: () {
                                settingsState.setFontFamily('Roboto');
                                Navigator.pop(context);
                              }),
                          ListTile(
                              title: const Text('Lora'),
                              onTap: () {
                                settingsState.setFontFamily('Lora');
                                Navigator.pop(context);
                              }),
                          ListTile(
                              title: const Text('Fira Code'),
                              onTap: () {
                                settingsState.setFontFamily('Fira Code');
                                Navigator.pop(context);
                              }),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require Biometrics'),
                subtitle: const Text('Lock app with OS biometrics/PIN'),
                value: settings.biometricLockEnabled,
                onChanged: (v) => settingsState.setBiometricLockEnabled(v),
              ),
              const Divider(height: 32),

              // --- Sync Connection ---
              _sectionHeader('Sync Connection'),
              _buildTextField(
                controller: _endpointController,
                label: 'Server endpoint URL',
                hint: 'https://stonepad.example.com',
                onChanged: (v) {
                  settingsState.setServerEndpoint(v);
                  if (settings.endpointVerified) {
                    settingsState.setEndpointVerified(false);
                  }
                },
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: settings.endpointVerified
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          settings.endpointVerified
                              ? Icons.check_circle
                              : Icons.wifi_find,
                          size: 18,
                        ),
                  label: Text(
                    settings.endpointVerified
                        ? 'Connection verified'
                        : 'Test Connection',
                  ),
                  onPressed: settings.hasEndpoint && !_testing
                      ? () => _testConnection(settingsState)
                      : null,
                ),
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Authentication mode'),
                subtitle: Text(settings.authMode == 'token'
                    ? 'Shared Token'
                    : settings.authMode == 's3'
                        ? 'S3 Access Keys'
                        : settings.authMode == 'users'
                            ? 'Username / Password'
                            : 'None'),
                trailing: DropdownButton<String>(
                  value: settings.authMode,
                  items: const [
                    DropdownMenuItem(value: 'n' 'one', child: Text('None')),
                    DropdownMenuItem(value: 'token', child: Text('Token')),
                    DropdownMenuItem(value: 's3', child: Text('S3 Keys')),
                    DropdownMenuItem(value: 'users', child: Text('Login')),
                  ],
                  onChanged: (v) {
                    if (v != null) settingsState.setAuthMode(v);
                  },
                ),
              ),

              if (settings.authMode == 'token')
                _buildTextField(
                  controller: _tokenController,
                  label: 'Shared auth token',
                  obscureText: true,
                  onChanged: (v) => settingsState.setAuthToken(v),
                ),

              if (settings.authMode == 'users')
                _buildUsersModeSection(settingsState, settings),

              if (settings.authMode == 's3') ...[
                _buildTextField(
                  controller: _accessKeyController,
                  label: 'Access Key ID',
                  onChanged: (v) =>
                      settingsState.setS3Keys(v, _secretKeyController.text),
                ),
                _buildTextField(
                  controller: _secretKeyController,
                  label: 'Secret Access Key',
                  obscureText: true,
                  onChanged: (v) =>
                      settingsState.setS3Keys(_accessKeyController.text, v),
                ),
              ],

              _buildTextField(
                controller: _workspaceController,
                label: 'Workspace ID',
                onChanged: (v) => settingsState.setWorkspaceId(v),
              ),

              const Divider(height: 32),

              // --- Sync Status ---
              _sectionHeader('Sync Status'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    settings.syncEnabled ? 'Online (Sync Active)' : 'Offline'),
                subtitle: const Text('Spotify-style offline mode'),
                value: settings.syncEnabled,
                onChanged: (v) {
                  settingsState.setSyncEnabled(v);
                  context.read<SyncService>().onSyncToggle(v);
                  syncState.setSyncEnabled(v);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
                onPressed: (settings.hasEndpoint && settings.endpointVerified)
                    ? () {
                        context.read<SyncService>().manualSync();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Manual sync triggered')),
                        );
                      }
                    : null,
              ),

              const Divider(height: 32),

              // --- Diagnostics ---
              _sectionHeader('Diagnostics'),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sync state'),
                  trailing: Text(syncState.state.name)),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notes count'),
                  trailing: Text('${notesState.allPaths.length}')),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pending changes'),
                  trailing:
                      Text('${notesState.manifest.modifiedPaths.length}')),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Conflicts'),
                  trailing:
                      Text('${notesState.manifest.conflictPaths.length}')),
              if (syncState.lastSuccess != null)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Last sync'),
                    subtitle:
                        Text(syncState.lastSuccess!.toLocal().toString())),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsersModeSection(
      SettingsState settingsState, StonepadSettings settings) {
    if (settings.sessionToken != null && settings.sessionToken!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(child: Text('Signed in')),
              TextButton(
                onPressed: () async {
                  await settingsState.setSessionToken(null);
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.login),
        label: const Text('Sign In to Server'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Future<void> _testConnection(SettingsState settingsState) async {
    setState(() => _testing = true);
    try {
      final endpoint = settingsState.settings.serverEndpoint!;
      final url = Uri.parse('$endpoint/api/v1/health');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        await settingsState.setEndpointVerified(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✓ Connection successful'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Server returned ${response.statusCode}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Connection failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
