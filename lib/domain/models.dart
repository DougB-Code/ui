/// Contains UI-facing domain models shared by clients, state, and widgets.
library;

/// ConnectionStateKind describes service availability for the shell.
enum ConnectionStateKind {
  /// The service has not been checked yet.
  unknown,

  /// The service responded successfully.
  connected,

  /// The service failed or timed out.
  disconnected,
}

/// ChatRole identifies the speaker or event class in a chat timeline.
enum ChatRole {
  /// User-authored message.
  user,

  /// Assistant-authored message.
  assistant,

  /// Tool or function activity.
  tool,
}

/// ChatSession represents the ADK session backing one user-visible chat.
class ChatSession {
  /// Creates a user-visible chat summary backed by an ADK session.
  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  /// ADK session identifier.
  final String id;

  /// Human-readable title.
  final String title;

  /// Last update timestamp.
  final DateTime updatedAt;
}

/// ChatCatalogEntry stores app-owned chat metadata across profiles.
class ChatCatalogEntry {
  /// Creates a local chat catalog entry.
  const ChatCatalogEntry({
    required this.profilePath,
    required this.profileId,
    required this.profileLabel,
    required this.sessionId,
    required this.title,
    required this.updatedAt,
    this.createdAt,
    this.titleStatus = 'session',
    this.titleError = '',
  });

  /// Runtime profile path that owns the ADK session.
  final String profilePath;

  /// Runtime profile id captured when the chat was cataloged.
  final String profileId;

  /// Runtime profile label captured when the chat was cataloged.
  final String profileLabel;

  /// ADK session id inside the owning profile.
  final String sessionId;

  /// App-visible chat title.
  final String title;

  /// Chat creation timestamp when known.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

  /// Title generation state such as session, manual, pending, generated, or failed.
  final String titleStatus;

  /// Last title generation error.
  final String titleError;

  /// Stable app-local key for profile/session lookup.
  String get key {
    return '$profilePath::$sessionId';
  }

  /// Returns a copy with selected metadata changed.
  ChatCatalogEntry copyWith({
    String? profilePath,
    String? profileId,
    String? profileLabel,
    String? sessionId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? titleStatus,
    String? titleError,
  }) {
    return ChatCatalogEntry(
      profilePath: profilePath ?? this.profilePath,
      profileId: profileId ?? this.profileId,
      profileLabel: profileLabel ?? this.profileLabel,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      titleStatus: titleStatus ?? this.titleStatus,
      titleError: titleError ?? this.titleError,
    );
  }

  /// Encodes this catalog entry to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile_path': profilePath,
      'profile_id': profileId,
      'profile_label': profileLabel,
      'session_id': sessionId,
      'title': title,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'title_status': titleStatus,
      'title_error': titleError,
    };
  }

  /// Parses a catalog entry from decoded JSON.
  factory ChatCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ChatCatalogEntry(
      profilePath: _modelString(json['profile_path']),
      profileId: _modelString(json['profile_id']),
      profileLabel: _modelString(json['profile_label']),
      sessionId: _modelString(json['session_id']),
      title: _modelString(json['title'], fallback: 'Untitled chat'),
      createdAt: _modelDateTime(json['created_at']),
      updatedAt: _modelDateTime(json['updated_at']) ?? DateTime.now(),
      titleStatus: _modelString(json['title_status'], fallback: 'session'),
      titleError: _modelString(json['title_error']),
    );
  }
}

/// ChatMessage represents one normalized message or activity row.
class ChatMessage {
  /// Creates a normalized chat message.
  const ChatMessage({
    required this.id,
    required this.role,
    required this.author,
    required this.text,
    required this.createdAt,
    this.toolActivity,
    this.isPartial = false,
  });

  /// Stable UI id.
  final String id;

  /// Speaker or event type.
  final ChatRole role;

  /// Display author.
  final String author;

  /// Display text.
  final String text;

  /// Timestamp for ordering and display.
  final DateTime createdAt;

  /// Optional tool activity metadata.
  final ToolActivity? toolActivity;

  /// Whether the message is a streaming partial.
  final bool isPartial;

  /// Returns a copy with changed display text.
  ChatMessage copyWith({String? text, bool? isPartial}) {
    return ChatMessage(
      id: id,
      role: role,
      author: author,
      text: text ?? this.text,
      createdAt: createdAt,
      toolActivity: toolActivity,
      isPartial: isPartial ?? this.isPartial,
    );
  }
}

/// ToolActivity summarizes one function call or result.
class ToolActivity {
  /// Creates a tool activity row.
  const ToolActivity({
    required this.name,
    required this.status,
    required this.summary,
  });

  /// Tool or function name.
  final String name;

  /// Short status such as requested, completed, or denied.
  final String status;

  /// Human-readable summary.
  final String summary;
}

/// ConfirmationRequest stores an ADK confirmation prompt awaiting user choice.
class ConfirmationRequest {
  /// Creates a confirmation request.
  const ConfirmationRequest({
    required this.callId,
    required this.hint,
    required this.options,
    this.toolName = '',
  });

  /// ADK function-call id to echo in the response.
  final String callId;

  /// Human-readable prompt text.
  final String hint;

  /// Available confirmation options.
  final List<ConfirmationOption> options;

  /// Original tool name that requested confirmation, when supplied by ADK.
  final String toolName;
}

/// ConfirmationOption describes one selectable confirmation action.
class ConfirmationOption {
  /// Creates a confirmation option.
  const ConfirmationOption({required this.action, required this.label});

  /// Machine action sent back to ADK.
  final String action;

  /// User-facing label.
  final String label;
}

/// ConfirmationReply is the user's response to an ADK confirmation request.
class ConfirmationReply {
  /// Creates a confirmation reply.
  const ConfirmationReply({
    required this.callId,
    required this.confirmed,
    this.action,
  });

  /// ADK function-call id.
  final String callId;

  /// Whether the action is approved.
  final bool confirmed;

  /// Optional selected action.
  final String? action;
}

/// MemoryRecord represents one durable memory row for display.
class MemoryRecord {
  /// Creates a display memory record.
  const MemoryRecord({
    required this.id,
    required this.title,
    required this.summary,
    required this.kind,
    required this.topics,
    required this.sourceLabel,
    this.evidenceId = '',
    this.scope = 'user',
    this.trustLevel = 'source_original',
    this.sensitivity = 'private',
    this.status = 'active',
    this.subjects = const <String>[],
    this.entityIds = const <String>[],
    this.entityNames = const <String>[],
    this.sourceSystem = '',
    this.sourceId = '',
    this.rawPath = '',
    this.rawChecksum = '',
    this.rawMediaType = '',
    this.rawContent = '',
    this.relationships = const <MemoryRelationship>[],
    this.eventTime,
    this.createdAt,
    this.updatedAt,
  });

  /// Catalog id.
  final String id;

  /// Display title.
  final String title;

  /// Short summary.
  final String summary;

  /// Memory kind.
  final String kind;

  /// Topics associated with the record.
  final List<String> topics;

  /// Source label.
  final String sourceLabel;

  /// Raw evidence id backing the catalog record.
  final String evidenceId;

  /// Ownership and visibility boundary.
  final String scope;

  /// Provenance trust classification.
  final String trustLevel;

  /// Disclosure sensitivity.
  final String sensitivity;

  /// Lifecycle status.
  final String status;

  /// Primary subject headings.
  final List<String> subjects;

  /// Canonical entity ids linked to the record.
  final List<String> entityIds;

  /// Canonical entity names linked to the record.
  final List<String> entityNames;

  /// Source system name.
  final String sourceSystem;

  /// Source system record id.
  final String sourceId;

  /// Durable raw evidence path.
  final String rawPath;

  /// Raw evidence checksum.
  final String rawChecksum;

  /// Raw evidence media type.
  final String rawMediaType;

  /// Optional hydrated raw evidence text.
  final String rawContent;

  /// Outgoing memory relationships.
  final List<MemoryRelationship> relationships;

  /// Optional real-world event time.
  final DateTime? eventTime;

  /// Catalog creation time.
  final DateTime? createdAt;

  /// Catalog update time.
  final DateTime? updatedAt;

  /// Returns a copy with hydrated source content or repaired metadata.
  MemoryRecord copyWith({
    String? title,
    String? summary,
    String? kind,
    String? scope,
    String? trustLevel,
    String? sensitivity,
    String? status,
    List<String>? subjects,
    List<String>? topics,
    List<String>? entityIds,
    List<String>? entityNames,
    String? rawContent,
    List<MemoryRelationship>? relationships,
    DateTime? updatedAt,
  }) {
    return MemoryRecord(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      kind: kind ?? this.kind,
      topics: topics ?? this.topics,
      sourceLabel: sourceLabel,
      evidenceId: evidenceId,
      scope: scope ?? this.scope,
      trustLevel: trustLevel ?? this.trustLevel,
      sensitivity: sensitivity ?? this.sensitivity,
      status: status ?? this.status,
      subjects: subjects ?? this.subjects,
      entityIds: entityIds ?? this.entityIds,
      entityNames: entityNames ?? this.entityNames,
      sourceSystem: sourceSystem,
      sourceId: sourceId,
      rawPath: rawPath,
      rawChecksum: rawChecksum,
      rawMediaType: rawMediaType,
      rawContent: rawContent ?? this.rawContent,
      relationships: relationships ?? this.relationships,
      eventTime: eventTime,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// MemoryRelationship represents a typed edge between memory objects.
class MemoryRelationship {
  /// Creates a memory relationship edge.
  const MemoryRelationship({
    required this.id,
    required this.fromId,
    required this.type,
    required this.toId,
    required this.trustLevel,
    this.sourceId = '',
    this.createdAt,
  });

  /// Relationship id.
  final String id;

  /// Source memory object id.
  final String fromId;

  /// Controlled relationship type.
  final String type;

  /// Target memory object id.
  final String toId;

  /// Evidence id supporting the edge.
  final String sourceId;

  /// Trust classification for the edge.
  final String trustLevel;

  /// Relationship creation time.
  final DateTime? createdAt;
}

/// CompiledMemoryPage represents a source-backed entity page or timeline.
class CompiledMemoryPage {
  /// Creates a compiled memory page.
  const CompiledMemoryPage({
    required this.id,
    required this.kind,
    required this.scope,
    required this.title,
    required this.path,
    required this.status,
    required this.sourceIds,
    this.content = '',
    this.stale = false,
    this.uncertainty = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  /// Page id.
  final String id;

  /// Page kind, usually entity_page or timeline.
  final String kind;

  /// Ownership scope used to build the page.
  final String scope;

  /// Human-readable page title.
  final String title;

  /// Durable page path.
  final String path;

  /// Lifecycle status.
  final String status;

  /// Evidence ids cited by the page.
  final List<String> sourceIds;

  /// Optional markdown content.
  final String content;

  /// Whether the page should be rebuilt.
  final bool stale;

  /// Known uncertainty surfaced during compilation.
  final List<String> uncertainty;

  /// Page creation time.
  final DateTime? createdAt;

  /// Page update time.
  final DateTime? updatedAt;
}

/// MemoryFilterState stores catalog retrieval and local stewardship filters.
class MemoryFilterState {
  /// Creates memory filter state.
  const MemoryFilterState({
    this.scope = 'user',
    this.text = '',
    this.kinds = const <String>[],
    this.topics = const <String>[],
    this.entityIds = const <String>[],
    this.allowedSensitivities = const <String>['public', 'internal', 'private'],
    this.localStatus = '',
    this.localTrustLevel = '',
    this.limit = 100,
  });

  /// Retrieval scope.
  final String scope;

  /// Full-text query.
  final String text;

  /// Included memory kinds.
  final List<String> kinds;

  /// Required topics.
  final List<String> topics;

  /// Required entity ids.
  final List<String> entityIds;

  /// Sensitivity levels allowed in retrieval.
  final List<String> allowedSensitivities;

  /// Local status filter applied after retrieval.
  final String localStatus;

  /// Local trust filter applied after retrieval.
  final String localTrustLevel;

  /// Maximum records to request.
  final int limit;

  /// Returns a copy with updated filter fields.
  MemoryFilterState copyWith({
    String? scope,
    String? text,
    List<String>? kinds,
    List<String>? topics,
    List<String>? entityIds,
    List<String>? allowedSensitivities,
    String? localStatus,
    String? localTrustLevel,
    int? limit,
  }) {
    return MemoryFilterState(
      scope: scope ?? this.scope,
      text: text ?? this.text,
      kinds: kinds ?? this.kinds,
      topics: topics ?? this.topics,
      entityIds: entityIds ?? this.entityIds,
      allowedSensitivities: allowedSensitivities ?? this.allowedSensitivities,
      localStatus: localStatus ?? this.localStatus,
      localTrustLevel: localTrustLevel ?? this.localTrustLevel,
      limit: limit ?? this.limit,
    );
  }
}

/// MemoryCaptureDraft stores a careful user-authored capture request.
class MemoryCaptureDraft {
  /// Creates a memory capture draft.
  const MemoryCaptureDraft({
    required this.content,
    required this.title,
    required this.kind,
    required this.scope,
    required this.trustLevel,
    required this.sensitivity,
    required this.sourceSystem,
    required this.sourceId,
    this.mediaType = 'text/plain; charset=utf-8',
    this.subjects = const <String>[],
    this.topics = const <String>[],
    this.entityNames = const <String>[],
  });

  /// Source text or serialized source content.
  final String content;

  /// Human-readable catalog title.
  final String title;

  /// Memory kind.
  final String kind;

  /// Memory scope.
  final String scope;

  /// Trust level.
  final String trustLevel;

  /// Sensitivity level.
  final String sensitivity;

  /// Source system label.
  final String sourceSystem;

  /// Source record id.
  final String sourceId;

  /// Source media type.
  final String mediaType;

  /// Subject headings.
  final List<String> subjects;

  /// Topic labels.
  final List<String> topics;

  /// Entity labels.
  final List<String> entityNames;
}

/// MemoryRepairDraft stores explicit catalog metadata corrections.
class MemoryRepairDraft {
  /// Creates a catalog repair draft.
  const MemoryRepairDraft({
    required this.catalogId,
    this.title,
    this.summary,
    this.kind,
    this.sensitivity,
    this.status,
    this.subjects,
    this.topics,
    this.entityNames,
  });

  /// Catalog record id.
  final String catalogId;

  /// Corrected title.
  final String? title;

  /// Corrected summary.
  final String? summary;

  /// Corrected kind.
  final String? kind;

  /// Corrected sensitivity.
  final String? sensitivity;

  /// Corrected lifecycle status.
  final String? status;

  /// Corrected subject headings.
  final List<String>? subjects;

  /// Corrected topic labels.
  final List<String>? topics;

  /// Corrected entity names.
  final List<String>? entityNames;
}

/// SourceItem represents a file/source backing the workspace.
class SourceItem {
  /// Creates a source item.
  const SourceItem({
    required this.id,
    required this.title,
    required this.detail,
  });

  /// Stable source id.
  final String id;

  /// Display title.
  final String title;

  /// Secondary text.
  final String detail;
}

/// WorkspaceTask represents a task or plan step in the UI.
class WorkspaceTask {
  /// Creates a workspace task.
  const WorkspaceTask({
    required this.id,
    required this.title,
    required this.detail,
    required this.done,
    this.description = '',
    this.status = 'open',
    this.priority = 'normal',
    this.dueAt,
    this.scheduledAt,
    this.topics = const <String>[],
    this.estimateMinutes = 0,
    this.energyRequired = '',
    this.effort = 0,
    this.value = 0,
    this.urgency = 0,
    this.risk = 0,
    this.context = '',
    this.domain = '',
    this.location = '',
    this.owner = '',
    this.source = '',
    this.confidence = 0,
    this.overdue = false,
    this.memoryLinks = const <TaskMemoryLink>[],
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.canceledAt,
    this.active = false,
    this.idempotencyKey = '',
    this.sourceId = '',
    this.sourceLabel = '',
  });

  /// Task id.
  final String id;

  /// Task title.
  final String title;

  /// Secondary status text.
  final String detail;

  /// Whether the task is complete.
  final bool done;

  /// Task notes.
  final String description;

  /// Backend lifecycle status.
  final String status;

  /// Backend priority value.
  final String priority;

  /// Optional due timestamp.
  final DateTime? dueAt;

  /// Optional scheduled timestamp.
  final DateTime? scheduledAt;

  /// Organization topics.
  final List<String> topics;

  /// Estimated task duration in minutes.
  final int estimateMinutes;

  /// Required energy mode.
  final String energyRequired;

  /// Effort score from 0 to 1.
  final double effort;

  /// Value score from 0 to 1.
  final double value;

  /// Urgency score from 0 to 1.
  final double urgency;

  /// Risk score from 0 to 1.
  final double risk;

  /// Execution context.
  final String context;

  /// Life or work domain.
  final String domain;

  /// Location requirement.
  final String location;

  /// Task owner.
  final String owner;

  /// Task source.
  final String source;

  /// Metadata confidence from 0 to 1.
  final double confidence;

  /// Whether the task is past due.
  final bool overdue;

  /// Contextual memory references.
  final List<TaskMemoryLink> memoryLinks;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Completion timestamp.
  final DateTime? completedAt;

  /// Cancellation timestamp.
  final DateTime? canceledAt;

  /// Whether the task is currently active.
  final bool active;

  /// Backend idempotency key, used to associate agent-created tasks with chats.
  final String idempotencyKey;

  /// Runtime profile server id that returned this task.
  final String sourceId;

  /// Runtime profile server label that returned this task.
  final String sourceLabel;

  /// Returns a copy with changed runtime source metadata.
  WorkspaceTask copyWith({String? sourceId, String? sourceLabel}) {
    return WorkspaceTask(
      id: id,
      title: title,
      detail: detail,
      done: done,
      description: description,
      status: status,
      priority: priority,
      dueAt: dueAt,
      scheduledAt: scheduledAt,
      topics: topics,
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
      overdue: overdue,
      memoryLinks: memoryLinks,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
      canceledAt: canceledAt,
      active: active,
      idempotencyKey: idempotencyKey,
      sourceId: sourceId ?? this.sourceId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
    );
  }
}

/// TaskMemoryLink references memory attached to a task object.
class TaskMemoryLink {
  /// Creates a task memory link.
  const TaskMemoryLink({
    required this.id,
    this.memoryCatalogId = '',
    this.memoryEvidenceId = '',
    this.relationship = 'context',
    this.note = '',
    this.createdAt,
  });

  /// Link id.
  final String id;

  /// Linked memory catalog id.
  final String memoryCatalogId;

  /// Linked memory evidence id.
  final String memoryEvidenceId;

  /// Relationship from task object to memory.
  final String relationship;

  /// Optional link note.
  final String note;

  /// Creation timestamp.
  final DateTime? createdAt;
}

/// TaskMemoryLinkDraft describes a memory link write request.
class TaskMemoryLinkDraft {
  /// Creates a memory link draft.
  const TaskMemoryLinkDraft({
    this.memoryCatalogId = '',
    this.memoryEvidenceId = '',
    this.relationship = 'context',
    this.note = '',
  });

  /// Memory catalog id to link.
  final String memoryCatalogId;

  /// Memory evidence id to link.
  final String memoryEvidenceId;

  /// Relationship from task object to memory.
  final String relationship;

  /// Optional link note.
  final String note;
}

/// TaskListItem represents one checklist item inside a named task list.
class TaskListItem {
  /// Creates a task list item.
  const TaskListItem({
    required this.id,
    required this.listId,
    required this.text,
    required this.checked,
    this.dueAt,
    this.actor = '',
    this.createdAt,
    this.updatedAt,
    this.checkedAt,
    this.memoryLinks = const <TaskMemoryLink>[],
  });

  /// Item id.
  final String id;

  /// Parent list id.
  final String listId;

  /// Item text.
  final String text;

  /// Whether the item is checked.
  final bool checked;

  /// Optional due timestamp.
  final DateTime? dueAt;

  /// Last actor.
  final String actor;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Checked timestamp.
  final DateTime? checkedAt;

  /// Contextual memory references.
  final List<TaskMemoryLink> memoryLinks;
}

/// WorkspaceTaskList represents a named checklist workspace.
class WorkspaceTaskList {
  /// Creates a named task list.
  const WorkspaceTaskList({
    required this.id,
    required this.name,
    this.description = '',
    this.topics = const <String>[],
    this.actor = '',
    this.createdAt,
    this.updatedAt,
    this.items = const <TaskListItem>[],
    this.memoryLinks = const <TaskMemoryLink>[],
    this.sourceId = '',
    this.sourceLabel = '',
  });

  /// List id.
  final String id;

  /// List name.
  final String name;

  /// List notes.
  final String description;

  /// Organization topics.
  final List<String> topics;

  /// Last actor.
  final String actor;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;

  /// Checklist items.
  final List<TaskListItem> items;

  /// Contextual memory references.
  final List<TaskMemoryLink> memoryLinks;

  /// Runtime profile server id that returned this list.
  final String sourceId;

  /// Runtime profile server label that returned this list.
  final String sourceLabel;

  /// Returns a copy with changed runtime source metadata.
  WorkspaceTaskList copyWith({String? sourceId, String? sourceLabel}) {
    return WorkspaceTaskList(
      id: id,
      name: name,
      description: description,
      topics: topics,
      actor: actor,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items,
      memoryLinks: memoryLinks,
      sourceId: sourceId ?? this.sourceId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
    );
  }
}

/// TaskFilterState stores the active local task work-queue filters.
class TaskFilterState {
  /// Creates task queue filters.
  const TaskFilterState({
    this.statuses = const <String>['open', 'waiting', 'blocked'],
    this.priorities = const <String>[],
    this.topics = const <String>[],
    this.search = '',
    this.overdueOnly = false,
    this.includeDone = true,
    this.limit = 100,
  });

  /// Statuses to display; empty means all statuses.
  final List<String> statuses;

  /// Priorities to display; empty means all priorities.
  final List<String> priorities;

  /// Topics to display; empty means all topics.
  final List<String> topics;

  /// Local search text.
  final String search;

  /// Whether to display only overdue tasks.
  final bool overdueOnly;

  /// Whether done and canceled tasks may be displayed.
  final bool includeDone;

  /// Requested service page size.
  final int limit;

  /// Returns a filter copy with selected fields changed.
  TaskFilterState copyWith({
    List<String>? statuses,
    List<String>? priorities,
    List<String>? topics,
    String? search,
    bool? overdueOnly,
    bool? includeDone,
    int? limit,
  }) {
    return TaskFilterState(
      statuses: statuses ?? this.statuses,
      priorities: priorities ?? this.priorities,
      topics: topics ?? this.topics,
      search: search ?? this.search,
      overdueOnly: overdueOnly ?? this.overdueOnly,
      includeDone: includeDone ?? this.includeDone,
      limit: limit ?? this.limit,
    );
  }
}

/// TaskRelationRecord stores one explicit or inferred relation edge.
class TaskRelationRecord {
  /// Creates a task relation record.
  const TaskRelationRecord({
    required this.id,
    required this.fromTaskId,
    required this.toTaskId,
    required this.relationType,
    this.confidence = 0,
    this.source = '',
    this.explanation = '',
    this.actor = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Stable relation id.
  final String id;

  /// Source task id.
  final String fromTaskId;

  /// Target task id.
  final String toTaskId;

  /// Relationship type.
  final String relationType;

  /// Relation confidence from 0 to 1.
  final double confidence;

  /// Relation source.
  final String source;

  /// Human-readable explanation.
  final String explanation;

  /// Last actor.
  final String actor;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;
}

/// TaskRelationSuggestion stores one inferred relation recommendation.
class TaskRelationSuggestion {
  /// Creates a task relation suggestion.
  const TaskRelationSuggestion({
    required this.id,
    required this.fromTaskId,
    required this.toTaskId,
    required this.relationType,
    this.confidence = 0,
    this.explanation = '',
  });

  /// Stable suggestion id.
  final String id;

  /// Source task id.
  final String fromTaskId;

  /// Target task id.
  final String toTaskId;

  /// Relationship type.
  final String relationType;

  /// Suggestion confidence.
  final double confidence;

  /// Suggestion explanation.
  final String explanation;
}

/// TaskMetadataSuggestion stores one inferred metadata recommendation.
class TaskMetadataSuggestion {
  /// Creates a task metadata suggestion.
  const TaskMetadataSuggestion({
    required this.id,
    required this.taskId,
    this.estimateMinutes = 0,
    this.energyRequired = '',
    this.effort = 0,
    this.value = 0,
    this.urgency = 0,
    this.risk = 0,
    this.context = '',
    this.domain = '',
    this.location = '',
    this.owner = '',
    this.source = '',
    this.confidence = 0,
    this.explanation = '',
  });

  /// Stable suggestion id.
  final String id;

  /// Task receiving metadata.
  final String taskId;

  /// Estimated task duration.
  final int estimateMinutes;

  /// Suggested energy mode.
  final String energyRequired;

  /// Suggested effort score.
  final double effort;

  /// Suggested value score.
  final double value;

  /// Suggested urgency score.
  final double urgency;

  /// Suggested risk score.
  final double risk;

  /// Suggested execution context.
  final String context;

  /// Suggested domain.
  final String domain;

  /// Suggested location.
  final String location;

  /// Suggested owner.
  final String owner;

  /// Suggested source.
  final String source;

  /// Suggestion confidence.
  final double confidence;

  /// Human-readable explanation.
  final String explanation;
}

/// TaskCommitmentSuggestion stores one inferred commitment recommendation.
class TaskCommitmentSuggestion {
  /// Creates a task commitment suggestion.
  const TaskCommitmentSuggestion({
    required this.id,
    required this.taskId,
    this.people = const <String>[],
    this.domain = '',
    this.project = '',
    this.timeWindow = '',
    this.responsibility = '',
    this.promiseSource = '',
    this.hardness = '',
    this.consequence = '',
    this.confidence = 0,
    this.explanation = '',
  });

  /// Stable suggestion id.
  final String id;

  /// Task represented by this suggested commitment.
  final String taskId;

  /// Suggested affected people.
  final List<String> people;

  /// Suggested life or work domain.
  final String domain;

  /// Suggested project.
  final String project;

  /// Suggested time window.
  final String timeWindow;

  /// Suggested responsibility state.
  final String responsibility;

  /// Suggested promise source.
  final String promiseSource;

  /// Suggested soft or hard commitment.
  final String hardness;

  /// Suggested consequence if ignored.
  final String consequence;

  /// Suggestion confidence.
  final double confidence;

  /// Human-readable explanation.
  final String explanation;
}

/// TaskCommitment stores one first-class task commitment.
class TaskCommitment {
  /// Creates a task commitment.
  const TaskCommitment({
    required this.id,
    required this.taskId,
    this.people = const <String>[],
    this.domain = '',
    this.project = '',
    this.timeWindow = '',
    this.responsibility = '',
    this.promiseSource = '',
    this.hardness = '',
    this.consequence = '',
    this.actor = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Stable commitment id.
  final String id;

  /// Referenced task id.
  final String taskId;

  /// Affected people.
  final List<String> people;

  /// Life or work domain.
  final String domain;

  /// Project name.
  final String project;

  /// Time window label.
  final String timeWindow;

  /// Responsibility state.
  final String responsibility;

  /// Source of promise.
  final String promiseSource;

  /// Soft or hard commitment.
  final String hardness;

  /// Consequence if ignored.
  final String consequence;

  /// Last actor.
  final String actor;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last update timestamp.
  final DateTime? updatedAt;
}

/// TaskStreamProjection groups tasks into time lanes with attention-flow links.
class TaskStreamProjection {
  /// Creates a task stream projection.
  const TaskStreamProjection({
    this.generatedAt,
    this.lanes = const <TaskStreamLane>[],
    this.links = const <TaskStreamLink>[],
  });

  /// Projection generation timestamp.
  final DateTime? generatedAt;

  /// Ordered stream lanes.
  final List<TaskStreamLane> lanes;

  /// Visible relation links between projected stream cards.
  final List<TaskStreamLink> links;
}

/// TaskStreamLane stores one stream time column.
class TaskStreamLane {
  /// Creates a task stream lane.
  const TaskStreamLane({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.cards = const <TaskStreamCard>[],
  });

  /// Stable lane id.
  final String id;

  /// Display title.
  final String title;

  /// Secondary display text.
  final String subtitle;

  /// Projected task cards.
  final List<TaskStreamCard> cards;
}

/// TaskStreamCard stores one projected task card.
class TaskStreamCard {
  /// Creates a task stream card.
  const TaskStreamCard({
    required this.taskId,
    required this.title,
    required this.status,
    required this.priority,
    this.dueAt,
    this.scheduledAt,
    this.context = '',
    this.domain = '',
    this.project = '',
    this.owner = '',
    this.flowLane = '',
    this.streamId = '',
    this.readyNow = false,
    this.nextBestAction = '',
    this.batchScore = 0,
    this.contextSwitchCost = 0,
    this.costLabel = '',
    this.costScore = 0,
    this.bottleneckScore = 0,
    this.confidence = 0,
    this.explanation = '',
    this.relatedTaskCount = 0,
    this.estimateMinutes = 0,
  });

  /// Referenced task id.
  final String taskId;

  /// Display task title.
  final String title;

  /// Backend task status.
  final String status;

  /// Backend task priority.
  final String priority;

  /// Optional due timestamp.
  final DateTime? dueAt;

  /// Optional scheduled timestamp.
  final DateTime? scheduledAt;

  /// Best inferred context.
  final String context;

  /// Life or work domain when supplied by the task stream backend.
  final String domain;

  /// Owning project when supplied by the task stream backend.
  final String project;

  /// Responsible person when supplied by the task stream backend.
  final String owner;

  /// Broad attention-mode swimlane.
  final String flowLane;

  /// Stable route identifier for coloring related flow edges.
  final String streamId;

  /// Whether the task can be acted on now.
  final bool readyNow;

  /// Suggested next action.
  final String nextBestAction;

  /// Batching score from 0 to 1.
  final double batchScore;

  /// Context-switch cost from 0 to 1.
  final double contextSwitchCost;

  /// Human-readable cost label when supplied by the backend.
  final String costLabel;

  /// Normalized cost score from 0 to 1 when supplied by the backend.
  final double costScore;

  /// Bottleneck score from 0 to 1.
  final double bottleneckScore;

  /// Projection confidence from 0 to 1.
  final double confidence;

  /// Human-readable placement explanation.
  final String explanation;

  /// Number of related task edges.
  final int relatedTaskCount;

  /// Estimated duration in minutes.
  final int estimateMinutes;
}

/// TaskStreamLink stores a relation that can be drawn across stream rows.
class TaskStreamLink {
  /// Creates a stream relation link.
  const TaskStreamLink({
    required this.fromTaskId,
    required this.toTaskId,
    required this.relationType,
    this.transitionType = '',
    this.streamId = '',
    this.confidence = 0,
    this.explanation = '',
  });

  /// Source projected task id.
  final String fromTaskId;

  /// Target projected task id.
  final String toTaskId;

  /// Relation type from the task graph.
  final String relationType;

  /// Attention-flow transition type.
  final String transitionType;

  /// Stable route identifier for coloring this transition.
  final String streamId;

  /// Relation confidence from 0 to 1.
  final double confidence;

  /// Human-readable relation explanation.
  final String explanation;
}

/// PriorityTerrainProjection stores priority terrain points.
class PriorityTerrainProjection {
  /// Creates a priority terrain projection.
  const PriorityTerrainProjection({
    this.generatedAt,
    this.points = const <PriorityTerrainPoint>[],
    this.bands = const <PriorityTerrainBand>[],
  });

  /// Projection generation timestamp.
  final DateTime? generatedAt;

  /// Projected task points.
  final List<PriorityTerrainPoint> points;

  /// Named terrain bands.
  final List<PriorityTerrainBand> bands;
}

/// PriorityTerrainPoint stores one task's terrain placement.
class PriorityTerrainPoint {
  /// Creates a priority terrain point.
  const PriorityTerrainPoint({
    required this.taskId,
    required this.title,
    required this.status,
    required this.priority,
    this.dueAt,
    this.urgencyScore = 0,
    this.valueScore = 0,
    this.effortScore = 0,
    this.riskScore = 0,
    this.x = 0,
    this.y = 0,
    this.elevation = 0,
    this.recommendedNextStep = '',
    this.confidence = 0,
    this.explanation = '',
  });

  /// Referenced task id.
  final String taskId;

  /// Display title.
  final String title;

  /// Backend task status.
  final String status;

  /// Backend task priority.
  final String priority;

  /// Optional due timestamp.
  final DateTime? dueAt;

  /// Normalized urgency score.
  final double urgencyScore;

  /// Normalized value score.
  final double valueScore;

  /// Normalized effort score.
  final double effortScore;

  /// Normalized risk score.
  final double riskScore;

  /// Normalized x coordinate.
  final double x;

  /// Normalized y coordinate.
  final double y;

  /// Combined priority score.
  final double elevation;

  /// Suggested next step.
  final String recommendedNextStep;

  /// Projection confidence from 0 to 1.
  final double confidence;

  /// Placement explanation.
  final String explanation;
}

/// PriorityTerrainBand describes one terrain region.
class PriorityTerrainBand {
  /// Creates a priority terrain band.
  const PriorityTerrainBand({
    required this.id,
    required this.title,
    this.description = '',
  });

  /// Stable band id.
  final String id;

  /// Display title.
  final String title;

  /// Region explanation.
  final String description;
}

/// TaskConstellationProjection stores spatial task graph nodes and edges.
class TaskConstellationProjection {
  /// Creates a task constellation projection.
  const TaskConstellationProjection({
    this.generatedAt,
    this.nodes = const <TaskConstellationNode>[],
    this.edges = const <TaskConstellationEdge>[],
  });

  /// Projection generation timestamp.
  final DateTime? generatedAt;

  /// Spatial task nodes.
  final List<TaskConstellationNode> nodes;

  /// Visual relation edges.
  final List<TaskConstellationEdge> edges;
}

/// TaskConstellationNode stores one spatial task node.
class TaskConstellationNode {
  /// Creates a task constellation node.
  const TaskConstellationNode({
    required this.taskId,
    required this.title,
    required this.status,
    this.category = '',
    this.timeHorizon = '',
    this.x = 0,
    this.y = 0,
    this.size = 0,
    this.urgency = 0,
    this.confidence = 0,
    this.explanation = '',
  });

  /// Referenced task id.
  final String taskId;

  /// Display title.
  final String title;

  /// Backend task status.
  final String status;

  /// Context or category label.
  final String category;

  /// Time horizon label.
  final String timeHorizon;

  /// Normalized x coordinate.
  final double x;

  /// Normalized y coordinate.
  final double y;

  /// Normalized node size.
  final double size;

  /// Normalized urgency.
  final double urgency;

  /// Projection confidence.
  final double confidence;

  /// Placement explanation.
  final String explanation;
}

/// TaskConstellationEdge stores one task relation edge.
class TaskConstellationEdge {
  /// Creates a task constellation edge.
  const TaskConstellationEdge({
    required this.fromTaskId,
    required this.toTaskId,
    required this.relationType,
    this.confidence = 0,
    this.source = '',
    this.explanation = '',
  });

  /// Source task id.
  final String fromTaskId;

  /// Target task id.
  final String toTaskId;

  /// Relationship type.
  final String relationType;

  /// Edge confidence.
  final double confidence;

  /// Edge source.
  final String source;

  /// Edge explanation.
  final String explanation;
}

/// CommitmentWeaveProjection stores commitment density rows and items.
class CommitmentWeaveProjection {
  /// Creates a commitment weave projection.
  const CommitmentWeaveProjection({
    this.generatedAt,
    this.columns = const <CommitmentWeaveColumn>[],
    this.rows = const <CommitmentWeaveRow>[],
    this.items = const <CommitmentWeaveItem>[],
  });

  /// Projection generation timestamp.
  final DateTime? generatedAt;

  /// Time columns.
  final List<CommitmentWeaveColumn> columns;

  /// People, project, or domain rows.
  final List<CommitmentWeaveRow> rows;

  /// Task placements.
  final List<CommitmentWeaveItem> items;
}

/// CommitmentWeaveColumn stores one time column.
class CommitmentWeaveColumn {
  /// Creates a commitment weave column.
  const CommitmentWeaveColumn({
    required this.id,
    required this.title,
    this.subtitle = '',
  });

  /// Stable column id.
  final String id;

  /// Display title.
  final String title;

  /// Secondary display text.
  final String subtitle;
}

/// CommitmentWeaveRow stores one commitment row.
class CommitmentWeaveRow {
  /// Creates a commitment weave row.
  const CommitmentWeaveRow({
    required this.id,
    required this.title,
    required this.group,
    this.density = 0,
    this.conflict = false,
  });

  /// Stable row id.
  final String id;

  /// Display title.
  final String title;

  /// Row group label.
  final String group;

  /// Normalized density.
  final double density;

  /// Whether row contains conflicts.
  final bool conflict;
}

/// CommitmentWeaveItem stores one task placement in the weave.
class CommitmentWeaveItem {
  /// Creates a commitment weave item.
  const CommitmentWeaveItem({
    required this.taskId,
    required this.title,
    required this.rowId,
    required this.columnId,
    required this.status,
    required this.priority,
    this.density = 0,
    this.conflict = false,
    this.explanation = '',
  });

  /// Referenced task id.
  final String taskId;

  /// Display title.
  final String title;

  /// Row id placement.
  final String rowId;

  /// Column id placement.
  final String columnId;

  /// Backend task status.
  final String status;

  /// Backend task priority.
  final String priority;

  /// Normalized item density.
  final double density;

  /// Whether the item marks a conflict.
  final bool conflict;

  /// Placement explanation.
  final String explanation;
}

/// TaskReviewReport summarizes task steward review output.
class TaskReviewReport {
  /// Creates a task review report.
  const TaskReviewReport({
    this.actor = '',
    this.generatedAt,
    this.reviewedTasks = 0,
    this.reviewedLists = 0,
    this.summary = '',
    this.recommendations = const <TaskReviewRecommendation>[],
  });

  /// Review actor.
  final String actor;

  /// Report timestamp.
  final DateTime? generatedAt;

  /// Number of reviewed tasks.
  final int reviewedTasks;

  /// Number of reviewed lists.
  final int reviewedLists;

  /// Human-readable summary.
  final String summary;

  /// Maintenance recommendations.
  final List<TaskReviewRecommendation> recommendations;
}

/// TaskReviewRecommendation describes one task steward recommendation.
class TaskReviewRecommendation {
  /// Creates a task review recommendation.
  const TaskReviewRecommendation({
    required this.kind,
    required this.severity,
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.message,
    required this.proposedAction,
    this.sourceId = '',
    this.sourceLabel = '',
  });

  /// Recommendation kind.
  final String kind;

  /// Severity label.
  final String severity;

  /// Target object type.
  final String targetType;

  /// Target object id.
  final String targetId;

  /// Recommendation title.
  final String title;

  /// Recommendation message.
  final String message;

  /// Proposed action.
  final String proposedAction;

  /// Runtime profile server id that returned this recommendation.
  final String sourceId;

  /// Runtime profile server label that returned this recommendation.
  final String sourceLabel;

  /// Returns a copy with changed runtime source metadata.
  TaskReviewRecommendation copyWith({String? sourceId, String? sourceLabel}) {
    return TaskReviewRecommendation(
      kind: kind,
      severity: severity,
      targetType: targetType,
      targetId: targetId,
      title: title,
      message: message,
      proposedAction: proposedAction,
      sourceId: sourceId ?? this.sourceId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
    );
  }
}

/// ProjectWorkspace represents the focused workspace state.
class ProjectWorkspace {
  /// Creates a focused project workspace.
  const ProjectWorkspace({
    required this.title,
    required this.subtitle,
    required this.tasks,
    required this.sources,
    required this.memoryRecords,
  });

  /// Workspace title.
  final String title;

  /// Workspace subtitle.
  final String subtitle;

  /// Project tasks and plan steps.
  final List<WorkspaceTask> tasks;

  /// Source list.
  final List<SourceItem> sources;

  /// Contextual memory records.
  final List<MemoryRecord> memoryRecords;
}

/// EndpointStatus summarizes one service connection.
class EndpointStatus {
  /// Creates a service status row.
  const EndpointStatus({
    required this.name,
    required this.url,
    required this.state,
    this.message = '',
  });

  /// Service name.
  final String name;

  /// Service URL.
  final String url;

  /// Availability state.
  final ConnectionStateKind state;

  /// Optional status detail.
  final String message;
}

/// Converts a decoded model value to a display string.
String _modelString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

/// Converts a decoded model value to an optional timestamp.
DateTime? _modelDateTime(dynamic value) {
  final text = _modelString(value);
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}
