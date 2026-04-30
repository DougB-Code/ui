/// Owns Aurora UI state and coordinates service clients.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../clients/assistant_client.dart';
import '../clients/mcp_client.dart';
import '../domain/models.dart';
import 'app_config.dart';
import 'app_logger.dart';
import 'config_files.dart';
import 'local_services.dart';
import 'runtime_profile.dart';

/// RuntimeProfileFileEntry describes one editable profile JSON file.
class RuntimeProfileFileEntry {
  /// Creates a runtime profile file entry.
  const RuntimeProfileFileEntry({
    required this.path,
    required this.id,
    required this.label,
    required this.active,
  });

  /// Profile JSON path.
  final String path;

  /// Profile id parsed from JSON or path.
  final String id;

  /// Display label parsed from JSON or path.
  final String label;

  /// Whether the app is currently using this profile.
  final bool active;
}

/// AuroraAppController stores app state and service orchestration.
class AuroraAppController extends ChangeNotifier {
  /// Creates the app controller and its service clients.
  AuroraAppController({
    required this.config,
    AssistantClient? assistantClient,
    MemoryClient? memoryClient,
    TasksClient? tasksClient,
    LocalServiceSupervisor? localServices,
    ConfigFileStore? configFiles,
    AppLogger? logger,
  }) : _assistantClientInjected = assistantClient != null,
       _memoryClientInjected = memoryClient != null,
       _tasksClientInjected = tasksClient != null,
       logger = logger ?? AppLogger(directory: config.serviceLogDirectory),
       assistantClient =
           assistantClient ??
           AssistantClient(
             baseUrl: config.agentApiBaseUrl,
             appName: config.agentAppName,
             userId: config.agentUserId,
             logger: logger ?? AppLogger(directory: config.serviceLogDirectory),
           ),
       memoryClient =
           memoryClient ??
           MemoryClient(
             rpc: McpJsonRpcClient(
               endpoint: config.memoryMcpUrl,
               logger:
                   logger ?? AppLogger(directory: config.serviceLogDirectory),
             ),
           ),
       tasksClient =
           tasksClient ??
           TasksClient(
             rpc: McpJsonRpcClient(
               endpoint: config.tasksMcpUrl,
               logger:
                   logger ?? AppLogger(directory: config.serviceLogDirectory),
             ),
           ),
       localServices = localServices ?? LocalServiceSupervisor(config: config),
       configFiles = configFiles ?? const ConfigFileStore();

  /// Runtime service configuration.
  final AppConfig config;

  /// File logger for UI and client diagnostics.
  final AppLogger logger;

  /// ADK assistant client.
  AssistantClient assistantClient;

  /// Memory MCP client.
  MemoryClient memoryClient;

  /// Task MCP client.
  TasksClient tasksClient;

  /// Local process supervisor for the pilot service stack.
  final LocalServiceSupervisor localServices;

  /// File store for editable model and agent configurations.
  final ConfigFileStore configFiles;

  final bool _assistantClientInjected;
  final bool _memoryClientInjected;
  final bool _tasksClientInjected;

  /// Active runtime profile for harness configs and MCP topology.
  RuntimeProfile? runtimeProfile;

  /// Filesystem path for the loaded runtime profile.
  String runtimeProfilePath = '';

  /// Profile files available in the app config directory.
  List<String> availableProfilePaths = const <String>[];

  /// Runtime profile files available in the app config directory.
  List<RuntimeProfileFileEntry> availableProfiles =
      const <RuntimeProfileFileEntry>[];

  /// Model config files available in the app config directory.
  List<ConfigFileEntry> availableModelConfigs = const <ConfigFileEntry>[];

  /// Agent config files available in the app config directory.
  List<ConfigFileEntry> availableAgentConfigs = const <ConfigFileEntry>[];

  /// Tool config files available in the app config directory.
  List<ConfigFileEntry> availableToolConfigs = const <ConfigFileEntry>[];

  Future<void>? _initialization;
  bool _initialized = false;

  /// All known chat sessions.
  List<ChatSession> sessions = const <ChatSession>[];

  /// Currently selected chat session id.
  String? selectedSessionId;

  /// Current chat messages.
  List<ChatMessage> messages = const <ChatMessage>[];

  /// Home execution steps.
  List<WorkspaceTask> executionSteps = const <WorkspaceTask>[];

  /// Focused project workspace state.
  ProjectWorkspace workspace = const ProjectWorkspace(
    title: 'Workspace',
    subtitle: 'Live connected workspace',
    tasks: <WorkspaceTask>[],
    sources: <SourceItem>[],
    memoryRecords: <MemoryRecord>[],
  );

  /// Active task queue filters.
  TaskFilterState taskFilters = const TaskFilterState();

  /// Named task lists loaded from task MCP servers.
  List<WorkspaceTaskList> taskLists = const <WorkspaceTaskList>[];

  /// Last task steward review report.
  TaskReviewReport? taskReviewReport;

  /// Currently selected task id.
  String? selectedTaskId;

  /// Currently selected named-list id.
  String? selectedTaskListId;

  /// Currently selected named-list item id.
  String? selectedTaskListItemId;

  /// Current task selection kind.
  String taskSelectionKind = 'task';

  /// Whether a task operation is currently running.
  bool tasksBusy = false;

  /// Last task-specific operation message.
  String tasksMessage = 'Tasks are ready';

  /// Active memory retrieval and stewardship filters.
  MemoryFilterState memoryFilters = const MemoryFilterState();

  /// Currently selected catalog record id.
  String? selectedMemoryId;

  /// Last loaded compiled entity page or timeline.
  CompiledMemoryPage? selectedMemoryPage;

  /// Whether a memory operation is currently running.
  bool memoryBusy = false;

  /// Last memory-specific operation message.
  String memoryMessage = 'Memory is ready for review';

  /// Endpoint statuses displayed in settings.
  List<EndpointStatus> endpointStatuses = const <EndpointStatus>[];

  /// Local service process statuses displayed in settings.
  List<ServiceProcessStatus> localProcessStatuses =
      const <ServiceProcessStatus>[];

  /// Pending ADK confirmation request.
  ConfirmationRequest? pendingConfirmation;

  /// Whether a message is currently streaming.
  bool sending = false;

  /// Last high-level error for status display.
  String statusMessage = 'Preparing managed runtime';

  /// Loads initial service data from connected services.
  Future<void> initialize() async {
    _initialization ??= _initialize();
    return _initialization!;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await initialize();
  }

  Future<void> _initialize() async {
    await _log('initialize start');
    localProcessStatuses = const <ServiceProcessStatus>[];
    try {
      final loader = RuntimeProfileLoader(config);
      final profileFile = await loader.resolveProfileFile();
      await _log('resolved runtime profile ${profileFile.path}');
      runtimeProfilePath = profileFile.path;
      runtimeProfile = await loader.loadFile(profileFile);
      runtimeProfile = await _migrateDefaultProfileConfigs(runtimeProfile!);
      await _refreshConfigCollections();
      _configureClientsForRuntimeProfile(runtimeProfile!);
      await _log('loaded runtime profile ${runtimeProfile!.id}');
    } catch (error) {
      await _log('runtime profile load failed: $error');
      runtimeProfile = null;
      runtimeProfilePath = config.runtimeProfilePath;
      endpointStatuses = <EndpointStatus>[
        EndpointStatus(
          name: 'Runtime Profile',
          url: config.runtimeProfilePath,
          state: ConnectionStateKind.disconnected,
          message: error.toString(),
        ),
      ];
      localProcessStatuses = const <ServiceProcessStatus>[];
      statusMessage = 'Runtime profile failed to load: $error';
      _initialized = true;
      notifyListeners();
      return;
    }
    endpointStatuses = <EndpointStatus>[
      EndpointStatus(
        name: 'Agent API',
        url: runtimeProfile!.harness.apiBaseUrl,
        state: ConnectionStateKind.unknown,
      ),
      for (final server in runtimeProfile!.mcpServers.where(
        (server) => server.enabled,
      ))
        EndpointStatus(
          name: server.label,
          url: server.endpoint,
          state: ConnectionStateKind.unknown,
        ),
    ];
    notifyListeners();
    try {
      await _log('starting required local services');
      localProcessStatuses = await localServices.startRequiredServices(
        runtimeProfile!,
      );
      for (final status in localProcessStatuses) {
        await _log(
          'service status ${status.name} ${status.state.name}: ${status.message}',
        );
      }
    } catch (error) {
      await _log('local service startup failed: $error');
      localProcessStatuses = <ServiceProcessStatus>[
        ServiceProcessStatus(
          name: 'Local Services',
          url: config.workspaceRoot,
          state: ConnectionStateKind.disconnected,
          message: error.toString(),
        ),
      ];
    }
    notifyListeners();
    await _log('loading sessions, memory, and tasks');
    await Future.wait(<Future<void>>[
      _loadSessions(),
      _loadMemory(),
      _loadTasks(),
    ]);
    _initialized = true;
    await _log('initialize complete');
  }

  /// Lists editable runtime profiles from the app config directory.
  Future<List<String>> listRuntimeProfilePaths() async {
    final directory = Directory(runtimeProfilesDirectoryPath());
    if (!await directory.exists()) {
      return const <String>[];
    }
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));
    return files.map((file) => file.path).toList();
  }

  /// Lists editable runtime profiles with labels parsed from profile JSON.
  Future<List<RuntimeProfileFileEntry>> listRuntimeProfileFiles() async {
    final paths = await listRuntimeProfilePaths();
    final entries = <RuntimeProfileFileEntry>[];
    for (final path in paths) {
      entries.add(await _profileEntryForPath(path));
    }
    if (runtimeProfilePath.isNotEmpty &&
        !entries.any((entry) => entry.path == runtimeProfilePath)) {
      entries.insert(0, await _profileEntryForPath(runtimeProfilePath));
    }
    return entries;
  }

  /// Reloads profile, model, and agent file collection metadata.
  Future<void> _refreshConfigCollections() async {
    final profile = runtimeProfile;
    availableProfilePaths = await listRuntimeProfilePaths();
    availableProfiles = await listRuntimeProfileFiles();
    availableModelConfigs = await configFiles.list(
      kind: ConfigFileKind.model,
      assignedPath: profile?.harness.modelConfigPath ?? '',
    );
    availableAgentConfigs = await configFiles.list(
      kind: ConfigFileKind.agent,
      assignedPath: profile?.harness.agentConfigPath ?? '',
    );
    availableToolConfigs = await configFiles.list(
      kind: ConfigFileKind.tool,
      assignedPath: profile?.harness.toolConfigPath ?? '',
    );
  }

  /// Refreshes file-backed profile, model, and agent collections.
  Future<void> refreshConfigurationCollections() async {
    await _refreshConfigCollections();
    notifyListeners();
  }

  /// Saves the active runtime profile JSON and reconnects owned clients.
  Future<void> saveRuntimeProfile(RuntimeProfile profile) async {
    final path = runtimeProfilePath.trim().isEmpty
        ? RuntimeProfileLoader(config).defaultRuntimeProfilePath()
        : runtimeProfilePath;
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(encodeRuntimeProfileJson(profile));
    runtimeProfilePath = path;
    runtimeProfile = profile;
    await _refreshConfigCollections();
    _configureClientsForRuntimeProfile(profile);
    _refreshEndpointSkeleton(profile);
    statusMessage = 'Runtime profile saved';
    notifyListeners();
  }

  /// Loads a different profile from disk and applies its runtime bindings.
  Future<void> loadRuntimeProfileFromPath(String path) async {
    final file = File(path);
    final profile = await RuntimeProfileLoader(config).loadFile(file);
    runtimeProfilePath = file.path;
    runtimeProfile = profile;
    await _refreshConfigCollections();
    _configureClientsForRuntimeProfile(profile);
    _refreshEndpointSkeleton(profile);
    statusMessage = 'Runtime profile loaded';
    notifyListeners();
  }

  /// Reads a text configuration file referenced by the active profile.
  Future<String> readConfigurationFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Configuration file does not exist', path);
    }
    return file.readAsString();
  }

  /// Saves a text configuration file referenced by the active profile.
  Future<void> saveConfigurationFile(String path, String content) async {
    if (path.trim().isEmpty) {
      throw const FileSystemException('Configuration path is empty');
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    statusMessage = 'Saved $path';
    notifyListeners();
  }

  /// Creates a new runtime profile file copied from the active profile.
  Future<void> createRuntimeProfileFile() async {
    final profile = _activeRuntimeProfile();
    final directory = Directory(runtimeProfilesDirectoryPath());
    await directory.create(recursive: true);
    final nextPath = await _uniqueRuntimeProfilePath(
      directory.path,
      profile.id,
    );
    final nextId = _profileIdFromPath(nextPath);
    final next = profile.copyWith(id: nextId, label: 'New Profile');
    await File(nextPath).writeAsString(encodeRuntimeProfileJson(next));
    await loadRuntimeProfileFromPath(nextPath);
  }

  /// Duplicates the active runtime profile file and loads the duplicate.
  Future<void> duplicateRuntimeProfileFile() async {
    final profile = _activeRuntimeProfile();
    final directory = Directory(runtimeProfilesDirectoryPath());
    await directory.create(recursive: true);
    final nextPath = await _uniqueRuntimeProfilePath(
      directory.path,
      profile.id,
    );
    final nextId = _profileIdFromPath(nextPath);
    final next = profile.copyWith(id: nextId, label: '${profile.label} Copy');
    await File(nextPath).writeAsString(encodeRuntimeProfileJson(next));
    await loadRuntimeProfileFromPath(nextPath);
  }

  /// Deletes the active runtime profile file and loads another available file.
  Future<void> deleteActiveRuntimeProfileFile() async {
    final paths = await listRuntimeProfilePaths();
    if (paths.length <= 1) {
      throw const FileSystemException('Cannot delete the only runtime profile');
    }
    final current = runtimeProfilePath;
    final nextPath = paths.firstWhere((path) => path != current);
    await File(current).delete();
    await loadRuntimeProfileFromPath(nextPath);
  }

  /// Creates a new model or agent config file.
  Future<String> createConfigFile(ConfigFileKind kind) async {
    final path = await configFiles.create(kind);
    await _refreshConfigCollections();
    notifyListeners();
    return path;
  }

  /// Duplicates a model or agent config file.
  Future<String> duplicateConfigFile(ConfigFileEntry entry) async {
    final path = await configFiles.duplicate(entry.path, entry.kind);
    await _refreshConfigCollections();
    notifyListeners();
    return path;
  }

  /// Deletes a model or agent config file when it is not actively assigned.
  Future<void> deleteConfigFile(ConfigFileEntry entry) async {
    final profile = _activeRuntimeProfile();
    if (entry.path == profile.harness.modelConfigPath ||
        entry.path == profile.harness.agentConfigPath ||
        entry.path == profile.harness.toolConfigPath) {
      throw FileSystemException(
        'Cannot delete an assigned config file',
        entry.path,
      );
    }
    await configFiles.delete(entry.path);
    await _refreshConfigCollections();
    notifyListeners();
  }

  /// Assigns a model or agent config file to the active profile.
  Future<void> assignConfigFile(ConfigFileEntry entry) async {
    await _assignConfigFile(entry.kind, entry.path);
  }

  /// Renames a model or agent config file and updates active assignments.
  Future<String> renameConfigFile(ConfigFileEntry entry, String name) async {
    final nextPath = await configFiles.rename(entry, name);
    final profile = _activeRuntimeProfile();
    var harness = profile.harness;
    if (profile.harness.modelConfigPath == entry.path) {
      harness = harness.copyWith(modelConfigPath: nextPath);
    }
    if (profile.harness.agentConfigPath == entry.path) {
      harness = harness.copyWith(agentConfigPath: nextPath);
    }
    if (profile.harness.toolConfigPath == entry.path) {
      harness = harness.copyWith(toolConfigPath: nextPath);
    }
    runtimeProfile = profile.copyWith(harness: harness);
    await saveRuntimeProfile(runtimeProfile!);
    return nextPath;
  }

  /// Assigns a config path to the active profile for a config kind.
  Future<void> _assignConfigFile(ConfigFileKind kind, String path) async {
    final profile = _activeRuntimeProfile();
    final harness = switch (kind) {
      ConfigFileKind.model => profile.harness.copyWith(modelConfigPath: path),
      ConfigFileKind.agent => profile.harness.copyWith(agentConfigPath: path),
      ConfigFileKind.tool => profile.harness.copyWith(toolConfigPath: path),
    };
    await saveRuntimeProfile(profile.copyWith(harness: harness));
  }

  Future<RuntimeProfile> _migrateDefaultProfileConfigs(
    RuntimeProfile profile,
  ) async {
    if (config.runtimeProfilePath.trim().isNotEmpty) {
      return profile;
    }
    final harness = profile.harness;
    final modelPath = await _copyConfigIntoAppDirectory(
      sourcePath: harness.modelConfigPath,
      targetDirectory: modelConfigsDirectoryPath(),
      targetName: '${profile.id}-model.yaml',
    );
    final agentPath = await _copyConfigIntoAppDirectory(
      sourcePath: harness.agentConfigPath,
      targetDirectory: agentConfigsDirectoryPath(),
      targetName: '${profile.id}-agent.yaml',
    );
    final toolPath = await _copyConfigIntoAppDirectory(
      sourcePath: harness.toolConfigPath,
      targetDirectory: toolConfigsDirectoryPath(),
      targetName: '${profile.id}-tool.yaml',
    );
    final next = profile.copyWith(
      harness: harness.copyWith(
        modelConfigPath: modelPath ?? harness.modelConfigPath,
        agentConfigPath: agentPath ?? harness.agentConfigPath,
        toolConfigPath: toolPath ?? harness.toolConfigPath,
      ),
    );
    if (next.harness.modelConfigPath != harness.modelConfigPath ||
        next.harness.agentConfigPath != harness.agentConfigPath ||
        next.harness.toolConfigPath != harness.toolConfigPath) {
      final file = File(runtimeProfilePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(encodeRuntimeProfileJson(next));
    }
    return next;
  }

  /// Releases HTTP clients and stops locally started service processes.
  Future<void> close() async {
    assistantClient.close();
    memoryClient.close();
    tasksClient.close();
    await localServices.close();
  }

  /// Rebuilds owned service clients from the active runtime profile.
  void _configureClientsForRuntimeProfile(RuntimeProfile profile) {
    if (!_assistantClientInjected) {
      assistantClient.close();
      assistantClient = AssistantClient(
        baseUrl: profile.harness.apiBaseUrl,
        appName: profile.harness.appName,
        userId: profile.harness.userId,
        logger: logger,
      );
    }
    if (!_memoryClientInjected && profile.memoryServers.isNotEmpty) {
      memoryClient.close();
      memoryClient = MemoryClient(
        rpc: McpJsonRpcClient(
          endpoint: profile.memoryServers.first.endpoint,
          logger: logger,
        ),
      );
    }
    if (!_tasksClientInjected && profile.taskServers.isNotEmpty) {
      tasksClient.close();
      tasksClient = TasksClient(
        rpc: McpJsonRpcClient(
          endpoint: profile.taskServers.first.endpoint,
          logger: logger,
        ),
      );
    }
  }

  /// Selects the home workspace without fabricating local data.
  void openHome() {
    notifyListeners();
  }

  /// Selects the workflow workspace without fabricating local data.
  void openWorkspace() {
    notifyListeners();
  }

  /// Selects a chat session and loads its events when connected.
  Future<void> selectSession(String sessionId) async {
    selectedSessionId = sessionId;
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
  Future<bool> createChat() async {
    await _ensureInitialized();
    await _log('create chat requested');
    if (runtimeProfile == null) {
      await _log('create chat blocked: runtime profile missing');
      _setEndpoint(
        'Runtime Profile',
        ConnectionStateKind.disconnected,
        statusMessage,
      );
      notifyListeners();
      return false;
    }
    try {
      final session = await assistantClient.createSession();
      sessions = <ChatSession>[session, ...sessions];
      selectedSessionId = session.id;
      messages = const <ChatMessage>[];
      _setEndpoint('Agent API', ConnectionStateKind.connected, 'Created chat');
      await _log('created chat session ${session.id}');
      notifyListeners();
      return true;
    } catch (error) {
      await _log('create chat failed: $error');
      _setEndpoint(
        'Agent API',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
    notifyListeners();
    return false;
  }

  /// Sends a user-authored chat message.
  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) {
      await _log(
        'send user message ignored empty=${trimmed.isEmpty} sending=$sending',
      );
      return;
    }
    await _log('send user message requested length=${trimmed.length}');
    statusMessage = 'Preparing managed chat runtime';
    notifyListeners();
    final ready = await _ensureLiveSession();
    final sessionId = selectedSessionId;
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
    if (!ready || sessionId == null) {
      await _log('send user message blocked: no live session');
      messages = <ChatMessage>[
        ...messages,
        ChatMessage(
          id: 'runtime-${DateTime.now().microsecondsSinceEpoch}',
          role: ChatRole.tool,
          author: 'Runtime',
          text: _agentUnavailableMessage(),
          createdAt: DateTime.now(),
        ),
      ];
      sending = false;
      notifyListeners();
      return;
    }
    sending = true;
    notifyListeners();
    await _log('streaming run for session $sessionId');
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
    await _sendConfirmationReply(
      sessionId: sessionId,
      confirmation: confirmation,
      option: option,
    );
  }

  /// Sends an ADK confirmation response back to the active assistant session.
  Future<void> _sendConfirmationReply({
    required String sessionId,
    required ConfirmationRequest confirmation,
    required ConfirmationOption option,
  }) async {
    await _streamRun(
      sessionId: sessionId,
      reply: ConfirmationReply(
        callId: confirmation.callId,
        confirmed: option.action != 'deny',
        action: option.action,
      ),
    );
  }

  /// Returns the best non-denial option for an auto-approved task operation.
  ConfirmationOption _approvalOption(ConfirmationRequest confirmation) {
    return confirmation.options.firstWhere(
      (option) => option.action != 'deny',
      orElse: () =>
          const ConfirmationOption(action: 'approve_once', label: 'Approve'),
    );
  }

  /// Reports whether a confirmation can be satisfied without user interaction.
  bool _shouldAutoApproveTaskConfirmation(ConfirmationRequest confirmation) {
    return _taskWriteToolNames.contains(confirmation.toolName);
  }

  /// Reports whether a task failure is the expected ADK approval handoff.
  bool _isAutoHandledTaskConfirmationFailure(ToolActivity activity) {
    return activity.status == 'failed' &&
        _taskWriteToolNames.contains(activity.name) &&
        activity.summary.toLowerCase().contains('requires confirmation');
  }

  /// Reports whether text is an approval-gated task response to repair.
  bool _isTaskApprovalText(String assistantText, String userText) {
    final answer = assistantText.toLowerCase();
    return answer.contains('approve') &&
        (answer.contains('create') || answer.contains('set')) &&
        (answer.contains('task') || answer.contains('reminder')) &&
        _looksLikeTaskRequest(userText);
  }

  /// Reports whether a user turn is likely asking for task management.
  bool _looksLikeTaskRequest(String userText) {
    final request = userText.toLowerCase();
    return request.contains('remind me') ||
        request.contains('reminder') ||
        request.contains('task') ||
        request.contains('todo') ||
        request.contains('to-do');
  }

  /// Creates a task after local UI confirmation.
  Future<void> createTaskFromUi(
    String title, {
    String description = '',
    String status = 'open',
    String priority = 'normal',
    DateTime? dueAt,
    DateTime? scheduledAt,
    List<String> topics = const <String>[],
    bool linkSelectedMemory = false,
  }) async {
    final server = _primaryTaskServer();
    if (server == null) {
      _setEndpoint('Tasks', ConnectionStateKind.disconnected, 'No task server');
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Creating task';
    notifyListeners();
    try {
      final memoryLinks = linkSelectedMemory
          ? _selectedMemoryLinkDrafts('originated_from')
          : const <TaskMemoryLinkDraft>[];
      await _withTasksClientForServer(server, (client) {
        return client.createTask(
          title: title,
          description: description,
          status: status,
          priority: priority,
          dueAt: dueAt,
          scheduledAt: scheduledAt,
          topics: topics,
          memoryLinks: memoryLinks,
        );
      });
      await _loadTasks();
      taskSelectionKind = 'task';
      _setEndpoint(server.label, ConnectionStateKind.connected, 'Task created');
      tasksMessage = 'Task created';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
    }
    notifyListeners();
  }

  /// Returns the selected task when the task inspector is active.
  WorkspaceTask? get selectedTask {
    if (taskSelectionKind != 'task') {
      return null;
    }
    if (selectedTaskId != null) {
      for (final task in workspace.tasks) {
        if (task.id == selectedTaskId) {
          return task;
        }
      }
    }
    if (workspace.tasks.isEmpty) {
      return null;
    }
    return workspace.tasks.first;
  }

  /// Returns the selected named task list when the list inspector is active.
  WorkspaceTaskList? get selectedTaskList {
    if (taskSelectionKind != 'list') {
      return null;
    }
    if (selectedTaskListId != null) {
      for (final list in taskLists) {
        if (list.id == selectedTaskListId) {
          return list;
        }
      }
    }
    if (taskLists.isEmpty) {
      return null;
    }
    return taskLists.first;
  }

  /// Returns the selected named-list item.
  TaskListItem? get selectedTaskListItem {
    final list = selectedTaskList;
    if (list == null || selectedTaskListItemId == null) {
      return null;
    }
    for (final item in list.items) {
      if (item.id == selectedTaskListItemId) {
        return item;
      }
    }
    return null;
  }

  /// Returns tasks after applying local queue filters.
  List<WorkspaceTask> get filteredTasks {
    return workspace.tasks.where((task) {
      final terminal = task.status == 'done' || task.status == 'canceled';
      if (!taskFilters.includeDone && terminal) {
        return false;
      }
      if (taskFilters.statuses.isNotEmpty &&
          !taskFilters.statuses.contains(task.status)) {
        return false;
      }
      if (taskFilters.priorities.isNotEmpty &&
          !taskFilters.priorities.contains(task.priority)) {
        return false;
      }
      if (taskFilters.topics.isNotEmpty &&
          !task.topics.any(taskFilters.topics.contains)) {
        return false;
      }
      if (taskFilters.overdueOnly && !task.overdue) {
        return false;
      }
      final search = taskFilters.search.trim();
      if (search.isNotEmpty &&
          !_textContains('${task.title} ${task.description}', search)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Returns all task topics in count order.
  List<String> get taskTopics {
    final counts = <String, int>{};
    for (final task in workspace.tasks) {
      for (final topic in task.topics) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    for (final list in taskLists) {
      for (final topic in list.topics) {
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((left, right) {
        final countCompare = right.value.compareTo(left.value);
        return countCompare == 0 ? left.key.compareTo(right.key) : countCompare;
      });
    return entries.map((entry) => entry.key).toList();
  }

  /// Applies local task filters and refreshes the task surface.
  Future<void> applyTaskFilters(TaskFilterState filters) async {
    taskFilters = filters;
    notifyListeners();
  }

  /// Refreshes task and list state from task MCP servers.
  Future<void> refreshTasksFromUi() async {
    await _loadTasks();
  }

  /// Selects a task for the inspector.
  void selectTask(String taskId) {
    taskSelectionKind = 'task';
    selectedTaskId = taskId;
    selectedTaskListItemId = null;
    notifyListeners();
  }

  /// Selects a named task list for the inspector.
  void selectTaskList(String listId, {String? itemId}) {
    taskSelectionKind = 'list';
    selectedTaskListId = listId;
    selectedTaskListItemId = itemId;
    selectedTaskId = null;
    notifyListeners();
  }

  /// Returns the selected memory record when it is still visible.
  MemoryRecord? get selectedMemory {
    for (final record in workspace.memoryRecords) {
      if (record.id == selectedMemoryId) {
        return record;
      }
    }
    if (workspace.memoryRecords.isEmpty) {
      return null;
    }
    return workspace.memoryRecords.first;
  }

  /// Returns records after applying local filters unsupported by retrieval.
  List<MemoryRecord> get filteredMemoryRecords {
    return workspace.memoryRecords.where((record) {
      if (memoryFilters.localStatus.isNotEmpty &&
          record.status != memoryFilters.localStatus) {
        return false;
      }
      if (memoryFilters.localTrustLevel.isNotEmpty &&
          record.trustLevel != memoryFilters.localTrustLevel) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Applies memory filters and reloads catalog records from the service.
  Future<void> applyMemoryFilters(MemoryFilterState filters) async {
    memoryFilters = filters;
    await _loadMemory();
  }

  /// Selects a memory and hydrates its source preview when possible.
  Future<void> selectMemory(String memoryId) async {
    selectedMemoryId = memoryId;
    selectedMemoryPage = null;
    notifyListeners();
    await hydrateSelectedMemorySource();
  }

  /// Loads raw source text for the selected memory without mutating source truth.
  Future<void> hydrateSelectedMemorySource() async {
    final memory = selectedMemory;
    if (memory == null || memory.rawContent.isNotEmpty) {
      return;
    }
    memoryBusy = true;
    memoryMessage = 'Loading source evidence';
    notifyListeners();
    try {
      final records = await memoryClient.searchSources(
        scope: memory.scope,
        text: memory.title,
        kinds: memoryFilters.kinds,
        allowedSensitivities: _sensitivitiesIncluding(memory.sensitivity),
        limit: memoryFilters.limit,
      );
      final hydrated = records.where((record) => record.id == memory.id);
      if (hydrated.isNotEmpty) {
        _replaceMemoryRecord(hydrated.first);
        memoryMessage = 'Source evidence loaded';
      } else {
        memoryMessage = 'Source evidence was not returned by search';
      }
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.connected,
        memoryMessage,
      );
    } catch (error) {
      memoryMessage = error.toString();
      workspace = ProjectWorkspace(
        title: workspace.title,
        subtitle: workspace.subtitle,
        tasks: workspace.tasks,
        sources: const <SourceItem>[],
        memoryRecords: const <MemoryRecord>[],
      );
      selectedMemoryId = null;
      selectedMemoryPage = null;
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.disconnected,
        memoryMessage,
      );
    } finally {
      memoryBusy = false;
      notifyListeners();
    }
  }

  /// Saves a reviewed memory candidate as immutable source-backed evidence.
  Future<void> saveMemoryCandidateFromUi(MemoryCaptureDraft draft) async {
    memoryBusy = true;
    memoryMessage = 'Saving reviewed memory candidate';
    notifyListeners();
    try {
      await memoryClient.saveMemoryCandidate(
        draft: draft,
        idempotencyKey:
            'aurora-ui:${DateTime.now().microsecondsSinceEpoch}:${draft.title}',
      );
      memoryMessage = 'Memory candidate saved';
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.connected,
        memoryMessage,
      );
      await _loadMemory();
    } catch (error) {
      memoryMessage = error.toString();
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.disconnected,
        memoryMessage,
      );
    } finally {
      memoryBusy = false;
      notifyListeners();
    }
  }

  /// Repairs selected catalog metadata without changing raw evidence.
  Future<void> repairMemoryFromUi(MemoryRepairDraft draft) async {
    memoryBusy = true;
    memoryMessage = 'Repairing catalog metadata';
    notifyListeners();
    try {
      final repaired = await memoryClient.repairCatalogRecord(draft: draft);
      _replaceMemoryRecord(repaired);
      selectedMemoryId = repaired.id;
      memoryMessage = 'Catalog metadata repaired';
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.connected,
        memoryMessage,
      );
    } catch (error) {
      memoryMessage = error.toString();
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.disconnected,
        memoryMessage,
      );
    } finally {
      memoryBusy = false;
      notifyListeners();
    }
  }

  /// Stores a correction as a new source-backed memory.
  Future<void> submitMemoryCorrectionFromUi(String text) async {
    final memory = selectedMemory;
    if (memory == null) {
      return;
    }
    memoryBusy = true;
    memoryMessage = 'Submitting source-backed correction';
    notifyListeners();
    try {
      await memoryClient.submitMemoryCorrection(
        catalogId: memory.id,
        text: text,
        scope: memory.scope,
      );
      memoryMessage = 'Correction saved as new memory';
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.connected,
        memoryMessage,
      );
      await _loadMemory();
    } catch (error) {
      memoryMessage = error.toString();
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.disconnected,
        memoryMessage,
      );
    } finally {
      memoryBusy = false;
      notifyListeners();
    }
  }

  /// Loads or creates a compiled entity page for the selected memory.
  Future<void> loadEntityPageFromUi(MemoryRecord memory) async {
    if (memory.entityIds.isEmpty && memory.entityNames.isEmpty) {
      memoryMessage = 'Select a memory with an entity first';
      notifyListeners();
      return;
    }
    memoryBusy = true;
    memoryMessage = 'Loading compiled entity page';
    notifyListeners();
    try {
      selectedMemoryPage = await memoryClient.loadEntityPage(
        scope: memory.scope,
        entityId: memory.entityIds.isEmpty ? '' : memory.entityIds.first,
        title: memory.entityNames.isEmpty
            ? memory.title
            : memory.entityNames.first,
      );
      memoryMessage = 'Entity page loaded';
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.connected,
        memoryMessage,
      );
    } catch (error) {
      memoryMessage = error.toString();
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.disconnected,
        memoryMessage,
      );
    } finally {
      memoryBusy = false;
      notifyListeners();
    }
  }

  /// Loads or creates a compiled timeline for a topic.
  Future<void> loadTimelineFromUi(String topic) async {
    final memory = selectedMemory;
    if (memory == null || topic.trim().isEmpty) {
      return;
    }
    memoryBusy = true;
    memoryMessage = 'Loading source-backed timeline';
    notifyListeners();
    try {
      selectedMemoryPage = await memoryClient.loadTimeline(
        scope: memory.scope,
        topic: topic.trim(),
        entityId: memory.entityIds.isEmpty ? '' : memory.entityIds.first,
      );
      memoryMessage = 'Timeline loaded';
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.connected,
        memoryMessage,
      );
    } catch (error) {
      memoryMessage = error.toString();
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.disconnected,
        memoryMessage,
      );
    } finally {
      memoryBusy = false;
      notifyListeners();
    }
  }

  /// Refreshes the last loaded compiled memory page.
  Future<void> refreshSelectedMemoryPageFromUi() async {
    final page = selectedMemoryPage;
    if (page == null) {
      return;
    }
    memoryBusy = true;
    memoryMessage = 'Refreshing compiled page';
    notifyListeners();
    try {
      selectedMemoryPage = await memoryClient.refreshCompiledPage(
        kind: page.kind,
        scope: page.scope,
        title: page.title,
        topic: page.kind == 'timeline' ? page.title : '',
      );
      memoryMessage = 'Compiled page refreshed';
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.connected,
        memoryMessage,
      );
    } catch (error) {
      memoryMessage = error.toString();
      _setEndpoint(
        _primaryMemoryLabel(),
        ConnectionStateKind.disconnected,
        memoryMessage,
      );
    } finally {
      memoryBusy = false;
      notifyListeners();
    }
  }

  /// Completes a task after local UI confirmation.
  Future<void> completeTaskFromUi(String taskId) async {
    final server = _taskServerForTask(taskId);
    if (server == null) {
      _setEndpoint('Tasks', ConnectionStateKind.disconnected, 'No task server');
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Completing task';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.completeTask(taskId);
      });
      await _loadTasks();
      _setEndpoint(
        server.label,
        ConnectionStateKind.connected,
        'Task completed',
      );
      tasksMessage = 'Task completed';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
    }
    notifyListeners();
  }

  /// Updates mutable task fields after local UI confirmation.
  Future<void> updateTaskFromUi({
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
  }) async {
    final server = _taskServerForTask(taskId);
    if (server == null) {
      _setEndpoint('Tasks', ConnectionStateKind.disconnected, 'No task server');
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Saving task';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.updateTask(
          taskId: taskId,
          title: title,
          description: description,
          status: status,
          priority: priority,
          dueAt: dueAt,
          clearDueAt: clearDueAt,
          scheduledAt: scheduledAt,
          clearScheduledAt: clearScheduledAt,
          topics: topics,
          replaceTopics: topics != null,
        );
      });
      selectedTaskId = taskId;
      taskSelectionKind = 'task';
      await _loadTasks();
      _setEndpoint(server.label, ConnectionStateKind.connected, 'Task saved');
      tasksMessage = 'Task saved';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Cancels a task after local UI confirmation.
  Future<void> cancelTaskFromUi(String taskId) async {
    final server = _taskServerForTask(taskId);
    if (server == null) {
      _setEndpoint('Tasks', ConnectionStateKind.disconnected, 'No task server');
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Canceling task';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.cancelTask(taskId);
      });
      selectedTaskId = taskId;
      await _loadTasks();
      _setEndpoint(
        server.label,
        ConnectionStateKind.connected,
        'Task canceled',
      );
      tasksMessage = 'Task canceled';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Deletes a task after local UI confirmation.
  Future<void> deleteTaskFromUi(String taskId) async {
    final server = _taskServerForTask(taskId);
    if (server == null) {
      _setEndpoint('Tasks', ConnectionStateKind.disconnected, 'No task server');
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Deleting task';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.deleteTask(taskId);
      });
      if (selectedTaskId == taskId) {
        selectedTaskId = null;
      }
      await _loadTasks();
      _setEndpoint(server.label, ConnectionStateKind.connected, 'Task deleted');
      tasksMessage = 'Task deleted';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Links the selected memory record to a task.
  Future<void> linkSelectedMemoryToTaskFromUi(String taskId) async {
    final server = _taskServerForTask(taskId);
    final drafts = _selectedMemoryLinkDrafts('context');
    if (server == null || drafts.isEmpty) {
      tasksMessage = 'Select a task server and memory record first';
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Linking memory to task';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.linkTaskMemory(taskId: taskId, link: drafts.first);
      });
      selectedTaskId = taskId;
      taskSelectionKind = 'task';
      await _loadTasks();
      _setEndpoint(
        server.label,
        ConnectionStateKind.connected,
        'Memory linked',
      );
      tasksMessage = 'Memory linked';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Unlinks memory from a task.
  Future<void> unlinkTaskMemoryFromUi({
    required String taskId,
    required String linkId,
  }) async {
    final server = _taskServerForTask(taskId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Unlinking memory';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.unlinkTaskMemory(taskId: taskId, linkId: linkId);
      });
      selectedTaskId = taskId;
      taskSelectionKind = 'task';
      await _loadTasks();
      tasksMessage = 'Memory unlinked';
      _setEndpoint(server.label, ConnectionStateKind.connected, tasksMessage);
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Creates a named task list.
  Future<void> createTaskListFromUi({
    required String name,
    String description = '',
    List<String> topics = const <String>[],
    bool linkSelectedMemory = false,
  }) async {
    final server = _primaryTaskServer();
    if (server == null) {
      _setEndpoint('Tasks', ConnectionStateKind.disconnected, 'No task server');
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Creating list';
    notifyListeners();
    try {
      final memoryLinks = linkSelectedMemory
          ? _selectedMemoryLinkDrafts('originated_from')
          : const <TaskMemoryLinkDraft>[];
      final created = await _withTasksClientForServer(server, (client) {
        return client.createList(
          name: name,
          description: description,
          topics: topics,
          memoryLinks: memoryLinks,
        );
      });
      selectedTaskListId = created.id;
      taskSelectionKind = 'list';
      await _loadTasks();
      _setEndpoint(server.label, ConnectionStateKind.connected, 'List created');
      tasksMessage = 'List created';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Deletes a named task list.
  Future<void> deleteTaskListFromUi(String listId) async {
    final server = _taskServerForList(listId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Deleting list';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.deleteList(listId);
      });
      if (selectedTaskListId == listId) {
        selectedTaskListId = null;
      }
      await _loadTasks();
      _setEndpoint(server.label, ConnectionStateKind.connected, 'List deleted');
      tasksMessage = 'List deleted';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Adds an item to a named task list.
  Future<void> addTaskListItemFromUi({
    required String listId,
    required String text,
    DateTime? dueAt,
    bool linkSelectedMemory = false,
  }) async {
    final server = _taskServerForList(listId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Adding list item';
    notifyListeners();
    try {
      final memoryLinks = linkSelectedMemory
          ? _selectedMemoryLinkDrafts('context')
          : const <TaskMemoryLinkDraft>[];
      final item = await _withTasksClientForServer(server, (client) {
        return client.addListItem(
          listId: listId,
          text: text,
          dueAt: dueAt,
          memoryLinks: memoryLinks,
        );
      });
      selectedTaskListId = listId;
      selectedTaskListItemId = item.id;
      taskSelectionKind = 'list';
      await _loadTasks();
      _setEndpoint(server.label, ConnectionStateKind.connected, 'Item added');
      tasksMessage = 'Item added';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Updates a named-list item.
  Future<void> updateTaskListItemFromUi({
    required String itemId,
    String? text,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? checked,
  }) async {
    final server = _taskServerForListItem(itemId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Saving list item';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.updateListItem(
          itemId: itemId,
          text: text,
          dueAt: dueAt,
          clearDueAt: clearDueAt,
          checked: checked,
        );
      });
      selectedTaskListItemId = itemId;
      taskSelectionKind = 'list';
      await _loadTasks();
      _setEndpoint(server.label, ConnectionStateKind.connected, 'Item saved');
      tasksMessage = 'Item saved';
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Sets a named-list item checked state.
  Future<void> checkTaskListItemFromUi({
    required String itemId,
    required bool checked,
  }) async {
    final server = _taskServerForListItem(itemId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = checked ? 'Checking item' : 'Unchecking item';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.checkListItem(itemId: itemId, checked: checked);
      });
      selectedTaskListItemId = itemId;
      taskSelectionKind = 'list';
      await _loadTasks();
      tasksMessage = checked ? 'Item checked' : 'Item unchecked';
      _setEndpoint(server.label, ConnectionStateKind.connected, tasksMessage);
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Deletes a named-list item.
  Future<void> deleteTaskListItemFromUi(String itemId) async {
    final server = _taskServerForListItem(itemId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Deleting item';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.deleteListItem(itemId);
      });
      if (selectedTaskListItemId == itemId) {
        selectedTaskListItemId = null;
      }
      await _loadTasks();
      tasksMessage = 'Item deleted';
      _setEndpoint(server.label, ConnectionStateKind.connected, tasksMessage);
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Links the selected memory record to a named task list.
  Future<void> linkSelectedMemoryToTaskListFromUi(String listId) async {
    final server = _taskServerForList(listId);
    final drafts = _selectedMemoryLinkDrafts('context');
    if (server == null || drafts.isEmpty) {
      tasksMessage = 'Select a list and memory record first';
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Linking memory to list';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.linkListMemory(listId: listId, link: drafts.first);
      });
      selectedTaskListId = listId;
      taskSelectionKind = 'list';
      await _loadTasks();
      tasksMessage = 'Memory linked';
      _setEndpoint(server.label, ConnectionStateKind.connected, tasksMessage);
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Unlinks memory from a named task list.
  Future<void> unlinkTaskListMemoryFromUi({
    required String listId,
    required String linkId,
  }) async {
    final server = _taskServerForList(listId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Unlinking memory';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.unlinkListMemory(listId: listId, linkId: linkId);
      });
      selectedTaskListId = listId;
      taskSelectionKind = 'list';
      await _loadTasks();
      tasksMessage = 'Memory unlinked';
      _setEndpoint(server.label, ConnectionStateKind.connected, tasksMessage);
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Links the selected memory record to a named-list item.
  Future<void> linkSelectedMemoryToTaskListItemFromUi(String itemId) async {
    final server = _taskServerForListItem(itemId);
    final drafts = _selectedMemoryLinkDrafts('context');
    if (server == null || drafts.isEmpty) {
      tasksMessage = 'Select a list item and memory record first';
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Linking memory to item';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.linkListItemMemory(itemId: itemId, link: drafts.first);
      });
      selectedTaskListItemId = itemId;
      taskSelectionKind = 'list';
      await _loadTasks();
      tasksMessage = 'Memory linked';
      _setEndpoint(server.label, ConnectionStateKind.connected, tasksMessage);
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Unlinks memory from a named-list item.
  Future<void> unlinkTaskListItemMemoryFromUi({
    required String itemId,
    required String linkId,
  }) async {
    final server = _taskServerForListItem(itemId);
    if (server == null) {
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Unlinking memory';
    notifyListeners();
    try {
      await _withTasksClientForServer(server, (client) {
        return client.unlinkListItemMemory(itemId: itemId, linkId: linkId);
      });
      selectedTaskListItemId = itemId;
      taskSelectionKind = 'list';
      await _loadTasks();
      tasksMessage = 'Memory unlinked';
      _setEndpoint(server.label, ConnectionStateKind.connected, tasksMessage);
    } catch (error) {
      tasksMessage = error.toString();
      _setEndpoint(
        server.label,
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    } finally {
      tasksBusy = false;
      notifyListeners();
    }
  }

  /// Runs the task steward review.
  Future<void> reviewTasksFromUi() async {
    final servers = runtimeProfile?.taskServers ?? const <McpServerRuntime>[];
    if (servers.isEmpty) {
      tasksMessage = 'No task server';
      _setEndpoint('Tasks', ConnectionStateKind.disconnected, tasksMessage);
      notifyListeners();
      return;
    }
    tasksBusy = true;
    tasksMessage = 'Running task review';
    notifyListeners();
    var reviewedTasks = 0;
    var reviewedLists = 0;
    final recommendations = <TaskReviewRecommendation>[];
    final failures = <String>[];
    DateTime? generatedAt;
    for (final server in servers) {
      final client = _tasksClientFor(server);
      try {
        final report = await client.reviewTasks();
        reviewedTasks += report.reviewedTasks;
        reviewedLists += report.reviewedLists;
        generatedAt ??= report.generatedAt;
        recommendations.addAll(
          report.recommendations.map(
            (recommendation) => recommendation.copyWith(
              sourceId: server.id,
              sourceLabel: server.label,
            ),
          ),
        );
        _setEndpoint(server.label, ConnectionStateKind.connected, 'Reviewed');
      } catch (error) {
        failures.add('${server.label}: $error');
        _setEndpoint(
          server.label,
          ConnectionStateKind.disconnected,
          error.toString(),
        );
      } finally {
        if (!identical(client, tasksClient)) {
          client.close();
        }
      }
    }
    taskReviewReport = TaskReviewReport(
      actor: 'task_steward',
      generatedAt: generatedAt ?? DateTime.now(),
      reviewedTasks: reviewedTasks,
      reviewedLists: reviewedLists,
      summary: failures.isEmpty
          ? 'Reviewed $reviewedTasks tasks and $reviewedLists lists'
          : failures.join(' | '),
      recommendations: recommendations,
    );
    tasksMessage = failures.isEmpty
        ? 'Task review complete'
        : 'Task review completed with failures';
    tasksBusy = false;
    notifyListeners();
  }

  Future<void> _loadSessions() async {
    await _log('load sessions start');
    try {
      final loaded = await assistantClient.listSessions();
      await _log('load sessions returned ${loaded.length}');
      if (loaded.isNotEmpty) {
        sessions = loaded;
        selectedSessionId = loaded.first.id;
        await selectSession(loaded.first.id);
      }
      _setEndpoint('Agent API', ConnectionStateKind.connected, 'Connected');
    } catch (error) {
      await _log('load sessions failed: $error');
      _setEndpoint(
        'Agent API',
        ConnectionStateKind.disconnected,
        error.toString(),
      );
    }
  }

  Future<void> _loadMemory() async {
    await _log('load memory start');
    try {
      memoryBusy = true;
      memoryMessage = 'Searching memory catalog';
      notifyListeners();
      final records = <MemoryRecord>[];
      final failures = <String>[];
      for (final server in _activeRuntimeProfile().memoryServers) {
        await _log('load memory via ${server.label} ${server.endpoint}');
        final client = _memoryClientFor(server);
        try {
          records.addAll(
            await client.searchCatalog(
              scope: memoryFilters.scope,
              text: memoryFilters.text,
              kinds: memoryFilters.kinds,
              topics: memoryFilters.topics,
              entityIds: memoryFilters.entityIds,
              allowedSensitivities: memoryFilters.allowedSensitivities,
              limit: memoryFilters.limit,
            ),
          );
          _setEndpoint(
            server.label,
            ConnectionStateKind.connected,
            'Connected',
          );
        } catch (error) {
          await _log('load memory failed for ${server.label}: $error');
          failures.add('${server.label}: $error');
          _setEndpoint(
            server.label,
            ConnectionStateKind.disconnected,
            error.toString(),
          );
        } finally {
          if (!identical(client, memoryClient)) {
            client.close();
          }
        }
      }
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
      if (records.isEmpty) {
        selectedMemoryId = null;
      } else if (selectedMemoryId == null ||
          !records.any((record) => record.id == selectedMemoryId)) {
        selectedMemoryId = records.first.id;
      }
      memoryMessage = records.isEmpty
          ? failures.isEmpty
                ? 'No memory records matched the current filters'
                : failures.join(' | ')
          : 'Loaded ${records.length} memory records';
      await _log('load memory complete records=${records.length}');
    } catch (error) {
      await _log('load memory failed: $error');
      memoryMessage = error.toString();
    } finally {
      memoryBusy = false;
    }
    notifyListeners();
  }

  Future<void> _loadTasks() async {
    await _log('load tasks start');
    tasksBusy = true;
    tasksMessage = 'Loading tasks';
    notifyListeners();
    final tasks = <WorkspaceTask>[];
    final lists = <WorkspaceTaskList>[];
    final failures = <String>[];
    final profile = runtimeProfile;
    if (profile == null) {
      workspace = ProjectWorkspace(
        title: workspace.title,
        subtitle: workspace.subtitle,
        tasks: const <WorkspaceTask>[],
        sources: workspace.sources,
        memoryRecords: workspace.memoryRecords,
      );
      taskLists = const <WorkspaceTaskList>[];
      tasksBusy = false;
      tasksMessage = 'Runtime profile is not loaded';
      notifyListeners();
      return;
    }
    for (final server in profile.taskServers) {
      await _log('load tasks via ${server.label} ${server.endpoint}');
      final client = _tasksClientFor(server);
      try {
        final serverTasks = await client.listTasks(
          filters: const TaskFilterState(statuses: <String>[]),
          includeDone: true,
          includeLinks: true,
          limit: taskFilters.limit,
        );
        final serverLists = await client.listLists(
          includeItems: true,
          includeLinks: true,
        );
        await _log('load tasks ${server.label} returned ${serverTasks.length}');
        tasks.addAll(
          serverTasks.map(
            (task) =>
                task.copyWith(sourceId: server.id, sourceLabel: server.label),
          ),
        );
        lists.addAll(
          serverLists.map(
            (list) =>
                list.copyWith(sourceId: server.id, sourceLabel: server.label),
          ),
        );
        _setEndpoint(server.label, ConnectionStateKind.connected, 'Connected');
      } catch (error) {
        await _log('load tasks failed for ${server.label}: $error');
        failures.add('${server.label}: $error');
        _setEndpoint(
          server.label,
          ConnectionStateKind.disconnected,
          error.toString(),
        );
      } finally {
        if (!identical(client, tasksClient)) {
          client.close();
        }
      }
    }
    tasks.sort(_compareTasksForWorkQueue);
    lists.sort((left, right) => left.name.compareTo(right.name));
    workspace = ProjectWorkspace(
      title: workspace.title,
      subtitle: workspace.subtitle,
      tasks: tasks,
      sources: workspace.sources,
      memoryRecords: workspace.memoryRecords,
    );
    taskLists = lists;
    if (selectedTaskId != null &&
        !tasks.any((task) => task.id == selectedTaskId)) {
      selectedTaskId = null;
    }
    if (selectedTaskListId != null &&
        !lists.any((list) => list.id == selectedTaskListId)) {
      selectedTaskListId = null;
      selectedTaskListItemId = null;
    }
    tasksMessage = failures.isEmpty
        ? 'Loaded ${tasks.length} tasks and ${lists.length} lists'
        : failures.join(' | ');
    tasksBusy = false;
    await _log('load tasks complete tasks=${tasks.length}');
    notifyListeners();
  }

  RuntimeProfile _activeRuntimeProfile() {
    final profile = runtimeProfile;
    if (profile == null) {
      throw StateError('Runtime profile is not loaded');
    }
    return profile;
  }

  MemoryClient _memoryClientFor(McpServerRuntime server) {
    if (memoryClient.endpoint == server.endpoint) {
      return memoryClient;
    }
    return MemoryClient(
      rpc: McpJsonRpcClient(endpoint: server.endpoint, logger: logger),
    );
  }

  TasksClient _tasksClientFor(McpServerRuntime server) {
    if (tasksClient.endpoint == server.endpoint) {
      return tasksClient;
    }
    return TasksClient(
      rpc: McpJsonRpcClient(endpoint: server.endpoint, logger: logger),
    );
  }

  McpServerRuntime? _primaryTaskServer() {
    final servers = runtimeProfile?.taskServers ?? const <McpServerRuntime>[];
    if (servers.isEmpty) {
      return null;
    }
    return servers.first;
  }

  String _primaryMemoryLabel() {
    final servers = _activeRuntimeProfile().memoryServers;
    if (servers.isEmpty) {
      return 'Memory';
    }
    return servers.first.label;
  }

  McpServerRuntime? _taskServerForTask(String taskId) {
    final profile = runtimeProfile;
    if (profile == null) {
      return null;
    }
    for (final task in workspace.tasks) {
      if (task.id == taskId && task.sourceId.isNotEmpty) {
        for (final server in profile.taskServers) {
          if (server.id == task.sourceId) {
            return server;
          }
        }
      }
    }
    return _primaryTaskServer();
  }

  McpServerRuntime? _taskServerForList(String listId) {
    final profile = runtimeProfile;
    if (profile == null) {
      return null;
    }
    for (final list in taskLists) {
      if (list.id == listId && list.sourceId.isNotEmpty) {
        for (final server in profile.taskServers) {
          if (server.id == list.sourceId) {
            return server;
          }
        }
      }
    }
    return _primaryTaskServer();
  }

  McpServerRuntime? _taskServerForListItem(String itemId) {
    for (final list in taskLists) {
      for (final item in list.items) {
        if (item.id == itemId) {
          return _taskServerForList(list.id);
        }
      }
    }
    return _primaryTaskServer();
  }

  Future<T> _withTasksClientForServer<T>(
    McpServerRuntime server,
    Future<T> Function(TasksClient client) action,
  ) async {
    final client = _tasksClientFor(server);
    try {
      return await action(client);
    } finally {
      if (!identical(client, tasksClient)) {
        client.close();
      }
    }
  }

  List<TaskMemoryLinkDraft> _selectedMemoryLinkDrafts(String relationship) {
    final memory = selectedMemory;
    if (memory == null) {
      return const <TaskMemoryLinkDraft>[];
    }
    return <TaskMemoryLinkDraft>[
      TaskMemoryLinkDraft(
        memoryCatalogId: memory.id,
        memoryEvidenceId: memory.evidenceId,
        relationship: relationship,
        note: memory.title,
      ),
    ];
  }

  void _setEndpoint(String name, ConnectionStateKind state, String message) {
    var found = false;
    endpointStatuses = endpointStatuses.map((status) {
      if (status.name != name) {
        return status;
      }
      found = true;
      return EndpointStatus(
        name: status.name,
        url: status.url,
        state: state,
        message: message,
      );
    }).toList();
    if (!found) {
      endpointStatuses = <EndpointStatus>[
        ...endpointStatuses,
        EndpointStatus(name: name, url: '', state: state, message: message),
      ];
    }
    statusMessage = message;
  }

  void _refreshEndpointSkeleton(RuntimeProfile profile) {
    endpointStatuses = <EndpointStatus>[
      EndpointStatus(
        name: 'Agent API',
        url: profile.harness.apiBaseUrl,
        state: ConnectionStateKind.unknown,
        message: 'Profile updated',
      ),
      for (final server in profile.mcpServers.where((server) => server.enabled))
        EndpointStatus(
          name: server.label,
          url: server.endpoint,
          state: ConnectionStateKind.unknown,
          message: 'Profile updated',
        ),
    ];
  }

  Future<bool> _ensureLiveSession() async {
    if (selectedSessionId != null) {
      await _log('live session already selected $selectedSessionId');
      return true;
    }
    await _log('no selected session; creating chat');
    return createChat();
  }

  String _agentUnavailableMessage() {
    final profile = runtimeProfile;
    if (profile == null) {
      return statusMessage;
    }
    for (final status in localProcessStatuses) {
      if (status.name == profile.harness.label && status.message.isNotEmpty) {
        return 'Aurora could not start the managed harness: ${status.message}';
      }
    }
    for (final status in endpointStatuses) {
      if (status.name == 'Agent API' && status.message.isNotEmpty) {
        return 'Aurora could not reach the managed Agent API: ${status.message}';
      }
    }
    return 'Aurora is still preparing the managed Agent API.';
  }

  Future<void> _streamRun({
    required String sessionId,
    String text = '',
    ConfirmationReply? reply,
    bool allowTaskTextCorrection = true,
  }) async {
    try {
      await _log(
        'stream run start session=$sessionId textLength=${text.length} confirmation=${reply != null}',
      );
      var count = 0;
      var sawToolActivity = false;
      final assistantText = StringBuffer();
      ConfirmationRequest? autoConfirmation;
      await for (final event in assistantClient.sendMessage(
        sessionId: sessionId,
        text: text,
        confirmation: reply,
      )) {
        count++;
        await _log(
          'stream event #$count author=${event.author} textLength=${event.text.length} partial=${event.partial} tool=${event.toolActivity?.name ?? ''} error=${event.errorMessage.isNotEmpty}',
        );
        if (event.toolActivity != null) {
          sawToolActivity = true;
        }
        if (event.author != 'user' && event.text.trim().isNotEmpty) {
          assistantText.write(' ');
          assistantText.write(event.text);
        }
        autoConfirmation ??= _applyEvent(event);
      }
      await _log('stream run complete session=$sessionId events=$count');
      if (count == 0) {
        messages = <ChatMessage>[
          ...messages,
          ChatMessage(
            id: 'runtime-${DateTime.now().microsecondsSinceEpoch}',
            role: ChatRole.tool,
            author: 'Runtime',
            text:
                'The Agent API completed the run without returning any stream events. Check ${config.serviceLogDirectory}/ui.log and harness.log for the request trace.',
            createdAt: DateTime.now(),
          ),
        ];
      }
      _setEndpoint('Agent API', ConnectionStateKind.connected, 'Run complete');
      if (autoConfirmation != null) {
        await _log(
          'auto-approving task confirmation for ${autoConfirmation.toolName}',
        );
        await _sendConfirmationReply(
          sessionId: sessionId,
          confirmation: autoConfirmation,
          option: _approvalOption(autoConfirmation),
        );
      } else if (allowTaskTextCorrection &&
          reply == null &&
          !sawToolActivity &&
          _isTaskApprovalText(assistantText.toString(), text)) {
        await _log('auto-correcting text approval gate for task request');
        await _streamRun(
          sessionId: sessionId,
          text: _taskAutoApprovalCorrection,
          allowTaskTextCorrection: false,
        );
      }
    } catch (error) {
      await _log('stream run failed session=$sessionId: $error');
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

  Future<void> _log(String message) async {
    await logger.write('ui', message);
  }

  ConfirmationRequest? _applyEvent(AssistantEvent event) {
    ConfirmationRequest? autoConfirmation;
    if (event.confirmation != null) {
      final confirmation = event.confirmation!;
      if (_shouldAutoApproveTaskConfirmation(confirmation)) {
        autoConfirmation = confirmation;
      } else {
        pendingConfirmation = confirmation;
      }
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
    final toolActivity = event.toolActivity;
    if (toolActivity != null &&
        toolActivity.status == 'completed' &&
        _taskWriteToolNames.contains(toolActivity.name)) {
      unawaited(_loadTasks());
    }
    notifyListeners();
    return autoConfirmation;
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
      if (_isAutoHandledTaskConfirmationFailure(event.toolActivity!)) {
        return null;
      }
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

  void _replaceMemoryRecord(MemoryRecord replacement) {
    final records = workspace.memoryRecords.map((record) {
      return record.id == replacement.id ? replacement : record;
    }).toList();
    workspace = ProjectWorkspace(
      title: workspace.title,
      subtitle: workspace.subtitle,
      tasks: workspace.tasks,
      sources: workspace.sources,
      memoryRecords: records,
    );
  }

  List<String> _sensitivitiesIncluding(String sensitivity) {
    if (memoryFilters.allowedSensitivities.contains(sensitivity)) {
      return memoryFilters.allowedSensitivities;
    }
    return <String>[...memoryFilters.allowedSensitivities, sensitivity];
  }
}

/// Compares tasks for the default work-queue order.
int _compareTasksForWorkQueue(WorkspaceTask left, WorkspaceTask right) {
  final terminalCompare = _terminalRank(left).compareTo(_terminalRank(right));
  if (terminalCompare != 0) {
    return terminalCompare;
  }
  final overdueCompare = (right.overdue ? 1 : 0).compareTo(
    left.overdue ? 1 : 0,
  );
  if (overdueCompare != 0) {
    return overdueCompare;
  }
  final leftDue = left.dueAt ?? left.scheduledAt;
  final rightDue = right.dueAt ?? right.scheduledAt;
  if (leftDue != null && rightDue != null) {
    final dueCompare = leftDue.compareTo(rightDue);
    if (dueCompare != 0) {
      return dueCompare;
    }
  } else if (leftDue != null) {
    return -1;
  } else if (rightDue != null) {
    return 1;
  }
  final priorityCompare = _priorityRank(
    left.priority,
  ).compareTo(_priorityRank(right.priority));
  if (priorityCompare != 0) {
    return priorityCompare;
  }
  return left.title.compareTo(right.title);
}

/// Returns whether a task is terminal for queue ordering.
int _terminalRank(WorkspaceTask task) {
  return task.status == 'done' || task.status == 'canceled' ? 1 : 0;
}

/// Returns a numeric rank for task priorities.
int _priorityRank(String priority) {
  return switch (priority) {
    'urgent' => 0,
    'high' => 1,
    'normal' => 2,
    'low' => 3,
    _ => 4,
  };
}

/// Returns whether text contains a query case-insensitively.
bool _textContains(String text, String query) {
  return text.toLowerCase().contains(query.trim().toLowerCase());
}

/// Task MCP write tools that should refresh the task workspace after chat use.
const Set<String> _taskWriteToolNames = <String>{
  'create_task',
  'update_task',
  'complete_task',
  'cancel_task',
  'delete_task',
  'link_task_memory',
  'unlink_task_memory',
  'create_list',
  'delete_list',
  'add_list_item',
  'update_list_item',
  'check_list_item',
  'delete_list_item',
  'link_list_memory',
  'unlink_list_memory',
  'link_list_item_memory',
  'unlink_list_item_memory',
};

/// Hidden repair turn for stale sessions that still ask to approve task writes.
const String _taskAutoApprovalCorrection =
    '${hiddenRuntimeMessagePrefix}Task management is auto-approved by Doug. '
    'Create the task now using the task tool. Do not ask for approval.';

/// Returns a non-conflicting profile copy path in the profile directory.
Future<String> _uniqueRuntimeProfilePath(
  String directory,
  String profileId,
) async {
  final base = profileId.trim().isEmpty ? 'profile' : profileId;
  var candidate = '$directory/$base-copy.json';
  var index = 2;
  while (await File(candidate).exists()) {
    candidate = '$directory/$base-copy-$index.json';
    index++;
  }
  return candidate;
}

Future<RuntimeProfileFileEntry> _profileEntryForPath(String path) async {
  try {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is Map<String, dynamic>) {
      return RuntimeProfileFileEntry(
        path: path,
        id: _optionalString(decoded['id'], fallback: _profileIdFromPath(path)),
        label: _optionalString(
          decoded['label'],
          fallback: _profileIdFromPath(path),
        ),
        active: false,
      );
    }
  } catch (_) {
    // Invalid profile files remain visible by filename so they can be repaired.
  }
  return RuntimeProfileFileEntry(
    path: path,
    id: _profileIdFromPath(path),
    label: _profileIdFromPath(path),
    active: false,
  );
}

Future<String?> _copyConfigIntoAppDirectory({
  required String sourcePath,
  required String targetDirectory,
  required String targetName,
}) async {
  if (sourcePath.trim().isEmpty || sourcePath.startsWith(targetDirectory)) {
    return sourcePath;
  }
  final source = File(sourcePath);
  if (!await source.exists()) {
    return null;
  }
  final directory = Directory(targetDirectory);
  await directory.create(recursive: true);
  final target = File('${directory.path}/$targetName');
  if (!await target.exists()) {
    await target.writeAsString(await source.readAsString());
  }
  return target.path;
}

/// Derives a stable profile id from a profile file path.
String _profileIdFromPath(String path) {
  final filename = path.replaceAll('\\', '/').split('/').last;
  final dot = filename.lastIndexOf('.');
  if (dot <= 0) {
    return filename;
  }
  return filename.substring(0, dot);
}

String _optionalString(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
