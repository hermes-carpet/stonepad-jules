import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../state/notes_state.dart';
import '../constants/timing.dart';
import '../models/frontmatter.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';
import 'package:markdown/markdown.dart' as md;

class NoteEditorScreen extends StatefulWidget {
  final String notePath;

  const NoteEditorScreen({super.key, required this.notePath});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late QuillController _controller;
  Timer? _debounceTimer;
  bool _hasChanges = false;
  final ScrollController _editScroll = ScrollController();
  bool _isToolbarVisible = true;

  Map<String, dynamic> _metadata = {};
  Color _noteColor = Colors.transparent;
  bool _isTransparent = true;
  bool _isReady = false;

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

    // Convert Markdown to Quill Delta
    final mdDocument = md.Document(
        encodeHtml: false,
        extensionSet: md.ExtensionSet.gitHubFlavored);

    final mdToDelta = MarkdownToDelta(
      markdownDocument: mdDocument,
    );

    final delta = mdToDelta.convert(fm.body.isEmpty ? '\n' : fm.body);

    _controller = QuillController(
      document: Document.fromDelta(delta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.addListener(_onTextChanged);
    _isReady = true;
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(TimingConstants.editDebounce, _saveNow);
  }

  Future<void> _saveNow() async {
    if (!_hasChanges) return;

    // Convert Quill Delta back to Markdown
    final deltaToMd = DeltaToMarkdown();
    final markdown = deltaToMd.convert(_controller.document.toDelta());

    final notesState = context.read<NotesState>();

    // Serialize with frontmatter
    final fullContent = Frontmatter.serialize(_metadata, markdown);

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
    if (!_isReady) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    if (notification.scrollDelta != null) {
                      if (notification.scrollDelta! > 2 && _isToolbarVisible) {
                        setState(() => _isToolbarVisible = false);
                      } else if (notification.scrollDelta! < -2 && !_isToolbarVisible) {
                        setState(() => _isToolbarVisible = true);
                      }
                    }
                    return false;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: QuillEditor.basic(
                      controller: _controller,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _isToolbarVisible ? MediaQuery.of(context).viewInsets.bottom + 16 : -100,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: () => _controller.undo(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo),
                      onPressed: () => _controller.redo(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.format_bold),
                      onPressed: () {
                        final attr = _controller.getSelectionStyle().attributes[Attribute.bold.key];
                        _controller.formatSelection(attr == null ? Attribute.bold : Attribute.clone(Attribute.bold, null));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_italic),
                      onPressed: () {
                        final attr = _controller.getSelectionStyle().attributes[Attribute.italic.key];
                        _controller.formatSelection(attr == null ? Attribute.italic : Attribute.clone(Attribute.italic, null));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.title), // Using title for H1 since format_h1 doesn't exist
                      onPressed: () {
                        final attr = _controller.getSelectionStyle().attributes[Attribute.h1.key];
                        _controller.formatSelection(attr == null ? Attribute.h1 : Attribute.clone(Attribute.h1, null));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_size), // Using format_size for H2
                      onPressed: () {
                        final attr = _controller.getSelectionStyle().attributes[Attribute.h2.key];
                        _controller.formatSelection(attr == null ? Attribute.h2 : Attribute.clone(Attribute.h2, null));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_list_bulleted),
                      onPressed: () {
                        final attr = _controller.getSelectionStyle().attributes[Attribute.ul.key];
                        _controller.formatSelection(attr == null ? Attribute.ul : Attribute.clone(Attribute.ul, null));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_list_numbered),
                      onPressed: () {
                        final attr = _controller.getSelectionStyle().attributes[Attribute.ol.key];
                        _controller.formatSelection(attr == null ? Attribute.ol : Attribute.clone(Attribute.ol, null));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_box_outlined),
                      onPressed: () {
                        final attr = _controller.getSelectionStyle().attributes[Attribute.unchecked.key];
                        _controller.formatSelection(attr == null ? Attribute.unchecked : Attribute.clone(Attribute.unchecked, null));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
