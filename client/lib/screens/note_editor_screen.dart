import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import '../state/notes_state.dart';
import '../constants/timing.dart';
import '../widgets/editor_toolbar.dart';
import '../models/frontmatter.dart';

class NoteEditorScreen extends StatefulWidget {
  final String notePath;

  const NoteEditorScreen({super.key, required this.notePath});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  bool _hasChanges = false;
  bool _showPreview = false;
  final ScrollController _editScroll = ScrollController();

  Map<String, dynamic> _metadata = {};
  Color _noteColor = Colors.transparent;
  bool _isTransparent = true;

  @override
  void initState() {
    super.initState();
    final notesState = context.read<NotesState>();
    final content = notesState.currentNoteContent ?? '';

    // Parse frontmatter explicitly
    final fm = Frontmatter.parse(content);
    _metadata = fm.metadata;

    if (_metadata.containsKey('color')) {
      try {
        _noteColor = Color(
            int.parse(_metadata['color'].toString().replaceFirst('#', '0xFF')));
        _isTransparent = false;
      } catch (_) {}
    }

    _controller = TextEditingController(text: fm.body);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _hasChanges = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(TimingConstants.editDebounce, _saveNow);
  }

  Future<void> _saveNow() async {
    if (!_hasChanges) return;
    final notesState = context.read<NotesState>();

    // Serialize with frontmatter
    final fullContent = Frontmatter.serialize(_metadata, _controller.text);

    notesState.updateNoteContent(fullContent);
    await notesState.saveCurrentNote();
    _hasChanges = false;
    if (mounted) setState(() {});
  }

  void _pickColor() async {
    final Color newColor = await showColorPickerDialog(
      context,
      _noteColor,
      title: Text('Note Color', style: Theme.of(context).textTheme.titleLarge),
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
        ColorPickerType.accent: false,
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

    setState(() {
      _noteColor = newColor;
      _isTransparent = false;
      // Convert Color to Hex string for Frontmatter
      _metadata['color'] =
          '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      _hasChanges = true;
      _saveNow();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveNow();
    _controller.dispose();
    _editScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filename = widget.notePath.split('/').last.replaceAll('.md', '');

    final scaffoldBg = _isTransparent ? colorScheme.surface : _noteColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        title: Text(filename),
        actions: [
          if (_hasChanges)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.circle, size: 10, color: Colors.orange),
            ),
          IconButton(
            icon: Icon(_showPreview ? Icons.edit : Icons.visibility),
            tooltip: _showPreview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Note color',
            onPressed: _pickColor,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save now',
            onPressed: _saveNow,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _showPreview ? _buildPreview(theme) : _buildEditor(theme),
          ),
          if (!_showPreview) _buildBottomToolbar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    return Markdown(
      data: _controller.text,
      selectable: true,
      padding: const EdgeInsets.all(24),
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        h2: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        p: TextStyle(
          fontSize: 18,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
        code: TextStyle(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TextField(
        controller: _controller,
        scrollController: _editScroll,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontSize: 18,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'Start writing...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
            top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        child: EditorToolbar(
          controller: _controller,
          onChanged: () {
            _hasChanges = true;
            _debounceTimer?.cancel();
            _debounceTimer = Timer(TimingConstants.editDebounce, _saveNow);
          },
        ),
      ),
    );
  }
}
