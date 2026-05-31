import 'package:flutter_test/flutter_test.dart';
import 'package:stonepad/models/frontmatter.dart';
import 'package:stonepad/models/note.dart';

void main() {
  group('Frontmatter Tests', () {
    test('Parses frontmatter correctly', () {
      const markdown = '---\ncolor: "#FF0000"\n---\n# Heading\nBody';
      final fm = Frontmatter.parse(markdown);
      expect(fm.metadata['color'], '#FF0000');
      expect(fm.body.trim(), '# Heading\nBody');
    });

    test('Parses frontmatter correctly without newline at the end', () {
      const markdown = '---\ncolor: "#00FF00"\n---\nBody only';
      final fm = Frontmatter.parse(markdown);
      expect(fm.metadata['color'], '#00FF00');
      expect(fm.body.trim(), 'Body only');
    });

    test('Handles markdown without frontmatter', () {
      const markdown = '# Heading\nBody';
      final fm = Frontmatter.parse(markdown);
      expect(fm.metadata.isEmpty, isTrue);
      expect(fm.body, markdown);
    });

    test('Serializes frontmatter correctly', () {
      final metadata = {'color': '#123456'};
      const body = '# Title\n\nSome text';
      final serialized = Frontmatter.serialize(metadata, body);
      expect(serialized, '---\ncolor: #123456\n---\n# Title\n\nSome text');
    });

    test('Note helper gets correct hex color', () {
      final note = Note(
        path: 'test.md',
        content: '---\ncolor: "#AABBCC"\n---\n# Hello',
        contentHash: '',
        sizeBytes: 0,
        modifiedAt: DateTime.now(),
      );
      expect(note.colorHex, '#AABBCC');
    });

    test('Note helper returns null if no hex color', () {
      final note = Note(
        path: 'test.md',
        content: '# Hello',
        contentHash: '',
        sizeBytes: 0,
        modifiedAt: DateTime.now(),
      );
      expect(note.colorHex, isNull);
    });
  });
}
