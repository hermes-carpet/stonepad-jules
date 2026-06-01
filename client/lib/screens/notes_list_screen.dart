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
  final TextEditingController _searchController = TextEditingController();
  bool _isScrolled = false;
  String _searchQuery = '';
  bool _isMasonry = true; // Toggle between list and masonry (gallery) view
  final Map<String, String?> _colorCache = {};

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
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesState>().loadManifest();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search notes...',
                            prefixIcon: const Icon(Icons.search),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Filters / View Toggle
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FilledButton.tonal(
                            onPressed: () {},
                            child: const Text('All Notes'),
                          ),
                          IconButton(
                            icon: Icon(_isMasonry ? Icons.list : Icons.grid_view),
                            onPressed: () {
                              setState(() {
                                _isMasonry = !_isMasonry;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (folders.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          folders.map((f) => _buildFolderItem(f, colorScheme)).toList(),
                        ),
                      ),
                    ),
                  if (folders.isEmpty && notes.where((p) => !p.endsWith('/.folder')).isEmpty)
                    SliverFillRemaining(child: _buildEmptyState(theme))
                  else ...[
                    // Pinned Section (Placeholder logic for demonstration)
                    if (_searchQuery.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Text(
                            'PINNED',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    if (_searchQuery.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: _buildNotesGridOrList(
                            notes.where((p) => !p.endsWith('/.folder')).take(2).toList(),
                            notesState, theme, colorScheme),
                      ),

                    // All Notes Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Text(
                          'ALL NOTES',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: _buildNotesGridOrList(
                          notes.where((p) => !p.endsWith('/.folder') && p.toLowerCase().contains(_searchQuery)).toList(),
                          notesState, theme, colorScheme),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)), // FAB padding
                  ],
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

  Widget _buildNotesGridOrList(
      List<String> notesPaths, NotesState notesState, ThemeData theme, ColorScheme colorScheme) {
    if (_isMasonry) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final n = notesPaths[index];
            final status = notesState.manifest.notes[n]?['status']?.toString();
            return _buildNoteCard(n, status ?? 'synced', notesState, theme, isGrid: true);
          },
          childCount: notesPaths.length,
        ),
      );
    } else {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final n = notesPaths[index];
            final status = notesState.manifest.notes[n]?['status']?.toString();
            return _buildNoteCard(n, status ?? 'synced', notesState, theme, isGrid: false);
          },
          childCount: notesPaths.length,
        ),
      );
    }
  }

  Widget _buildNoteCard(
      String notePath, String status, NotesState notesState, ThemeData theme, {bool isGrid = false}) {
    final colorScheme = theme.colorScheme;
    final filename = notePath.split('/').last.replaceAll('.md', '');

    Widget buildCard(Color bgColor) {
      return Card(
        margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        filename,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: isGrid ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status == 'modified')
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.cloud_upload,
                            size: 16, color: colorScheme.primary),
                      ),
                    if (status == 'conflict_pending')
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.warning,
                            size: 16, color: colorScheme.error),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: isGrid ? 1 : 0,
                  child: Text(
                    'Tap to view and edit note content...',
                    style:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: isGrid ? null : 2,
                    overflow: isGrid ? TextOverflow.fade : TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Just now', // Placeholder
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_colorCache.containsKey(notePath)) {
      Color bgColor = colorScheme.surfaceContainerLow;
      final cachedColor = _colorCache[notePath];
      if (cachedColor != null) {
        try {
          bgColor = Color(int.parse(cachedColor.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
      return buildCard(bgColor);
    }

    return FutureBuilder<String?>(
        future: NoteHelper.getNoteColor(notePath, StorageService()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) {
                 setState(() {
                   _colorCache[notePath] = snapshot.data;
                 });
               }
             });
          }

          Color bgColor = colorScheme.surfaceContainerLow;
          if (snapshot.hasData && snapshot.data != null) {
            try {
              bgColor =
                  Color(int.parse(snapshot.data!.replaceFirst('#', '0xFF')));
            } catch (_) {}
          }

          return buildCard(bgColor);
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
