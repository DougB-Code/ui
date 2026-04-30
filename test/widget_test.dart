/// Tests the primary Aurora workspace widgets.
library;

import 'package:agentawesome_ui/app/app_config.dart';
import 'package:agentawesome_ui/app/app_controller.dart';
import 'package:agentawesome_ui/app/local_services.dart';
import 'package:agentawesome_ui/app/runtime_profile.dart';
import 'package:agentawesome_ui/domain/models.dart';
import 'package:agentawesome_ui/ui/aurora_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs widget tests for the shell.
void main() {
  testWidgets('renders home workspace without local demo data', (tester) async {
    final controller = AuroraAppController(config: _testConfig());

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );

    expect(find.text('Live Workspace'), findsOneWidget);
    expect(find.text('Execution Plan'), findsNothing);
    expect(find.text('No live chat messages'), findsOneWidget);
    expect(find.text('Prepare investor meeting brief'), findsNothing);
  });

  testWidgets('opens settings command workspace', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AuroraAppController(config: _testConfig());
    controller.runtimeProfile = _settingsProfile();
    controller.endpointStatuses = const <EndpointStatus>[
      EndpointStatus(
        name: 'Agent API',
        url: 'http://127.0.0.1:1/api',
        state: ConnectionStateKind.disconnected,
      ),
      EndpointStatus(
        name: 'Memory MCP',
        url: 'http://127.0.0.1:1/mcp',
        state: ConnectionStateKind.disconnected,
      ),
      EndpointStatus(
        name: 'Tasks MCP',
        url: 'http://127.0.0.1:1/mcp',
        state: ConnectionStateKind.disconnected,
      ),
    ];
    controller.localProcessStatuses = const <ServiceProcessStatus>[
      ServiceProcessStatus(
        name: 'Memory Service',
        url: 'http://127.0.0.1:1/healthz',
        state: ConnectionStateKind.connected,
        message: 'Started locally',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Profiles'), findsWidgets);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Personal'), findsWidgets);
  });

  testWidgets('opens dedicated chat command shell', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AuroraAppController(config: _testConfig());
    controller.sessions = <ChatSession>[
      ChatSession(
        id: 'session-live',
        title: 'Live chat',
        updatedAt: DateTime(2026, 4, 29, 9, 30),
      ),
    ];
    controller.selectedSessionId = 'session-live';
    controller.messages = <ChatMessage>[
      ChatMessage(
        id: 'message-1',
        role: ChatRole.assistant,
        author: 'Aurora',
        text: 'Connected chat message.',
        createdAt: DateTime(2026, 4, 29, 9, 31),
      ),
    ];
    controller.workspace = _memoryWorkspace();

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CONVERSATION'), findsOneWidget);
    expect(find.text('CONTEXT'), findsOneWidget);
    expect(find.byTooltip('Chats'), findsWidgets);
    expect(find.byTooltip('Sessions'), findsNothing);
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.text('Connected chat message.'), findsOneWidget);
    expect(find.text('Preference'), findsWidgets);
    await tester.tap(find.byTooltip('Chats').first);
    await tester.pumpAndSettle();
    expect(find.text('CHATS'), findsOneWidget);
  });

  testWidgets('opens memory stewardship workspace', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AuroraAppController(config: _testConfig());
    controller.workspace = _memoryWorkspace();

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.text('Memory'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SEARCH'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('Preference'), findsWidgets);
    expect(find.text('CATALOG'), findsOneWidget);
  });

  testWidgets('opens task workspace with queue and inspector', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AuroraAppController(config: _testConfig());
    controller.workspace = const ProjectWorkspace(
      title: 'Workspace',
      subtitle: 'Live connected workspace',
      tasks: <WorkspaceTask>[
        WorkspaceTask(
          id: 'task-brief',
          title: 'Draft task brief',
          detail: 'Open',
          done: false,
          status: 'open',
          priority: 'high',
          topics: <String>['brief'],
        ),
      ],
      sources: <SourceItem>[],
      memoryRecords: <MemoryRecord>[],
    );
    controller.taskLists = const <WorkspaceTaskList>[
      WorkspaceTaskList(
        id: 'list-errands',
        name: 'Errands',
        items: <TaskListItem>[
          TaskListItem(
            id: 'item-stamps',
            listId: 'list-errands',
            text: 'Buy stamps',
            checked: false,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.text('Tasks').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('QUEUE'), findsOneWidget);
    expect(find.text('TASK INSPECTOR'), findsOneWidget);
    expect(find.text('Draft task brief'), findsWidgets);
    await tester.tap(find.byTooltip('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('Errands'), findsOneWidget);
  });

  testWidgets('loads workflow content inside the persistent app shell', (
    tester,
  ) async {
    final controller = AuroraAppController(config: _testConfig());

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('New chat'), findsOneWidget);
    expect(find.text('Workspace'), findsWidgets);
    expect(find.text('MEMORY & CONTEXT'), findsOneWidget);
  });

  testWidgets('keeps workflow command panes side by side on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AuroraAppController(config: _testConfig());

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();

    final workflowLeft = tester.getRect(find.text('Workspace').first);
    final workflowRight = tester.getRect(find.text('MEMORY & CONTEXT'));

    expect(tester.takeException(), isNull);
    expect(workflowLeft.left, lessThan(workflowRight.left));
    expect(workflowRight.left, greaterThan(900));
  });

  testWidgets('resizes workflow command panes with the split handle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AuroraAppController(config: _testConfig());

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();

    final beforeRight = tester.getRect(find.text('MEMORY & CONTEXT')).left;
    await tester.drag(
      find.byKey(const ValueKey<String>('command-split-handle')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    final afterRight = tester.getRect(find.text('MEMORY & CONTEXT')).left;

    expect(tester.takeException(), isNull);
    expect(afterRight, greaterThan(beforeRight + 80));
  });

  testWidgets('cycles and filters workflow command panel content', (
    tester,
  ) async {
    final controller = AuroraAppController(config: _testConfig());
    controller.workspace = const ProjectWorkspace(
      title: 'Workspace',
      subtitle: 'Live connected workspace',
      tasks: <WorkspaceTask>[
        WorkspaceTask(
          id: 'task-review',
          title: 'Review source material',
          detail: 'Open',
          done: false,
        ),
        WorkspaceTask(
          id: 'task-competitor',
          title: 'Analyze competitor positioning',
          detail: 'Open',
          done: false,
        ),
      ],
      sources: <SourceItem>[],
      memoryRecords: <MemoryRecord>[],
    );

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WORKSPACE'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('command-panel-filter-Research Plan')),
      'competitor',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('RESEARCH PLAN'), findsOneWidget);
    expect(find.text('Analyze competitor positioning'), findsOneWidget);
    expect(find.text('Review source material'), findsNothing);
  });

  testWidgets('collapses sidebar without layout overflow', (tester) async {
    final controller = AuroraAppController(config: _testConfig());

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('AURORA'), findsNothing);
  });
}

ProjectWorkspace _memoryWorkspace() {
  return const ProjectWorkspace(
    title: 'Workspace',
    subtitle: 'Live connected workspace',
    tasks: <WorkspaceTask>[],
    sources: <SourceItem>[],
    memoryRecords: <MemoryRecord>[
      MemoryRecord(
        id: 'cat-1',
        evidenceId: 'ev-1',
        title: 'Preference',
        summary: 'User prefers direct connected data.',
        kind: 'profile_fact',
        topics: <String>['ui'],
        sourceLabel: 'chat:1',
        sourceSystem: 'chat',
        sourceId: '1',
      ),
    ],
  );
}

RuntimeProfile _settingsProfile() {
  return const RuntimeProfile(
    id: 'personal',
    label: 'Personal',
    harness: HarnessRuntime(
      id: 'harness',
      label: 'Local Harness',
      apiBaseUrl: 'http://127.0.0.1:1/api',
      appName: 'test',
      userId: 'user',
      workingDirectory: '/tmp/harness',
      packagePath: './cmd/agent-awesome',
      modelConfigPath: '/tmp/model.yaml',
      agentConfigPath: '/tmp/agent.yaml',
      toolConfigPath: '/tmp/tool.yaml',
      port: 1,
      autoStart: false,
    ),
    mcpServers: <McpServerRuntime>[
      McpServerRuntime(
        id: 'memory',
        label: 'Personal Memory',
        kind: 'memory',
        endpoint: 'http://127.0.0.1:1/mcp',
        healthUrl: 'http://127.0.0.1:1/healthz',
        workingDirectory: '/tmp/memory',
        packagePath: './cmd/memoryd',
        arguments: <String>[],
        autoStart: false,
        enabled: true,
      ),
      McpServerRuntime(
        id: 'tasks',
        label: 'Personal Tasks',
        kind: 'tasks',
        endpoint: 'http://127.0.0.1:2/mcp',
        healthUrl: 'http://127.0.0.1:2/healthz',
        workingDirectory: '/tmp/tasks',
        packagePath: './cmd/tasksd',
        arguments: <String>[],
        autoStart: false,
        enabled: true,
      ),
    ],
  );
}

AppConfig _testConfig() {
  return const AppConfig(
    agentApiBaseUrl: 'http://127.0.0.1:1/api',
    memoryMcpUrl: 'http://127.0.0.1:1/mcp',
    tasksMcpUrl: 'http://127.0.0.1:1/mcp',
    agentAppName: 'test',
    agentUserId: 'user',
    workspaceRoot: '/tmp/agentawesome-test',
    autoStartLocalServices: false,
    runtimeProfilePath: '',
  );
}
