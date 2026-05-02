/// Persists app-owned chat metadata across runtime profiles.
library;

import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';
import 'runtime_profile.dart';

/// ChatCatalogStore reads and writes local chat metadata.
class ChatCatalogStore {
  /// Creates a chat catalog store in the standard app data directory.
  const ChatCatalogStore();

  /// Loads known chats from disk.
  Future<List<ChatCatalogEntry>> load() async {
    final file = File(chatCatalogPath());
    if (!await file.exists()) {
      return const <ChatCatalogEntry>[];
    }
    final decoded = jsonDecode(await file.readAsString());
    final chats = decoded is Map<String, dynamic> ? decoded['chats'] : decoded;
    if (chats is! List) {
      return const <ChatCatalogEntry>[];
    }
    final entries = chats
        .whereType<Map<String, dynamic>>()
        .map(ChatCatalogEntry.fromJson)
        .toList();
    entries.sort(_compareCatalogEntries);
    return entries;
  }

  /// Saves known chats to disk.
  Future<void> save(List<ChatCatalogEntry> entries) async {
    final file = File(chatCatalogPath());
    await file.parent.create(recursive: true);
    final sorted = entries.toList()..sort(_compareCatalogEntries);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      '${encoder.convert(<String, dynamic>{'chats': sorted.map((entry) => entry.toJson()).toList()})}\n',
    );
  }
}

/// Returns the chat catalog JSON path.
String chatCatalogPath() {
  return '${auroraAppConfigDirectoryPath()}/data/chats.json';
}

/// Sorts chat entries by latest activity first.
int _compareCatalogEntries(ChatCatalogEntry left, ChatCatalogEntry right) {
  return right.updatedAt.compareTo(left.updatedAt);
}
