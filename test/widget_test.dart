/// Tests the primary Aurora workspace widgets.
library;

import 'package:agentawesome_ui/app/app_config.dart';
import 'package:agentawesome_ui/app/app_controller.dart';
import 'package:agentawesome_ui/domain/models.dart';
import 'package:agentawesome_ui/ui/aurora_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs widget tests for the shell.
void main() {
  testWidgets('renders home workspace with seeded content', (tester) async {
    final controller = AuroraAppController(config: _testConfig());

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );

    expect(find.text('Prepare investor meeting brief'), findsOneWidget);
    expect(find.text('Execution Plan'), findsNothing);
    expect(find.text('Review source material'), findsOneWidget);
  });

  testWidgets('opens settings route and shows endpoints', (tester) async {
    final controller = AuroraAppController(config: _testConfig());
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

    await tester.pumpWidget(
      MaterialApp(home: AuroraShell(controller: controller)),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Agent API'), findsOneWidget);
    expect(find.text('Memory MCP'), findsOneWidget);
    expect(find.text('Tasks MCP'), findsOneWidget);
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

AppConfig _testConfig() {
  return const AppConfig(
    agentApiBaseUrl: 'http://127.0.0.1:1/api',
    memoryMcpUrl: 'http://127.0.0.1:1/mcp',
    tasksMcpUrl: 'http://127.0.0.1:1/mcp',
    agentAppName: 'test',
    agentUserId: 'user',
  );
}
