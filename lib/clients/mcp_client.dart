/// Provides JSON-RPC clients for Agent Awesome MCP services.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/app_logger.dart';
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
  McpJsonRpcClient({
    required this.endpoint,
    http.Client? httpClient,
    this.logger,
  }) : _http = httpClient ?? http.Client();

  /// JSON-RPC endpoint URL.
  final String endpoint;

  final http.Client _http;
  final AppLogger? logger;
  int _nextId = 1;

  /// Calls an MCP tool and returns its structured content.
  Future<dynamic> callTool(
    String name, [
    Map<String, dynamic>? arguments,
  ]) async {
    final id = _nextId++;
    final payload = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': 'tools/call',
      'params': <String, dynamic>{
        'name': name,
        'arguments': arguments ?? <String, dynamic>{},
      },
    };
    await _log('POST $endpoint tools/call id=$id name=$name');
    final response = await _http.post(
      Uri.parse(endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    await _log('POST $endpoint tools/call id=$id -> ${response.statusCode}');
    if (response.statusCode != 200) {
      throw McpException('HTTP ${response.statusCode} from $endpoint');
    }
    final content = parseToolStructuredContent(jsonDecode(response.body));
    await _log('tools/call id=$id name=$name parsed');
    return content;
  }

  /// Lists tool names exposed by this MCP endpoint.
  Future<List<String>> listToolNames() async {
    final id = _nextId++;
    final payload = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': 'tools/list',
      'params': <String, dynamic>{},
    };
    await _log('POST $endpoint tools/list id=$id');
    final response = await _http.post(
      Uri.parse(endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    await _log('POST $endpoint tools/list id=$id -> ${response.statusCode}');
    if (response.statusCode != 200) {
      throw McpException('HTTP ${response.statusCode} from $endpoint');
    }
    return parseToolNames(jsonDecode(response.body));
  }

  /// Closes the underlying HTTP client.
  void close() {
    _http.close();
  }

  Future<void> _log(String message) async {
    await logger?.write('mcp-client', message);
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

/// Extracts tool names from a MCP tools/list response.
List<String> parseToolNames(dynamic decoded) {
  if (decoded is! Map<String, dynamic>) {
    throw const McpException('MCP response was not an object');
  }
  if (decoded['error'] != null) {
    throw McpException('JSON-RPC error: ${decoded['error']}');
  }
  final result = decoded['result'];
  if (result is! Map<String, dynamic>) {
    throw const McpException('MCP tools/list result was not an object');
  }
  final tools = result['tools'];
  if (tools is! List) {
    return const <String>[];
  }
  return tools
      .whereType<Map<String, dynamic>>()
      .map((tool) => stringValue(tool['name']))
      .where((name) => name.isNotEmpty)
      .toList();
}

/// MemoryClient wraps the user-facing memory MCP tools.
class MemoryClient {
  /// Creates a memory tool client.
  MemoryClient({required McpJsonRpcClient rpc}) : _rpc = rpc;

  final McpJsonRpcClient _rpc;

  /// MCP endpoint used by this client.
  String get endpoint => _rpc.endpoint;

  /// Lists MCP tool names for compatibility checks.
  Future<List<String>> listToolNames() {
    return _rpc.listToolNames();
  }

  /// Searches catalog records for the memory panel and source list.
  Future<List<MemoryRecord>> searchCatalog({
    String scope = 'user',
    String text = '',
    List<String> kinds = const <String>[],
    List<String> topics = const <String>[],
    List<String> entityIds = const <String>[],
    List<String> allowedSensitivities = const <String>[
      'public',
      'internal',
      'private',
    ],
    int limit = 20,
  }) async {
    final content = await _rpc.callTool('search_catalog', <String, dynamic>{
      'scope': scope,
      'text': text,
      'kinds': kinds,
      'topics': topics,
      'entity_ids': entityIds,
      'allowed_sensitivities': allowedSensitivities,
      'limit': limit,
    });
    return parseMemoryRecords(content);
  }

  /// Searches source-backed text records.
  Future<List<MemoryRecord>> searchSources({
    String scope = 'user',
    String text = '',
    List<String> kinds = const <String>[],
    List<String> topics = const <String>[],
    List<String> entityIds = const <String>[],
    List<String> allowedSensitivities = const <String>[
      'public',
      'internal',
      'private',
    ],
    int limit = 20,
  }) async {
    final content = await _rpc.callTool('search_sources', <String, dynamic>{
      'scope': scope,
      'text': text,
      'kinds': kinds,
      'topics': topics,
      'entity_ids': entityIds,
      'allowed_sensitivities': allowedSensitivities,
      'limit': limit,
    });
    return parseMemoryRecords(content);
  }

  /// Saves a carefully reviewed memory candidate.
  Future<dynamic> saveMemoryCandidate({
    required MemoryCaptureDraft draft,
    String actor = 'aurora-ui',
    String idempotencyKey = '',
  }) {
    return _rpc.callTool('save_memory_candidate', <String, dynamic>{
      'actor': actor,
      'content': draft.content,
      'title': draft.title,
      'media_type': draft.mediaType,
      'source': <String, dynamic>{
        'system': draft.sourceSystem,
        'id': draft.sourceId,
      },
      'kind': draft.kind,
      'scope': draft.scope,
      'trust_level': draft.trustLevel,
      'sensitivity': draft.sensitivity,
      'subjects': draft.subjects,
      'topics': draft.topics,
      'entity_names': draft.entityNames,
      'idempotency_key': idempotencyKey,
    });
  }

  /// Loads or builds a compiled entity page.
  Future<CompiledMemoryPage> loadEntityPage({
    required String scope,
    required String entityId,
    required String title,
  }) async {
    final content = await _rpc.callTool('load_entity_page', <String, dynamic>{
      'scope': scope,
      'entity_id': entityId,
      'title': title,
    });
    return parseCompiledMemoryPage(content);
  }

  /// Loads or builds a source-backed timeline.
  Future<CompiledMemoryPage> loadTimeline({
    required String scope,
    required String topic,
    String entityId = '',
  }) async {
    final content = await _rpc.callTool('load_timeline', <String, dynamic>{
      'scope': scope,
      'topic': topic,
      'entity_id': entityId,
    });
    return parseCompiledMemoryPage(content);
  }

  /// Refreshes a compiled entity page or timeline.
  Future<CompiledMemoryPage> refreshCompiledPage({
    required String kind,
    required String scope,
    required String title,
    String entityId = '',
    String topic = '',
    String actor = 'aurora-ui',
  }) async {
    final content = await _rpc
        .callTool('refresh_compiled_page', <String, dynamic>{
          'actor': actor,
          'kind': kind,
          'scope': scope,
          'title': title,
          'entity_id': entityId,
          'topic': topic,
        });
    return parseCompiledMemoryPage(content);
  }

  /// Applies explicit catalog metadata repairs.
  Future<MemoryRecord> repairCatalogRecord({
    required MemoryRepairDraft draft,
    String actor = 'aurora-ui',
  }) async {
    final arguments = <String, dynamic>{
      'actor': actor,
      'catalog_id': draft.catalogId,
    };
    if (draft.title != null) {
      arguments['title'] = draft.title;
    }
    if (draft.summary != null) {
      arguments['summary'] = draft.summary;
    }
    if (draft.kind != null) {
      arguments['kind'] = draft.kind;
    }
    if (draft.sensitivity != null) {
      arguments['sensitivity'] = draft.sensitivity;
    }
    if (draft.status != null) {
      arguments['status'] = draft.status;
    }
    if (draft.subjects != null) {
      arguments['subjects'] = draft.subjects;
    }
    if (draft.topics != null) {
      arguments['topics'] = draft.topics;
    }
    if (draft.entityNames != null) {
      arguments['entity_names'] = draft.entityNames;
    }
    final content = await _rpc.callTool('repair_catalog_record', arguments);
    return parseMemoryRecord(content);
  }

  /// Stores a user correction as new source-backed memory.
  Future<dynamic> submitMemoryCorrection({
    required String catalogId,
    required String text,
    required String scope,
    String actor = 'aurora-ui',
  }) {
    return _rpc.callTool('submit_memory_correction', <String, dynamic>{
      'actor': actor,
      'catalog_id': catalogId,
      'scope': scope,
      'text': text,
    });
  }

  /// Closes the underlying JSON-RPC HTTP client.
  void close() {
    _rpc.close();
  }
}

/// TasksClient wraps task and list MCP tools for the workspace.
class TasksClient {
  /// Creates a task tool client.
  TasksClient({required McpJsonRpcClient rpc}) : _rpc = rpc;

  final McpJsonRpcClient _rpc;

  /// MCP endpoint used by this client.
  String get endpoint => _rpc.endpoint;

  /// Lists task MCP tool names for compatibility checks.
  Future<List<String>> listToolNames() {
    return _rpc.listToolNames();
  }

  /// Lists operational tasks.
  Future<List<WorkspaceTask>> listTasks({
    TaskFilterState filters = const TaskFilterState(),
    bool includeDone = true,
    bool includeLinks = true,
    int limit = 100,
  }) async {
    final arguments = _taskQueryArguments(
      filters: filters,
      includeDone: includeDone,
      includeLinks: includeLinks,
      limit: limit,
    );
    final content = await _rpc.callTool('list_tasks', arguments);
    return parseWorkspaceTasks(content);
  }

  /// Pages operational tasks with a service cursor.
  Future<TaskPage> pageTasks({
    TaskFilterState filters = const TaskFilterState(),
    String cursor = '',
    bool includeLinks = true,
  }) async {
    final arguments = _taskQueryArguments(
      filters: filters,
      includeDone: filters.includeDone,
      includeLinks: includeLinks,
      limit: filters.limit,
    );
    if (cursor.isNotEmpty) {
      arguments['cursor'] = cursor;
    }
    final content = await _rpc.callTool('page_tasks', arguments);
    return parseTaskPage(content);
  }

  /// Lists named task lists.
  Future<List<WorkspaceTaskList>> listLists({
    bool includeItems = true,
    bool includeLinks = true,
    int limit = 50,
  }) async {
    final content = await _rpc.callTool('list_lists', <String, dynamic>{
      'include_items': includeItems,
      'include_links': includeLinks,
      'limit': limit,
    });
    return parseTaskLists(content);
  }

  /// Creates an operational task.
  Future<WorkspaceTask> createTask({
    required String title,
    String description = '',
    String status = 'open',
    String priority = 'normal',
    DateTime? dueAt,
    DateTime? scheduledAt,
    List<String> topics = const <String>[],
    int estimateMinutes = 0,
    String energyRequired = '',
    double effort = 0,
    double value = 0,
    double urgency = 0,
    double risk = 0,
    String context = '',
    String domain = '',
    String location = '',
    String owner = '',
    String source = '',
    double confidence = 0,
    List<TaskMemoryLinkDraft> memoryLinks = const <TaskMemoryLinkDraft>[],
    String actor = 'aurora-ui',
  }) async {
    final arguments = <String, dynamic>{
      'actor': actor,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
    };
    if (dueAt != null) {
      arguments['due_at'] = _dateArgument(dueAt);
    }
    if (scheduledAt != null) {
      arguments['scheduled_at'] = _dateArgument(scheduledAt);
    }
    if (topics.isNotEmpty) {
      arguments['topics'] = topics;
    }
    _addTaskMetadataArguments(
      arguments,
      estimateMinutes: estimateMinutes,
      energyRequired: energyRequired,
      effort: effort,
      value: value,
      urgency: urgency,
      risk: risk,
      context: context,
      domain: domain,
      location: location,
      owner: owner,
      source: source,
      confidence: confidence,
    );
    if (memoryLinks.isNotEmpty) {
      arguments['memory_links'] = memoryLinks
          .map(_memoryLinkDraftPayload)
          .toList();
    }
    final content = await _rpc.callTool('create_task', arguments);
    return parseWorkspaceTask(content);
  }

  /// Updates mutable task fields.
  Future<WorkspaceTask> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? status,
    String? priority,
    DateTime? dueAt,
    bool clearDueAt = false,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    List<String>? topics,
    bool replaceTopics = false,
    int? estimateMinutes,
    String? energyRequired,
    double? effort,
    double? value,
    double? urgency,
    double? risk,
    String? context,
    String? domain,
    String? location,
    String? owner,
    String? source,
    double? confidence,
    String actor = 'aurora-ui',
  }) async {
    final arguments = <String, dynamic>{'task_id': taskId, 'actor': actor};
    if (title != null) {
      arguments['title'] = title;
    }
    if (description != null) {
      arguments['description'] = description;
    }
    if (status != null) {
      arguments['status'] = status;
    }
    if (priority != null) {
      arguments['priority'] = priority;
    }
    if (dueAt != null) {
      arguments['due_at'] = _dateArgument(dueAt);
    }
    if (clearDueAt) {
      arguments['clear_due_at'] = true;
    }
    if (scheduledAt != null) {
      arguments['scheduled_at'] = _dateArgument(scheduledAt);
    }
    if (clearScheduledAt) {
      arguments['clear_scheduled_at'] = true;
    }
    if (topics != null) {
      arguments['topics'] = topics;
      arguments['replace_topics'] = replaceTopics;
    }
    _addOptionalTaskMetadataArguments(
      arguments,
      estimateMinutes: estimateMinutes,
      energyRequired: energyRequired,
      effort: effort,
      value: value,
      urgency: urgency,
      risk: risk,
      context: context,
      domain: domain,
      location: location,
      owner: owner,
      source: source,
      confidence: confidence,
    );
    final content = await _rpc.callTool('update_task', arguments);
    return parseWorkspaceTask(content);
  }

  /// Marks an operational task complete.
  Future<WorkspaceTask> completeTask(
    String taskId, {
    String actor = 'aurora-ui',
  }) async {
    final content = await _rpc.callTool('complete_task', <String, dynamic>{
      'task_id': taskId,
      'actor': actor,
    });
    return parseWorkspaceTask(content);
  }

  /// Marks an operational task canceled.
  Future<WorkspaceTask> cancelTask(
    String taskId, {
    String actor = 'aurora-ui',
  }) async {
    final content = await _rpc.callTool('cancel_task', <String, dynamic>{
      'task_id': taskId,
      'actor': actor,
    });
    return parseWorkspaceTask(content);
  }

  /// Permanently deletes an operational task.
  Future<void> deleteTask(String taskId, {String actor = 'aurora-ui'}) async {
    await _rpc.callTool('delete_task', <String, dynamic>{
      'task_id': taskId,
      'actor': actor,
    });
  }

  /// Links memory to an operational task.
  Future<TaskMemoryLink> linkTaskMemory({
    required String taskId,
    required TaskMemoryLinkDraft link,
  }) async {
    final content = await _rpc.callTool('link_task_memory', <String, dynamic>{
      'task_id': taskId,
      'link': _memoryLinkDraftPayload(link),
    });
    return parseTaskMemoryLink(content);
  }

  /// Unlinks memory from an operational task.
  Future<void> unlinkTaskMemory({
    required String taskId,
    required String linkId,
  }) async {
    await _rpc.callTool('unlink_task_memory', <String, dynamic>{
      'task_id': taskId,
      'link_id': linkId,
    });
  }

  /// Creates a named task list.
  Future<WorkspaceTaskList> createList({
    required String name,
    String description = '',
    List<String> topics = const <String>[],
    List<TaskMemoryLinkDraft> memoryLinks = const <TaskMemoryLinkDraft>[],
    String actor = 'aurora-ui',
  }) async {
    final arguments = <String, dynamic>{
      'actor': actor,
      'name': name,
      'description': description,
    };
    if (topics.isNotEmpty) {
      arguments['topics'] = topics;
    }
    if (memoryLinks.isNotEmpty) {
      arguments['memory_links'] = memoryLinks
          .map(_memoryLinkDraftPayload)
          .toList();
    }
    final content = await _rpc.callTool('create_list', arguments);
    return parseTaskList(content);
  }

  /// Permanently deletes a named task list.
  Future<void> deleteList(String listId, {String actor = 'aurora-ui'}) async {
    await _rpc.callTool('delete_list', <String, dynamic>{
      'list_id': listId,
      'actor': actor,
    });
  }

  /// Adds an item to a named task list.
  Future<TaskListItem> addListItem({
    required String listId,
    required String text,
    DateTime? dueAt,
    List<TaskMemoryLinkDraft> memoryLinks = const <TaskMemoryLinkDraft>[],
    String actor = 'aurora-ui',
  }) async {
    final arguments = <String, dynamic>{
      'list_id': listId,
      'actor': actor,
      'text': text,
    };
    if (dueAt != null) {
      arguments['due_at'] = _dateArgument(dueAt);
    }
    if (memoryLinks.isNotEmpty) {
      arguments['memory_links'] = memoryLinks
          .map(_memoryLinkDraftPayload)
          .toList();
    }
    final content = await _rpc.callTool('add_list_item', arguments);
    return parseTaskListItem(content);
  }

  /// Updates one named-list item.
  Future<TaskListItem> updateListItem({
    required String itemId,
    String? text,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? checked,
    String actor = 'aurora-ui',
  }) async {
    final arguments = <String, dynamic>{'item_id': itemId, 'actor': actor};
    if (text != null) {
      arguments['text'] = text;
    }
    if (dueAt != null) {
      arguments['due_at'] = _dateArgument(dueAt);
    }
    if (clearDueAt) {
      arguments['clear_due_at'] = true;
    }
    if (checked != null) {
      arguments['checked'] = checked;
    }
    final content = await _rpc.callTool('update_list_item', arguments);
    return parseTaskListItem(content);
  }

  /// Sets one named-list item's checked state.
  Future<TaskListItem> checkListItem({
    required String itemId,
    required bool checked,
    String actor = 'aurora-ui',
  }) async {
    final content = await _rpc.callTool('check_list_item', <String, dynamic>{
      'item_id': itemId,
      'actor': actor,
      'checked': checked,
    });
    return parseTaskListItem(content);
  }

  /// Permanently deletes one named-list item.
  Future<void> deleteListItem(
    String itemId, {
    String actor = 'aurora-ui',
  }) async {
    await _rpc.callTool('delete_list_item', <String, dynamic>{
      'item_id': itemId,
      'actor': actor,
    });
  }

  /// Links memory to a named task list.
  Future<TaskMemoryLink> linkListMemory({
    required String listId,
    required TaskMemoryLinkDraft link,
  }) async {
    final content = await _rpc.callTool('link_list_memory', <String, dynamic>{
      'list_id': listId,
      'link': _memoryLinkDraftPayload(link),
    });
    return parseTaskMemoryLink(content);
  }

  /// Unlinks memory from a named task list.
  Future<void> unlinkListMemory({
    required String listId,
    required String linkId,
  }) async {
    await _rpc.callTool('unlink_list_memory', <String, dynamic>{
      'list_id': listId,
      'link_id': linkId,
    });
  }

  /// Links memory to a named-list item.
  Future<TaskMemoryLink> linkListItemMemory({
    required String itemId,
    required TaskMemoryLinkDraft link,
  }) async {
    final content = await _rpc.callTool(
      'link_list_item_memory',
      <String, dynamic>{
        'item_id': itemId,
        'link': _memoryLinkDraftPayload(link),
      },
    );
    return parseTaskMemoryLink(content);
  }

  /// Unlinks memory from a named-list item.
  Future<void> unlinkListItemMemory({
    required String itemId,
    required String linkId,
  }) async {
    await _rpc.callTool('unlink_list_item_memory', <String, dynamic>{
      'item_id': itemId,
      'link_id': linkId,
    });
  }

  /// Runs the task steward review without mutating state.
  Future<TaskReviewReport> reviewTasks({String actor = 'aurora-ui'}) async {
    final content = await _rpc.callTool('review_tasks', <String, dynamic>{
      'actor': actor,
      'include_done': false,
      'stale_after_days': 14,
    });
    return parseTaskReviewReport(content);
  }

  /// Lists explicit task relation records.
  Future<List<TaskRelationRecord>> listTaskRelations() async {
    final content = await _rpc.callTool('list_task_relations');
    return parseTaskRelations(content);
  }

  /// Creates or updates one task relation.
  Future<TaskRelationRecord> upsertTaskRelation({
    required String fromTaskId,
    required String toTaskId,
    String relationType = 'related_to',
    double confidence = 1,
    String source = 'explicit',
    String explanation = '',
    String actor = 'aurora-ui',
  }) async {
    final content = await _rpc
        .callTool('upsert_task_relation', <String, dynamic>{
          'from_task_id': fromTaskId,
          'to_task_id': toTaskId,
          'relation_type': relationType,
          'confidence': confidence,
          'source': source,
          'explanation': explanation,
          'actor': actor,
        });
    return parseTaskRelation(content);
  }

  /// Deletes one task relation.
  Future<void> deleteTaskRelation(
    String relationId, {
    String actor = 'aurora-ui',
  }) async {
    await _rpc.callTool('delete_task_relation', <String, dynamic>{
      'relation_id': relationId,
      'actor': actor,
    });
  }

  /// Lists first-class task commitments.
  Future<List<TaskCommitment>> listCommitments() async {
    final content = await _rpc.callTool('list_commitments');
    return parseTaskCommitments(content);
  }

  /// Creates or updates one first-class task commitment.
  Future<TaskCommitment> upsertCommitment({
    String commitmentId = '',
    required String taskId,
    List<String> people = const <String>[],
    String domain = '',
    String project = '',
    String timeWindow = '',
    String responsibility = '',
    String promiseSource = '',
    String hardness = '',
    String consequence = '',
    String actor = 'aurora-ui',
  }) async {
    final arguments = <String, dynamic>{
      'task_id': taskId,
      'people': people,
      'domain': domain,
      'project': project,
      'time_window': timeWindow,
      'responsibility': responsibility,
      'promise_source': promiseSource,
      'hardness': hardness,
      'consequence': consequence,
      'actor': actor,
    };
    if (commitmentId.isNotEmpty) {
      arguments['commitment_id'] = commitmentId;
    }
    final content = await _rpc.callTool('upsert_commitment', arguments);
    return parseTaskCommitment(content);
  }

  /// Deletes one first-class task commitment.
  Future<void> deleteCommitment(
    String commitmentId, {
    String actor = 'aurora-ui',
  }) async {
    await _rpc.callTool('delete_commitment', <String, dynamic>{
      'commitment_id': commitmentId,
      'actor': actor,
    });
  }

  /// Lists inferred task relation suggestions.
  Future<List<TaskRelationSuggestion>> suggestTaskRelationships() async {
    final content = await _rpc.callTool('suggest_task_relationships');
    return parseTaskRelationSuggestions(content);
  }

  /// Lists inferred task metadata suggestions.
  Future<List<TaskMetadataSuggestion>> suggestTaskMetadata() async {
    final content = await _rpc.callTool('suggest_task_metadata');
    return parseTaskMetadataSuggestions(content);
  }

  /// Lists inferred task commitment suggestions.
  Future<List<TaskCommitmentSuggestion>> suggestCommitments() async {
    final content = await _rpc.callTool('suggest_commitments');
    return parseTaskCommitmentSuggestions(content);
  }

  /// Accepts one inferred task suggestion.
  Future<void> applyTaskSuggestion(
    String suggestionId, {
    String actor = 'aurora-ui',
  }) async {
    await _rpc.callTool('apply_task_suggestion', <String, dynamic>{
      'suggestion_id': suggestionId,
      'actor': actor,
    });
  }

  /// Dismisses one inferred task suggestion.
  Future<void> dismissTaskSuggestion(
    String suggestionId, {
    String actor = 'aurora-ui',
  }) async {
    await _rpc.callTool('dismiss_task_suggestion', <String, dynamic>{
      'suggestion_id': suggestionId,
      'actor': actor,
    });
  }

  /// Projects tasks into attention-flow lanes.
  Future<TaskStreamProjection> projectTaskStream() async {
    final content = await _rpc.callTool('project_task_stream');
    return parseTaskStreamProjection(content);
  }

  /// Projects tasks into a priority terrain.
  Future<PriorityTerrainProjection> projectPriorityTerrain() async {
    final content = await _rpc.callTool('project_priority_terrain');
    return parsePriorityTerrainProjection(content);
  }

  /// Projects tasks into a relationship constellation.
  Future<TaskConstellationProjection> projectTaskConstellation() async {
    final content = await _rpc.callTool('project_task_constellation');
    return parseTaskConstellationProjection(content);
  }

  /// Projects tasks into a commitment density weave.
  Future<CommitmentWeaveProjection> projectCommitmentWeave() async {
    final content = await _rpc.callTool('project_commitment_weave');
    return parseCommitmentWeaveProjection(content);
  }

  /// Closes the underlying JSON-RPC HTTP client.
  void close() {
    _rpc.close();
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
  return rawRecords
      .whereType<Map<String, dynamic>>()
      .map(parseMemoryRecord)
      .toList();
}

/// Parses one memory catalog record.
MemoryRecord parseMemoryRecord(dynamic content) {
  final record = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  final source = record['source'];
  final raw = record['raw'];
  final sourceSystem = source is Map<String, dynamic>
      ? stringValue(source['system'], fallback: 'source')
      : 'source';
  final sourceId = source is Map<String, dynamic>
      ? stringValue(source['id'])
      : '';
  final rawMap = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  return MemoryRecord(
    id: stringValue(record['id']),
    evidenceId: stringValue(record['evidence_id']),
    title: stringValue(record['title'], fallback: 'Untitled memory'),
    summary: stringValue(record['summary']),
    kind: stringValue(record['kind'], fallback: 'memory'),
    scope: stringValue(record['scope'], fallback: 'user'),
    trustLevel: stringValue(record['trust_level'], fallback: 'source_original'),
    sensitivity: stringValue(record['sensitivity'], fallback: 'private'),
    status: stringValue(record['status'], fallback: 'active'),
    subjects: stringList(record['subjects']),
    topics: stringList(record['topics']),
    entityIds: stringList(record['entity_ids']),
    entityNames: stringList(record['entity_names']),
    sourceSystem: sourceSystem,
    sourceId: sourceId,
    sourceLabel: sourceId.isEmpty ? sourceSystem : '$sourceSystem:$sourceId',
    rawPath: stringValue(rawMap['path']),
    rawChecksum: stringValue(rawMap['checksum']),
    rawMediaType: stringValue(rawMap['media_type']),
    rawContent: stringValue(rawMap['content_text']),
    relationships: parseMemoryRelationships(record['relationships']),
    eventTime: parseOptionalDateTime(record['event_time']),
    createdAt: parseOptionalDateTime(record['created_at']),
    updatedAt: parseOptionalDateTime(record['updated_at']),
  );
}

/// Parses relationship edges from catalog records.
List<MemoryRelationship> parseMemoryRelationships(dynamic content) {
  if (content is! List) {
    return const <MemoryRelationship>[];
  }
  return content.whereType<Map<String, dynamic>>().map((relationship) {
    return MemoryRelationship(
      id: stringValue(relationship['id']),
      fromId: stringValue(relationship['from_id']),
      type: stringValue(relationship['type']),
      toId: stringValue(relationship['to_id']),
      sourceId: stringValue(relationship['source_id']),
      trustLevel: stringValue(
        relationship['trust_level'],
        fallback: 'source_original',
      ),
      createdAt: parseOptionalDateTime(relationship['created_at']),
    );
  }).toList();
}

/// Parses a compiled page returned by the memory service.
CompiledMemoryPage parseCompiledMemoryPage(dynamic content) {
  final page = content is Map<String, dynamic> ? content : <String, dynamic>{};
  return CompiledMemoryPage(
    id: stringValue(page['id']),
    kind: stringValue(page['kind'], fallback: 'entity_page'),
    scope: stringValue(page['scope'], fallback: 'user'),
    title: stringValue(page['title'], fallback: 'Untitled page'),
    path: stringValue(page['path']),
    status: stringValue(page['status'], fallback: 'active'),
    sourceIds: stringList(page['source_ids']),
    content: stringValue(page['content']),
    stale: page['stale'] == true,
    uncertainty: stringList(page['uncertainty']),
    createdAt: parseOptionalDateTime(page['created_at']),
    updatedAt: parseOptionalDateTime(page['updated_at']),
  );
}

/// Parses workspace tasks from task MCP results.
List<WorkspaceTask> parseWorkspaceTasks(dynamic content) {
  if (content is! List) {
    return const <WorkspaceTask>[];
  }
  return content
      .whereType<Map<String, dynamic>>()
      .map(parseWorkspaceTask)
      .toList();
}

/// Parses one workspace task from a task MCP result.
WorkspaceTask parseWorkspaceTask(dynamic content) {
  final task = content is Map<String, dynamic> ? content : <String, dynamic>{};
  final status = stringValue(task['status'], fallback: 'open');
  final priority = stringValue(task['priority'], fallback: 'normal');
  final dueAt = parseOptionalDateTime(task['due_at']);
  final scheduledAt = parseOptionalDateTime(task['scheduled_at']);
  final detailParts = <String>[statusLabel(status)];
  if (priority.isNotEmpty && priority != 'normal') {
    detailParts.add(priorityLabel(priority));
  }
  if (dueAt != null) {
    detailParts.add('Due ${dateOnlyLabel(dueAt)}');
  } else if (scheduledAt != null) {
    detailParts.add('Scheduled ${dateOnlyLabel(scheduledAt)}');
  }
  return WorkspaceTask(
    id: stringValue(task['id']),
    title: stringValue(task['title'], fallback: 'Untitled task'),
    detail: detailParts.join(' • '),
    done: status == 'done',
    description: stringValue(task['description']),
    status: status,
    priority: priority,
    dueAt: dueAt,
    scheduledAt: scheduledAt,
    topics: stringList(task['topics']),
    overdue: boolValue(task['overdue']),
    memoryLinks: parseTaskMemoryLinks(task['memory_links']),
    estimateMinutes: intValue(task['estimate_minutes']),
    energyRequired: stringValue(task['energy_required']),
    effort: doubleValue(task['effort']),
    value: doubleValue(task['value']),
    urgency: doubleValue(task['urgency']),
    risk: doubleValue(task['risk']),
    context: stringValue(task['context']),
    domain: stringValue(task['domain']),
    location: stringValue(task['location']),
    owner: stringValue(task['owner']),
    source: stringValue(task['source']),
    confidence: doubleValue(task['confidence']),
    createdAt: parseOptionalDateTime(task['created_at']),
    updatedAt: parseOptionalDateTime(task['updated_at']),
    completedAt: parseOptionalDateTime(task['completed_at']),
    canceledAt: parseOptionalDateTime(task['canceled_at']),
    active: status == 'open' || status == 'waiting' || status == 'blocked',
    idempotencyKey: stringValue(task['idempotency_key']),
  );
}

/// Parses a cursor-paginated task page.
TaskPage parseTaskPage(dynamic content) {
  final page = content is Map<String, dynamic> ? content : <String, dynamic>{};
  return TaskPage(
    tasks: parseWorkspaceTasks(page['tasks']),
    nextCursor: stringValue(page['next_cursor']),
  );
}

/// Parses task lists from task MCP results.
List<WorkspaceTaskList> parseTaskLists(dynamic content) {
  if (content is! List) {
    return const <WorkspaceTaskList>[];
  }
  return content.whereType<Map<String, dynamic>>().map(parseTaskList).toList();
}

/// Parses one named task list.
WorkspaceTaskList parseTaskList(dynamic content) {
  final list = content is Map<String, dynamic> ? content : <String, dynamic>{};
  return WorkspaceTaskList(
    id: stringValue(list['id']),
    name: stringValue(list['name'], fallback: 'Untitled list'),
    description: stringValue(list['description']),
    topics: stringList(list['topics']),
    actor: stringValue(list['actor']),
    createdAt: parseOptionalDateTime(list['created_at']),
    updatedAt: parseOptionalDateTime(list['updated_at']),
    items: parseTaskListItems(list['items']),
    memoryLinks: parseTaskMemoryLinks(list['memory_links']),
  );
}

/// Parses named-list items.
List<TaskListItem> parseTaskListItems(dynamic content) {
  if (content is! List) {
    return const <TaskListItem>[];
  }
  return content
      .whereType<Map<String, dynamic>>()
      .map(parseTaskListItem)
      .toList();
}

/// Parses one named-list item.
TaskListItem parseTaskListItem(dynamic content) {
  final item = content is Map<String, dynamic> ? content : <String, dynamic>{};
  return TaskListItem(
    id: stringValue(item['id']),
    listId: stringValue(item['list_id']),
    text: stringValue(item['text'], fallback: 'Untitled item'),
    checked: boolValue(item['checked']),
    dueAt: parseOptionalDateTime(item['due_at']),
    actor: stringValue(item['actor']),
    createdAt: parseOptionalDateTime(item['created_at']),
    updatedAt: parseOptionalDateTime(item['updated_at']),
    checkedAt: parseOptionalDateTime(item['checked_at']),
    memoryLinks: parseTaskMemoryLinks(item['memory_links']),
  );
}

/// Parses task memory links.
List<TaskMemoryLink> parseTaskMemoryLinks(dynamic content) {
  if (content is! List) {
    return const <TaskMemoryLink>[];
  }
  return content
      .whereType<Map<String, dynamic>>()
      .map(parseTaskMemoryLink)
      .toList();
}

/// Parses one task memory link.
TaskMemoryLink parseTaskMemoryLink(dynamic content) {
  final link = content is Map<String, dynamic> ? content : <String, dynamic>{};
  return TaskMemoryLink(
    id: stringValue(link['id']),
    memoryCatalogId: stringValue(link['memory_catalog_id']),
    memoryEvidenceId: stringValue(link['memory_evidence_id']),
    relationship: stringValue(link['relationship'], fallback: 'context'),
    note: stringValue(link['note']),
    createdAt: parseOptionalDateTime(link['created_at']),
  );
}

/// Parses a task steward review report.
TaskReviewReport parseTaskReviewReport(dynamic content) {
  final report = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  return TaskReviewReport(
    actor: stringValue(report['actor']),
    generatedAt: parseOptionalDateTime(report['generated_at']),
    reviewedTasks: intValue(report['reviewed_tasks']),
    reviewedLists: intValue(report['reviewed_lists']),
    summary: stringValue(report['summary']),
    recommendations: parseTaskReviewRecommendations(report['recommendations']),
  );
}

/// Parses task steward recommendations.
List<TaskReviewRecommendation> parseTaskReviewRecommendations(dynamic content) {
  if (content is! List) {
    return const <TaskReviewRecommendation>[];
  }
  return content.whereType<Map<String, dynamic>>().map((item) {
    return TaskReviewRecommendation(
      kind: stringValue(item['kind']),
      severity: stringValue(item['severity'], fallback: 'info'),
      targetType: stringValue(item['target_type']),
      targetId: stringValue(item['target_id']),
      title: stringValue(item['title'], fallback: 'Task recommendation'),
      message: stringValue(item['message']),
      proposedAction: stringValue(item['proposed_action']),
    );
  }).toList();
}

/// Parses explicit task relation records.
List<TaskRelationRecord> parseTaskRelations(dynamic content) {
  if (content is! List) {
    return const <TaskRelationRecord>[];
  }
  return content
      .whereType<Map<String, dynamic>>()
      .map(parseTaskRelation)
      .toList();
}

/// Parses one explicit task relation record.
TaskRelationRecord parseTaskRelation(dynamic content) {
  final relation = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  return TaskRelationRecord(
    id: stringValue(relation['id']),
    fromTaskId: stringValue(relation['from_task_id']),
    toTaskId: stringValue(relation['to_task_id']),
    relationType: stringValue(
      relation['relation_type'],
      fallback: 'related_to',
    ),
    confidence: doubleValue(relation['confidence']),
    source: stringValue(relation['source']),
    explanation: stringValue(relation['explanation']),
    actor: stringValue(relation['actor']),
    createdAt: parseOptionalDateTime(relation['created_at']),
    updatedAt: parseOptionalDateTime(relation['updated_at']),
  );
}

/// Parses inferred task relation suggestions.
List<TaskRelationSuggestion> parseTaskRelationSuggestions(dynamic content) {
  if (content is! List) {
    return const <TaskRelationSuggestion>[];
  }
  return content.whereType<Map<String, dynamic>>().map((suggestion) {
    return TaskRelationSuggestion(
      id: stringValue(suggestion['id']),
      fromTaskId: stringValue(suggestion['from_task_id']),
      toTaskId: stringValue(suggestion['to_task_id']),
      relationType: stringValue(
        suggestion['relation_type'],
        fallback: 'related_to',
      ),
      confidence: doubleValue(suggestion['confidence']),
      explanation: stringValue(suggestion['explanation']),
    );
  }).toList();
}

/// Parses inferred task metadata suggestions.
List<TaskMetadataSuggestion> parseTaskMetadataSuggestions(dynamic content) {
  if (content is! List) {
    return const <TaskMetadataSuggestion>[];
  }
  return content.whereType<Map<String, dynamic>>().map((suggestion) {
    return TaskMetadataSuggestion(
      id: stringValue(suggestion['id']),
      taskId: stringValue(suggestion['task_id']),
      estimateMinutes: intValue(suggestion['estimate_minutes']),
      energyRequired: stringValue(suggestion['energy_required']),
      effort: doubleValue(suggestion['effort']),
      value: doubleValue(suggestion['value']),
      urgency: doubleValue(suggestion['urgency']),
      risk: doubleValue(suggestion['risk']),
      context: stringValue(suggestion['context']),
      domain: stringValue(suggestion['domain']),
      location: stringValue(suggestion['location']),
      owner: stringValue(suggestion['owner']),
      source: stringValue(suggestion['source']),
      confidence: doubleValue(suggestion['confidence']),
      explanation: stringValue(suggestion['explanation']),
    );
  }).toList();
}

/// Parses inferred task commitment suggestions.
List<TaskCommitmentSuggestion> parseTaskCommitmentSuggestions(dynamic content) {
  if (content is! List) {
    return const <TaskCommitmentSuggestion>[];
  }
  return content.whereType<Map<String, dynamic>>().map((suggestion) {
    return TaskCommitmentSuggestion(
      id: stringValue(suggestion['id']),
      taskId: stringValue(suggestion['task_id']),
      people: stringList(suggestion['people']),
      domain: stringValue(suggestion['domain']),
      project: stringValue(suggestion['project']),
      timeWindow: stringValue(suggestion['time_window']),
      responsibility: stringValue(suggestion['responsibility']),
      promiseSource: stringValue(suggestion['promise_source']),
      hardness: stringValue(suggestion['hardness']),
      consequence: stringValue(suggestion['consequence']),
      confidence: doubleValue(suggestion['confidence']),
      explanation: stringValue(suggestion['explanation']),
    );
  }).toList();
}

/// Parses stored task commitments.
List<TaskCommitment> parseTaskCommitments(dynamic content) {
  if (content is! List) {
    return const <TaskCommitment>[];
  }
  return content
      .whereType<Map<String, dynamic>>()
      .map(parseTaskCommitment)
      .toList();
}

/// Parses one stored task commitment.
TaskCommitment parseTaskCommitment(dynamic content) {
  final commitment = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  return TaskCommitment(
    id: stringValue(commitment['id']),
    taskId: stringValue(commitment['task_id']),
    people: stringList(commitment['people']),
    domain: stringValue(commitment['domain']),
    project: stringValue(commitment['project']),
    timeWindow: stringValue(commitment['time_window']),
    responsibility: stringValue(commitment['responsibility']),
    promiseSource: stringValue(commitment['promise_source']),
    hardness: stringValue(commitment['hardness']),
    consequence: stringValue(commitment['consequence']),
    actor: stringValue(commitment['actor']),
    createdAt: parseOptionalDateTime(commitment['created_at']),
    updatedAt: parseOptionalDateTime(commitment['updated_at']),
  );
}

/// Parses a task stream projection.
TaskStreamProjection parseTaskStreamProjection(dynamic content) {
  final projection = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  return TaskStreamProjection(
    generatedAt: parseOptionalDateTime(projection['generated_at']),
    lanes: parseTaskStreamLanes(projection['lanes']),
    links: parseTaskStreamLinks(projection['links']),
  );
}

/// Parses task stream lanes.
List<TaskStreamLane> parseTaskStreamLanes(dynamic content) {
  if (content is! List) {
    return const <TaskStreamLane>[];
  }
  return content.whereType<Map<String, dynamic>>().map((lane) {
    return TaskStreamLane(
      id: stringValue(lane['id']),
      title: stringValue(lane['title'], fallback: 'Lane'),
      subtitle: stringValue(lane['subtitle']),
      cards: parseTaskStreamCards(lane['cards']),
    );
  }).toList();
}

/// Parses task stream cards.
List<TaskStreamCard> parseTaskStreamCards(dynamic content) {
  if (content is! List) {
    return const <TaskStreamCard>[];
  }
  return content.whereType<Map<String, dynamic>>().map((card) {
    return TaskStreamCard(
      taskId: stringValue(card['task_id']),
      title: stringValue(card['title'], fallback: 'Untitled task'),
      status: stringValue(card['status'], fallback: 'open'),
      priority: stringValue(card['priority'], fallback: 'normal'),
      dueAt: parseOptionalDateTime(card['due_at']),
      scheduledAt: parseOptionalDateTime(card['scheduled_at']),
      context: stringValue(card['context']),
      domain: stringValue(card['domain']),
      project: stringValue(card['project']),
      owner: stringValue(card['owner']),
      flowLane: stringValue(card['flow_lane']),
      streamId: stringValue(card['stream_id']),
      readyNow: boolValue(card['ready_now']),
      nextBestAction: stringValue(card['next_best_action']),
      batchScore: doubleValue(card['batch_score']),
      contextSwitchCost: doubleValue(card['context_switch_cost']),
      costLabel: stringValue(
        card['cost_label'],
        fallback: stringValue(card['cost']),
      ),
      costScore: doubleValue(card['cost_score']),
      bottleneckScore: doubleValue(card['bottleneck_score']),
      confidence: doubleValue(card['confidence']),
      explanation: stringValue(card['explanation']),
      relatedTaskCount: intValue(card['related_task_count']),
      estimateMinutes: intValue(card['estimate_minutes']),
    );
  }).toList();
}

/// Parses task stream relation links.
List<TaskStreamLink> parseTaskStreamLinks(dynamic content) {
  if (content is! List) {
    return const <TaskStreamLink>[];
  }
  return content.whereType<Map<String, dynamic>>().map((link) {
    return TaskStreamLink(
      fromTaskId: stringValue(link['from_task_id']),
      toTaskId: stringValue(link['to_task_id']),
      relationType: stringValue(link['relation_type']),
      transitionType: stringValue(link['transition_type']),
      streamId: stringValue(link['stream_id']),
      confidence: doubleValue(link['confidence']),
      explanation: stringValue(link['explanation']),
    );
  }).toList();
}

/// Parses a priority terrain projection.
PriorityTerrainProjection parsePriorityTerrainProjection(dynamic content) {
  final projection = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  return PriorityTerrainProjection(
    generatedAt: parseOptionalDateTime(projection['generated_at']),
    points: parsePriorityTerrainPoints(projection['points']),
    bands: parsePriorityTerrainBands(projection['bands']),
  );
}

/// Parses priority terrain points.
List<PriorityTerrainPoint> parsePriorityTerrainPoints(dynamic content) {
  if (content is! List) {
    return const <PriorityTerrainPoint>[];
  }
  return content.whereType<Map<String, dynamic>>().map((point) {
    return PriorityTerrainPoint(
      taskId: stringValue(point['task_id']),
      title: stringValue(point['title'], fallback: 'Untitled task'),
      status: stringValue(point['status'], fallback: 'open'),
      priority: stringValue(point['priority'], fallback: 'normal'),
      dueAt: parseOptionalDateTime(point['due_at']),
      urgencyScore: doubleValue(point['urgency_score']),
      valueScore: doubleValue(point['value_score']),
      effortScore: doubleValue(point['effort_score']),
      riskScore: doubleValue(point['risk_score']),
      x: doubleValue(point['x']),
      y: doubleValue(point['y']),
      elevation: doubleValue(point['elevation']),
      recommendedNextStep: stringValue(point['recommended_next_step']),
      confidence: doubleValue(point['confidence']),
      explanation: stringValue(point['explanation']),
    );
  }).toList();
}

/// Parses priority terrain bands.
List<PriorityTerrainBand> parsePriorityTerrainBands(dynamic content) {
  if (content is! List) {
    return const <PriorityTerrainBand>[];
  }
  return content.whereType<Map<String, dynamic>>().map((band) {
    return PriorityTerrainBand(
      id: stringValue(band['id']),
      title: stringValue(band['title'], fallback: 'Band'),
      description: stringValue(band['description']),
    );
  }).toList();
}

/// Parses a task constellation projection.
TaskConstellationProjection parseTaskConstellationProjection(dynamic content) {
  final projection = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  return TaskConstellationProjection(
    generatedAt: parseOptionalDateTime(projection['generated_at']),
    nodes: parseTaskConstellationNodes(projection['nodes']),
    edges: parseTaskConstellationEdges(projection['edges']),
  );
}

/// Parses task constellation nodes.
List<TaskConstellationNode> parseTaskConstellationNodes(dynamic content) {
  if (content is! List) {
    return const <TaskConstellationNode>[];
  }
  return content.whereType<Map<String, dynamic>>().map((node) {
    return TaskConstellationNode(
      taskId: stringValue(node['task_id']),
      title: stringValue(node['title'], fallback: 'Untitled task'),
      status: stringValue(node['status'], fallback: 'open'),
      category: stringValue(node['category']),
      timeHorizon: stringValue(node['time_horizon']),
      x: doubleValue(node['x']),
      y: doubleValue(node['y']),
      size: doubleValue(node['size']),
      urgency: doubleValue(node['urgency']),
      confidence: doubleValue(node['confidence']),
      explanation: stringValue(node['explanation']),
    );
  }).toList();
}

/// Parses task constellation edges.
List<TaskConstellationEdge> parseTaskConstellationEdges(dynamic content) {
  if (content is! List) {
    return const <TaskConstellationEdge>[];
  }
  return content.whereType<Map<String, dynamic>>().map((edge) {
    return TaskConstellationEdge(
      fromTaskId: stringValue(edge['from_task_id']),
      toTaskId: stringValue(edge['to_task_id']),
      relationType: stringValue(edge['relation_type']),
      confidence: doubleValue(edge['confidence']),
      source: stringValue(edge['source']),
      explanation: stringValue(edge['explanation']),
    );
  }).toList();
}

/// Parses a commitment weave projection.
CommitmentWeaveProjection parseCommitmentWeaveProjection(dynamic content) {
  final projection = content is Map<String, dynamic>
      ? content
      : <String, dynamic>{};
  return CommitmentWeaveProjection(
    generatedAt: parseOptionalDateTime(projection['generated_at']),
    columns: parseCommitmentWeaveColumns(projection['columns']),
    rows: parseCommitmentWeaveRows(projection['rows']),
    items: parseCommitmentWeaveItems(projection['items']),
  );
}

/// Parses commitment weave columns.
List<CommitmentWeaveColumn> parseCommitmentWeaveColumns(dynamic content) {
  if (content is! List) {
    return const <CommitmentWeaveColumn>[];
  }
  return content.whereType<Map<String, dynamic>>().map((column) {
    return CommitmentWeaveColumn(
      id: stringValue(column['id']),
      title: stringValue(column['title'], fallback: 'Time'),
      subtitle: stringValue(column['subtitle']),
    );
  }).toList();
}

/// Parses commitment weave rows.
List<CommitmentWeaveRow> parseCommitmentWeaveRows(dynamic content) {
  if (content is! List) {
    return const <CommitmentWeaveRow>[];
  }
  return content.whereType<Map<String, dynamic>>().map((row) {
    return CommitmentWeaveRow(
      id: stringValue(row['id']),
      title: stringValue(row['title'], fallback: 'Row'),
      group: stringValue(row['group'], fallback: 'Domain'),
      density: doubleValue(row['density']),
      conflict: boolValue(row['conflict']),
    );
  }).toList();
}

/// Parses commitment weave items.
List<CommitmentWeaveItem> parseCommitmentWeaveItems(dynamic content) {
  if (content is! List) {
    return const <CommitmentWeaveItem>[];
  }
  return content.whereType<Map<String, dynamic>>().map((item) {
    return CommitmentWeaveItem(
      taskId: stringValue(item['task_id']),
      title: stringValue(item['title'], fallback: 'Untitled task'),
      rowId: stringValue(item['row_id']),
      columnId: stringValue(item['column_id']),
      status: stringValue(item['status'], fallback: 'open'),
      priority: stringValue(item['priority'], fallback: 'normal'),
      density: doubleValue(item['density']),
      conflict: boolValue(item['conflict']),
      explanation: stringValue(item['explanation']),
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

/// Converts a dynamic list into display strings.
List<String> stringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map(stringValue).where((item) => item.isNotEmpty).toList();
}

/// Converts a dynamic value to a bool.
bool boolValue(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return fallback;
}

/// Converts a dynamic value to an integer.
int intValue(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

/// Converts a dynamic value to a double.
double doubleValue(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

/// Parses an optional service timestamp.
DateTime? parseOptionalDateTime(dynamic value) {
  final text = stringValue(value);
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
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

/// Converts backend task priority values into compact display labels.
String priorityLabel(String priority) {
  switch (priority) {
    case 'urgent':
      return 'Urgent';
    case 'high':
      return 'High';
    case 'low':
      return 'Low';
    default:
      return 'Normal';
  }
}

/// Formats a task date for compact row details.
String dateOnlyLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Builds task query arguments while omitting empty filters.
Map<String, dynamic> _taskQueryArguments({
  required TaskFilterState filters,
  required bool includeDone,
  required bool includeLinks,
  required int limit,
}) {
  final arguments = <String, dynamic>{
    'include_done': includeDone,
    'include_links': includeLinks,
    'limit': limit,
  };
  if (filters.statuses.isNotEmpty) {
    arguments['statuses'] = filters.statuses;
  }
  if (filters.priorities.isNotEmpty) {
    arguments['priorities'] = filters.priorities;
  }
  if (filters.topics.isNotEmpty) {
    arguments['topics'] = filters.topics;
  }
  if (filters.search.trim().isNotEmpty) {
    arguments['search'] = filters.search.trim();
  }
  if (filters.overdueOnly) {
    arguments['overdue_only'] = true;
  }
  return arguments;
}

/// Adds non-empty task graph metadata arguments to a create payload.
void _addTaskMetadataArguments(
  Map<String, dynamic> arguments, {
  required int estimateMinutes,
  required String energyRequired,
  required double effort,
  required double value,
  required double urgency,
  required double risk,
  required String context,
  required String domain,
  required String location,
  required String owner,
  required String source,
  required double confidence,
}) {
  if (estimateMinutes > 0) {
    arguments['estimate_minutes'] = estimateMinutes;
  }
  if (energyRequired.trim().isNotEmpty) {
    arguments['energy_required'] = energyRequired.trim();
  }
  if (effort > 0) {
    arguments['effort'] = effort;
  }
  if (value > 0) {
    arguments['value'] = value;
  }
  if (urgency > 0) {
    arguments['urgency'] = urgency;
  }
  if (risk > 0) {
    arguments['risk'] = risk;
  }
  if (context.trim().isNotEmpty) {
    arguments['context'] = context.trim();
  }
  if (domain.trim().isNotEmpty) {
    arguments['domain'] = domain.trim();
  }
  if (location.trim().isNotEmpty) {
    arguments['location'] = location.trim();
  }
  if (owner.trim().isNotEmpty) {
    arguments['owner'] = owner.trim();
  }
  if (source.trim().isNotEmpty) {
    arguments['source'] = source.trim();
  }
  if (confidence > 0) {
    arguments['confidence'] = confidence;
  }
}

/// Adds nullable task graph metadata arguments to an update payload.
void _addOptionalTaskMetadataArguments(
  Map<String, dynamic> arguments, {
  required int? estimateMinutes,
  required String? energyRequired,
  required double? effort,
  required double? value,
  required double? urgency,
  required double? risk,
  required String? context,
  required String? domain,
  required String? location,
  required String? owner,
  required String? source,
  required double? confidence,
}) {
  if (estimateMinutes != null) {
    arguments['estimate_minutes'] = estimateMinutes;
  }
  if (energyRequired != null) {
    arguments['energy_required'] = energyRequired.trim();
  }
  if (effort != null) {
    arguments['effort'] = effort;
  }
  if (value != null) {
    arguments['value'] = value;
  }
  if (urgency != null) {
    arguments['urgency'] = urgency;
  }
  if (risk != null) {
    arguments['risk'] = risk;
  }
  if (context != null) {
    arguments['context'] = context.trim();
  }
  if (domain != null) {
    arguments['domain'] = domain.trim();
  }
  if (location != null) {
    arguments['location'] = location.trim();
  }
  if (owner != null) {
    arguments['owner'] = owner.trim();
  }
  if (source != null) {
    arguments['source'] = source.trim();
  }
  if (confidence != null) {
    arguments['confidence'] = confidence;
  }
}

/// Formats a timestamp for task MCP arguments.
String _dateArgument(DateTime value) {
  return value.toUtc().toIso8601String();
}

/// Converts a memory link draft to task MCP arguments.
Map<String, dynamic> _memoryLinkDraftPayload(TaskMemoryLinkDraft draft) {
  final payload = <String, dynamic>{'relationship': draft.relationship};
  if (draft.memoryCatalogId.isNotEmpty) {
    payload['memory_catalog_id'] = draft.memoryCatalogId;
  }
  if (draft.memoryEvidenceId.isNotEmpty) {
    payload['memory_evidence_id'] = draft.memoryEvidenceId;
  }
  if (draft.note.isNotEmpty) {
    payload['note'] = draft.note;
  }
  return payload;
}

/// TaskPage stores one cursor-paginated task result page.
class TaskPage {
  /// Creates a task page.
  const TaskPage({required this.tasks, this.nextCursor = ''});

  /// Page tasks.
  final List<WorkspaceTask> tasks;

  /// Cursor for the next page.
  final String nextCursor;
}
