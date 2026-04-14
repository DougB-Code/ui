import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:ui/main.dart';
import 'package:ui/provider_catalog_api.dart';

void main() {
  ProviderCatalogApi buildProviderApi() => MemoryProviderCatalogApi.seeded();

  testWidgets('renders the agent workbench shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    await tester.pumpWidget(AgentWorkbenchApp(providerApi: buildProviderApi()));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Providers'), findsWidgets);
    expect(find.text('Workflows'), findsWidgets);
    expect(find.text('Tool Traffic'), findsOneWidget);
    expect(find.text('Agent Awesome'), findsOneWidget);

    await tester.tap(find.text('Providers').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Search providers'), findsOneWidget);
    expect(find.text('openai-prod'), findsWidgets);

    await tester.tapAt(const Offset(1500, 100));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workflows').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Search workflows'), findsOneWidget);
    expect(find.text('governed_change_execution'), findsWidgets);

    await tester.tapAt(const Offset(1500, 100));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Agent Awesome'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('connects and disconnects workflow nodes by dragging handles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    await tester.pumpWidget(AgentWorkbenchApp(providerApi: buildProviderApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workflows').first);
    await tester.pumpAndSettle();

    expect(find.text('1 outgoing connection'), findsOneWidget);

    final sourceHandle = find.byKey(const ValueKey('connector-source-triage'));
    final finishNode = find.byKey(const ValueKey('canvas-node-finish'));

    final connectGesture = await tester.startGesture(
      tester.getCenter(sourceHandle),
    );
    await connectGesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await connectGesture.moveTo(tester.getCenter(finishNode));
    await tester.pump();
    await connectGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('2 outgoing connections'), findsOneWidget);
    expect(find.text('Finish'), findsWidgets);

    final disconnectGesture = await tester.startGesture(
      tester.getCenter(sourceHandle),
    );
    await disconnectGesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await disconnectGesture.moveTo(tester.getCenter(finishNode));
    await tester.pump();
    await disconnectGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('1 outgoing connection'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('selects a connection and deletes it with Delete', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    await tester.pumpWidget(AgentWorkbenchApp(providerApi: buildProviderApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workflows').first);
    await tester.pumpAndSettle();

    final triageNode = find.byKey(const ValueKey('canvas-node-triage'));
    final planNode = find.byKey(const ValueKey('canvas-node-plan'));
    final triageCenter = tester.getCenter(triageNode);
    final planCenter = tester.getCenter(planNode);
    final edgePoint = Offset(
      (triageCenter.dx + planCenter.dx) / 2,
      (triageCenter.dy + planCenter.dy) / 2,
    );

    await tester.tapAt(edgePoint);
    await tester.pumpAndSettle();

    expect(
      find.text('Selected connection: triage -> plan. Press Delete to remove.'),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.text('0 outgoing connections'), findsOneWidget);
    expect(
      find.text('Selected connection: triage -> plan. Press Delete to remove.'),
      findsNothing,
    );

    await tester.binding.setSurfaceSize(null);
  });
}
