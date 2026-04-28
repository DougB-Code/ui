/// Owns Aurora UI state and coordinates service clients.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../clients/assistant_client.dart';
import '../clients/mcp_client.dart';
import '../domain/models.dart';
import 'app_config.dart';
import 'seed_data.dart';

/// AuroraAppController stores app state and service orchestration.
class AuroraAppController extends ChangeNotifier {
  /// Creates the app controller and its service clients.
  AuroraAppController({
    required this.config,
    AssistantClient? assistantClient,
    MemoryClient? memoryClient,
    TasksClient? tasksClient,
  }) : assistantClient =
           assistantClient ??
           AssistantClient(
             baseUrl: config.agentApiBaseUrl,
             appName: config.agentAppName,
             userId: config.agentUserId,
           ),
       memoryClient =
           memoryClient ??
           MemoryClient(rpc: McpJsonRpcClient(endpoint: config.memoryMcpUrl)),
       tasksClient =
           tasksClient ??
           TasksClient(rpc: McpJsonRpcClient(endpoint: config.tasksMcpUrl));

  /// Runtime service configuration.
  final AppConfig config;

  /// ADK assistant client.
  final AssistantClient assistantClient;

  /// Memory MCP client.
  final MemoryClient memoryClient;

  /// Task MCP client.
  final TasksClient tasksClient;

  /// All known chat sessions.
  List<ChatSession> sessions = seededSessions();

  /// Currently selected chat session id.
  String? selectedSessionId = 'seed-home';

  /// Current chat messages.
  List<ChatMessage> messages = seededHomeMessages();

  /// Home execution steps.
  List<WorkspaceTask> executionSteps = seededExecutionSteps();

  /// Focused project workspace state.
  ProjectWorkspace workspace = seededWorkspace();

  /// Endpoint statuses displayed in settings.
  List<EndpointStatus> endpointStatuses = const <EndpointStatus>[];

  /// Pending ADK confirmation request.
  ConfirmationRequest? pendingConfirmation;

  /// Whether a message is currently streaming.
  bool sending = false;

  /// Last high-level error for status display.
  String statusMessage = 'Seeded concept data loaded';

  /// Loads initial service data while preserving seeded fallbacks.
  Future<void> initialize() async {
    endpointStatuses = <EndpointStatus>[
      EndpointStatus(
        name: 'Agent API',
        url: config.agentApiBaseUrl,
        state: ConnectionStateKind.unknown,
      ),
      EndpointStatus(
        name: 'Memory MCP',
        url: config.memoryMcpUrl,
        state: ConnectionStateKind.unknown,
      ),
      EndpointStatus(
        name: 'Tasks MCP',
        url: config.tasksMcpUrl,
        state: ConnectionStateKind.unknown,
      ),
    ];
    notifyListeners();
    await Future.wait(<Future<void>>[
      _loadSessions(),
      _loadMemory(),
      _loadTasks(),
    ]);
  }

  /// Selects the seeded home chat when no live session is active.
  void openHome() {
    if (selectedSessionId == null || selectedSessionId!.startsWith('seed-')) {
      selectedSessionId = 'seed-home';
      messages = seededHomeMessages();
      notifyListeners();
    }
  }

  /// Selects the seeded project workspace chat when no live session is active.
  void openWorkspace() {
    if (selectedSessionId == null || selectedSessionId!.startsWith('seed-')) {
      selectedSessionId = 'seed-saas-market';
      messages = seededWorkspaceMessages();
      notifyListeners();
    }
  }

  /// Selects a chat session and loads its events when connected.
  Future<void> selectSession(String sessionId) async {
    selectedSessionId = sessionId;
    if (sessionId.startsWith('seed-')) {
      messages = sessionId == 'seed-home'
          ? seededHomeMessages()
          : seededWorkspaceMessages();
      notifyListeners();
      return;
    }
    try {
      final events = await assistantClient.loadSessionEvents(sessionId);
      messages = events
          .map(_messageFromEvent)
          .whereType<ChatMessage>()
          .toList();
      _setEndpoint(
        'Agent API',
        ConnectionStateKind.connected,
        'Loaded session',
      );
    } catch (error) {
      _setEndpoint(
        'Agent API',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
    notifyListeners();
  }

  /// Creates a new chat session.
  Future<void> createChat() async {
    try {
      final session = await assistantClient.createSession();
      sessions = <ChatSession>[
        session,
        ...sessions.where((item) => !item.id.startsWith('seed-')),
      ];
      selectedSessionId = session.id;
      messages = const <ChatMessage>[];
      _setEndpoint('Agent API', ConnectionStateKind.connected, 'Created chat');
    } catch (error) {
      _setEndpoint(
        'Agent API',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
    notifyListeners();
  }

  /// Sends a user-authored chat message.
  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) {
      return;
    }
    await _ensureLiveSession();
    final sessionId = selectedSessionId;
    if (sessionId == null || sessionId.startsWith('seed-')) {
      messages = <ChatMessage>[
        ...messages,
        ChatMessage(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.user,
          author: 'You',
          text: trimmed,
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: 'offline-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.tool,
          author: 'Runtime',
          text:
              'Connect the local Agent API to send live messages. Seeded workspace data remains available.',
          createdAt: DateTime.now(),
        ),
      ];
      notifyListeners();
      return;
    }
    messages = <ChatMessage>[
      ...messages,
      ChatMessage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.user,
        author: 'You',
        text: trimmed,
        createdAt: DateTime.now(),
      ),
    ];
    sending = true;
    notifyListeners();
    await _streamRun(sessionId: sessionId, text: trimmed);
  }

  /// Responds to a pending ADK confirmation request.
  Future<void> answerConfirmation(ConfirmationOption option) async {
    final confirmation = pendingConfirmation;
    final sessionId = selectedSessionId;
    if (confirmation == null || sessionId == null) {
      return;
    }
    pendingConfirmation = null;
    notifyListeners();
    await _streamRun(
      sessionId: sessionId,
      reply: ConfirmationReply(
        callId: confirmation.callId,
        confirmed: option.action != 'deny',
        action: option.action,
      ),
    );
  }

  /// Creates a task after local UI confirmation.
  Future<void> createTaskFromUi(String title) async {
    try {
      await tasksClient.createTask(title: title);
      await _loadTasks();
      _setEndpoint('Tasks MCP', ConnectionStateKind.connected, 'Task created');
    } catch (error) {
      _setEndpoint(
        'Tasks MCP',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
    notifyListeners();
  }

  /// Completes a task after local UI confirmation.
  Future<void> completeTaskFromUi(String taskId) async {
    try {
      await tasksClient.completeTask(taskId);
      await _loadTasks();
      _setEndpoint(
        'Tasks MCP',
        ConnectionStateKind.connected,
        'Task completed',
      );
    } catch (error) {
      _setEndpoint(
        'Tasks MCP',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> _loadSessions() async {
    try {
      final loaded = await assistantClient.listSessions();
      if (loaded.isNotEmpty) {
        sessions = loaded;
        selectedSessionId = loaded.first.id;
        await selectSession(loaded.first.id);
      }
      _setEndpoint('Agent API', ConnectionStateKind.connected, 'Connected');
    } catch (error) {
      _setEndpoint(
        'Agent API',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
  }

  Future<void> _loadMemory() async {
    try {
      final records = await memoryClient.searchCatalog();
      if (records.isNotEmpty) {
        workspace = ProjectWorkspace(
          title: workspace.title,
          subtitle: workspace.subtitle,
          tasks: workspace.tasks,
          sources: records.map((record) {
            return SourceItem(
              id: record.id,
              title: record.title,
              detail: '${record.kind} • ${record.sourceLabel}',
            );
          }).toList(),
          memoryRecords: records,
        );
      }
      _setEndpoint('Memory MCP', ConnectionStateKind.connected, 'Connected');
    } catch (error) {
      _setEndpoint(
        'Memory MCP',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await tasksClient.listTasks();
      if (tasks.isNotEmpty) {
        workspace = ProjectWorkspace(
          title: workspace.title,
          subtitle: workspace.subtitle,
          tasks: tasks,
          sources: workspace.sources,
          memoryRecords: workspace.memoryRecords,
        );
      }
      _setEndpoint('Tasks MCP', ConnectionStateKind.connected, 'Connected');
    } catch (error) {
      _setEndpoint(
        'Tasks MCP',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> _ensureLiveSession() async {
    if (selectedSessionId != null && !selectedSessionId!.startsWith('seed-')) {
      return;
    }
    await createChat();
  }

  Future<void> _streamRun({
    required String sessionId,
    String text = '',
    ConfirmationReply? reply,
  }) async {
    try {
      await for (final event in assistantClient.sendMessage(
        sessionId: sessionId,
        text: text,
        confirmation: reply,
      )) {
        _applyEvent(event);
      }
      _setEndpoint('Agent API', ConnectionStateKind.connected, 'Run complete');
    } catch (error) {
      _setEndpoint(
        'Agent API',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void _applyEvent(AssistantEvent event) {
    if (event.confirmation != null) {
      pendingConfirmation = event.confirmation;
    }
    final message = _messageFromEvent(event);
    if (message != null) {
      if (message.isPartial && messages.isNotEmpty && messages.last.isPartial) {
        messages = <ChatMessage>[
          ...messages.take(messages.length - 1),
          messages.last.copyWith(text: messages.last.text + message.text),
        ];
      } else {
        messages = <ChatMessage>[...messages, message];
      }
    }
    notifyListeners();
  }

  ChatMessage? _messageFromEvent(AssistantEvent event) {
    if (event.errorMessage.isNotEmpty) {
      return ChatMessage(
        id: event.id,
        role: ChatRole.tool,
        author: 'Runtime',
        text: event.errorMessage,
        createdAt: DateTime.now(),
      );
    }
    if (event.toolActivity != null) {
      return ChatMessage(
        id: event.id,
        role: ChatRole.tool,
        author: 'Tool',
        text: event.toolActivity!.summary,
        createdAt: DateTime.now(),
        toolActivity: event.toolActivity,
      );
    }
    if (event.text.trim().isEmpty) {
      return null;
    }
    final role = event.author == 'user' ? ChatRole.user : ChatRole.assistant;
    return ChatMessage(
      id: event.id,
      role: role,
      author: role == ChatRole.user ? 'You' : 'Aurora',
      text: event.text,
      createdAt: DateTime.now(),
      isPartial: event.partial,
    );
  }

  void _setEndpoint(String name, ConnectionStateKind state, String message) {
    endpointStatuses = endpointStatuses.map((status) {
      if (status.name != name) {
        return status;
      }
      return EndpointStatus(
        name: status.name,
        url: status.url,
        state: state,
        message: message,
      );
    }).toList();
    statusMessage = message;
  }
}
