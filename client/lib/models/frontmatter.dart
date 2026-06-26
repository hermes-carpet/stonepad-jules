import 'package:yaml/yaml.dart';

/// Helper to parse and update YAML frontmatter in Markdown strings.
class Frontmatter {
  final Map<String, dynamic> metadata;
  final String body;

  Frontmatter(this.metadata, this.body);

  static Frontmatter parse(String markdown) {
    if (!markdown.startsWith('---\n') && !markdown.startsWith('---\r\n')) {
      return Frontmatter({}, markdown);
    }

    final endMatch =
        RegExp(r'\n---\n|\r\n---\r\n').firstMatch(markdown.substring(3));
    if (endMatch == null) {
      return Frontmatter({}, markdown);
    }

    final yamlString = markdown.substring(3, endMatch.start + 3);
    final body = markdown.substring(endMatch.end + 3);

    try {
      final yamlDoc = loadYaml(yamlString);
      if (yamlDoc is YamlMap) {
        return Frontmatter(Map<String, dynamic>.from(yamlDoc), body);
      }
    } catch (_) {
      // Invalid YAML, treat as no metadata
    }

    return Frontmatter({}, markdown);
  }

  static String serialize(Map<String, dynamic> metadata, String body) {
    if (metadata.isEmpty) {
      return body;
    }
    final sb = StringBuffer();
    sb.writeln('---');
    metadata.forEach((key, value) {
      // Simple serialization for basic key-value string/bool pairs.
      sb.writeln('$key: $value');
    });
    sb.writeln('---');
    // Ensure body starts on a new line but don't add extra empty lines
    if (body.isNotEmpty && !body.startsWith('\n')) {
      sb.write(body);
    } else {
      sb.write(body);
    }
    return sb.toString();
  }
}
