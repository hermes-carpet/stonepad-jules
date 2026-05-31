import "../models/note_helper.dart";
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/notes_state.dart';
import "../models/sync_state.dart";
import '../state/sync_state_notifier.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  String _currentFolder = '';
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 0 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 0 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesState>().loadManifest();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<NotesState, SyncStateNotifier, SyncService>(
      builder: (context, notesState, syncState, syncService, child) {
        final allPaths = notesState.manifest.notes.keys.toList()..sort();
        final folders = StorageService.subFolders(allPaths, _currentFolder);
        final notes = StorageService.notesInFolder(allPaths, _currentFolder);

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return PopScope(
            canPop: _currentFolder.isEmpty,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                _navigateUp();
              }
            },
            child: Scaffold(
              body: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    expandedHeight: 120,
                    pinned: true,
                    scrolledUnderElevation: 0,
                    backgroundColor: colorScheme.surface,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 32, bottom: 16),
                      title: Text(
                        _buildBreadcrumb(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    actions: [
                      _buildSyncStatus(
                          syncState.state, syncService, colorScheme),
                      IconButton(
                        icon: Icon(Icons.settings_outlined,
                            color: colorScheme.onSurface),
                        onPressed: () =>
                            Navigator.pushNamed(context, '/settings'),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                  if (_currentFolder.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: InkWell(
                          onTap: _navigateUp,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_back,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 16),
                                Text('Back to previous folder',
                                    style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        ...folders.map((f) => _buildFolderItem(f, colorScheme)),
                        ...notes
                            .where((p) => !p.endsWith('/.folder'))
                            .map((notePath) {
                          final entry = notesState.manifest.notes[notePath];
                          if (entry == null) return const SizedBox.shrink();
                          return _buildNoteCard(
                              notePath, entry.status.name, notesState, theme);
                        }),
                        if (folders.isEmpty &&
                            notes.where((p) => !p.endsWith('/.folder')).isEmpty)
                          _buildEmptyState(theme),
                      ]),
                    ),
                  ),
                  const SliverPadding(
                      padding: EdgeInsets.only(bottom: 100)), // Space for FAB
                ],
              ),
              floatingActionButton: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'new_folder',
                    onPressed: _createFolder,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurfaceVariant,
                    elevation: 0,
                    child: const Icon(Icons.create_new_folder_outlined),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton.extended(
                    heroTag: 'new_note',
                    onPressed: _createNote,
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 4,
                    icon: const Icon(Icons.edit),
                    label: const Text('New note',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ));
      },
    );
  }

  Widget _buildSyncStatus(
      SyncState state, SyncService syncService, ColorScheme colorScheme) {
    IconData icon;
    Color color;

    switch (state) {
      case SyncState.active:
        icon = Icons.cloud_done;
        color = colorScheme.primary;
        break;
      case SyncState.manualOnly:
        icon = Icons.cloud_off;
        color = colorScheme.onSurfaceVariant;
        break;
      case SyncState.noNetwork:
        icon = Icons.cloud_off;
        color = colorScheme.error;
        break;
      case SyncState.disabled:
        icon = Icons.cloud_off;
        color = colorScheme.onSurfaceVariant;
        break;
    }

    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: 'Sync Status',
      onPressed: () {
        if (state != SyncState.disabled) syncService.manualSync();
      },
    );
  }

  Widget _buildFolderItem(String folderPath, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(Icons.folder, color: colorScheme.primary),
        title: Text(
          folderPath.split('/').last,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () => setState(() => _currentFolder = folderPath),
        onLongPress: () {
          _showFolderActions(folderPath);
        },
      ),
    );
  }

  Widget _buildNoteCard(
      String notePath, String status, NotesState notesState, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final filename = notePath.split('/').last.replaceAll('.md', '');

    return FutureBuilder<String?>(
        future: NoteHelper.getNoteColor(notePath, StorageService()),
        builder: (context, snapshot) {
          Color bgColor = colorScheme.surfaceContainerLow;
          if (snapshot.hasData && snapshot.data != null) {
            try {
              bgColor =
                  Color(int.parse(snapshot.data!.replaceFirst('#', '0xFF')));
            } catch (_) {}
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: bgColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _openNote(notesState, notePath),
              onLongPress: () {
                _showNoteActions(notesState, notePath);
              },
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            filename,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (status == 'modified')
                          Icon(Icons.cloud_upload,
                              size: 16, color: colorScheme.primary),
                        if (status == 'conflict_pending')
                          Icon(Icons.warning,
                              size: 16, color: colorScheme.error),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to view and edit note content...',
                      style:
                          TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_document,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notes yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to create your first note.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _buildBreadcrumb() {
    if (_currentFolder.isEmpty) return 'Library';
    final parts = _currentFolder.split('/');
    return parts.last;
  }

  void _navigateUp() {
    final parts = _currentFolder.split('/');
    if (parts.length <= 1) {
      setState(() => _currentFolder = '');
    } else {
      setState(
          () => _currentFolder = parts.sublist(0, parts.length - 1).join('/'));
    }
  }

  void _openNote(NotesState notesState, String path) {
    notesState.openNote(path).then((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: notesState,
            child: NoteEditorScreen(notePath: path),
          ),
        ),
      );
    });
  }

  Future<void> _createNote() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Note'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Note name (e.g. shopping-list)',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      final folderPrefix = _currentFolder.isEmpty ? '' : '$_currentFolder/';
      final path = '$folderPrefix$result.md';
      final notesState = context.read<NotesState>();
      await notesState.createNote(path);
      if (mounted) {
        _openNote(notesState, path);
      }
    }
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      final folderPrefix = _currentFolder.isEmpty ? '' : '$_currentFolder/';
      final folderPath = '$folderPrefix$result';
      final notesState = context.read<NotesState>();
      await notesState.createNote('$folderPath/.folder', content: '');
      setState(() {});
    }
  }

  Future<void> _showFolderActions(String folderPath) async {
    final notesState = context.read<NotesState>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () => Navigator.pop(ctx), // Placeholder
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pop(ctx, true),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Folder'),
          content: Text(
              'Delete "${folderPath.split('/').last}" and all notes inside?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (shouldDelete == true) {
        await notesState.deleteFolder(folderPath);
        if (_currentFolder.startsWith(folderPath)) {
          _navigateUp();
        }
        if (mounted) setState(() {});
      }
    }
  }

  void _showNoteActions(NotesState notesState, String path) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(ctx);
              _openNote(notesState, path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              notesState.deleteNote(path);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
