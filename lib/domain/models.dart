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

/// ChatSession represents one ADK session in the UI.
class ChatSession {
  /// Creates a chat session summary.
  const ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  /// Session identifier.
  final String id;

  /// Human-readable title.
  final String title;

  /// Last update timestamp.
  final DateTime updatedAt;
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
  });

  /// ADK function-call id to echo in the response.
  final String callId;

  /// Human-readable prompt text.
  final String hint;

  /// Available confirmation options.
  final List<ConfirmationOption> options;
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
    this.active = false,
  });

  /// Task id.
  final String id;

  /// Task title.
  final String title;

  /// Secondary status text.
  final String detail;

  /// Whether the task is complete.
  final bool done;

  /// Whether the task is currently active.
  final bool active;
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
