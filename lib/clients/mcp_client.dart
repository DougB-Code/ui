/// Provides JSON-RPC clients for Agent Awesome MCP services.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// McpException reports a JSON-RPC or MCP tool error.
class McpException implements Exception {
  /// Creates an MCP exception with a display message.
  const McpException(this.message);

  /// Error message.
  final String message;

  /// Formats the exception for logs and UI fallback details.
  @override
  String toString() => 'McpException: $message';
}

/// McpJsonRpcClient calls one streamable HTTP MCP JSON-RPC endpoint.
class McpJsonRpcClient {
  /// Creates a JSON-RPC client for an MCP endpoint.
  McpJsonRpcClient({required this.endpoint, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// JSON-RPC endpoint URL.
  final String endpoint;

  final http.Client _http;
  int _nextId = 1;

  /// Calls an MCP tool and returns its structured content.
  Future<dynamic> callTool(
    String name, [
    Map<String, dynamic>? arguments,
  ]) async {
    final payload = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': _nextId++,
      'method': 'tools/call',
      'params': <String, dynamic>{
        'name': name,
        'arguments': arguments ?? <String, dynamic>{},
      },
    };
    final response = await _http.post(
      Uri.parse(endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw McpException('HTTP ${response.statusCode} from $endpoint');
    }
    return parseToolStructuredContent(jsonDecode(response.body));
  }

  /// Closes the underlying HTTP client.
  void close() {
    _http.close();
  }
}

/// Extracts structuredContent from a MCP tools/call response.
dynamic parseToolStructuredContent(dynamic decoded) {
  if (decoded is! Map<String, dynamic>) {
    throw const McpException('MCP response was not an object');
  }
  if (decoded['error'] != null) {
    throw McpException('JSON-RPC error: ${decoded['error']}');
  }
  final result = decoded['result'];
  if (result is! Map<String, dynamic>) {
    throw const McpException('MCP result was not an object');
  }
  if (result['isError'] == true) {
    throw McpException('Tool returned error: ${result['structuredContent']}');
  }
  return result['structuredContent'];
}

/// MemoryClient wraps the user-facing memory MCP tools.
class MemoryClient {
  /// Creates a memory tool client.
  MemoryClient({required McpJsonRpcClient rpc}) : _rpc = rpc;

  final McpJsonRpcClient _rpc;

  /// Searches catalog records for the memory panel and source list.
  Future<List<MemoryRecord>> searchCatalog({
    String scope = 'user',
    String text = '',
    int limit = 20,
  }) async {
    final content = await _rpc.callTool('search_catalog', <String, dynamic>{
      'scope': scope,
      'text': text,
      'limit': limit,
    });
    return parseMemoryRecords(content);
  }

  /// Searches source-backed text records.
  Future<List<MemoryRecord>> searchSources({
    String scope = 'user',
    String text = '',
    int limit = 20,
  }) async {
    final content = await _rpc.callTool('search_sources', <String, dynamic>{
      'scope': scope,
      'text': text,
      'limit': limit,
    });
    return parseMemoryRecords(content);
  }

  /// Loads or builds a compiled entity page.
  Future<dynamic> loadEntityPage({
    required String scope,
    required String entityId,
    required String title,
  }) {
    return _rpc.callTool('load_entity_page', <String, dynamic>{
      'scope': scope,
      'entity_id': entityId,
      'title': title,
    });
  }

  /// Loads or builds a source-backed timeline.
  Future<dynamic> loadTimeline({
    required String scope,
    required String topic,
    String entityId = '',
  }) {
    return _rpc.callTool('load_timeline', <String, dynamic>{
      'scope': scope,
      'topic': topic,
      'entity_id': entityId,
    });
  }
}

/// TasksClient wraps task and list MCP tools for the workspace.
class TasksClient {
  /// Creates a task tool client.
  TasksClient({required McpJsonRpcClient rpc}) : _rpc = rpc;

  final McpJsonRpcClient _rpc;

  /// Lists operational tasks.
  Future<List<WorkspaceTask>> listTasks({
    bool includeDone = true,
    bool includeLinks = true,
    int limit = 30,
  }) async {
    final content = await _rpc.callTool('list_tasks', <String, dynamic>{
      'include_done': includeDone,
      'include_links': includeLinks,
      'limit': limit,
    });
    return parseWorkspaceTasks(content);
  }

  /// Lists named task lists.
  Future<dynamic> listLists({bool includeItems = true}) {
    return _rpc.callTool('list_lists', <String, dynamic>{
      'include_items': includeItems,
      'include_links': true,
      'limit': 20,
    });
  }

  /// Creates an operational task.
  Future<dynamic> createTask({
    required String title,
    String description = '',
    String actor = 'aurora-ui',
  }) {
    return _rpc.callTool('create_task', <String, dynamic>{
      'actor': actor,
      'title': title,
      'description': description,
      'priority': 'normal',
    });
  }

  /// Marks an operational task complete.
  Future<dynamic> completeTask(String taskId, {String actor = 'aurora-ui'}) {
    return _rpc.callTool('complete_task', <String, dynamic>{
      'task_id': taskId,
      'actor': actor,
    });
  }

  /// Runs the task steward review without mutating state.
  Future<dynamic> reviewTasks({String actor = 'aurora-ui'}) {
    return _rpc.callTool('review_tasks', <String, dynamic>{
      'actor': actor,
      'include_done': false,
      'stale_after_days': 14,
    });
  }
}

/// Parses memory records from memory retrieval bundles.
List<MemoryRecord> parseMemoryRecords(dynamic content) {
  final bundle = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  final rawRecords = bundle['primary_evidence'];
  if (rawRecords is! List) {
    return const <MemoryRecord>[];
  }
  return rawRecords.whereType<Map<String, dynamic>>().map((record) {
    final source = record['source'];
    final topics = record['topics'];
    return MemoryRecord(
      id: stringValue(record['id']),
      title: stringValue(record['title'], fallback: 'Untitled memory'),
      summary: stringValue(record['summary']),
      kind: stringValue(record['kind'], fallback: 'memory'),
      topics: topics is List ? topics.map(stringValue).toList() : const [],
      sourceLabel: source is Map<String, dynamic>
          ? '${stringValue(source['system'], fallback: 'source')}:${stringValue(source['id'])}'
          : 'source',
    );
  }).toList();
}

/// Parses workspace tasks from task MCP results.
List<WorkspaceTask> parseWorkspaceTasks(dynamic content) {
  if (content is! List) {
    return const <WorkspaceTask>[];
  }
  return content.whereType<Map<String, dynamic>>().map((task) {
    final status = stringValue(task['status'], fallback: 'open');
    final dueAt = stringValue(task['due_at']);
    final detail = dueAt.isEmpty
        ? statusLabel(status)
        : '${statusLabel(status)} • $dueAt';
    return WorkspaceTask(
      id: stringValue(task['id']),
      title: stringValue(task['title'], fallback: 'Untitled task'),
      detail: detail,
      done: status == 'done',
      active: status == 'open' || status == 'blocked',
    );
  }).toList();
}

/// Converts a dynamic value to a display string.
String stringValue(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

/// Converts backend task status values into compact display labels.
String statusLabel(String status) {
  switch (status) {
    case 'done':
      return 'Done';
    case 'waiting':
      return 'Waiting';
    case 'blocked':
      return 'Blocked';
    case 'canceled':
      return 'Canceled';
    default:
      return 'Open';
  }
}
