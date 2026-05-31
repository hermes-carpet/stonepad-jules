import '../models/note.dart';
import '../services/storage_service.dart';

class NoteHelper {
  static Future<String?> getNoteColor(
      String path, StorageService storage) async {
    final content = await storage.readNote(path);
    if (content == null) return null;

    final note = Note(
      path: path,
      content: content,
      contentHash: '',
      sizeBytes: 0,
      modifiedAt: DateTime.now(),
    );
    return note.colorHex;
  }
}
