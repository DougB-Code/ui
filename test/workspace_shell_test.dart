import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/shared/ui.dart';
import 'package:ui/shared/workspace_shell.dart';

void main() {
  testWidgets('workspace shell divider shows feedback and resizes panes', (
    WidgetTester tester,
  ) async {
    const leftPaneKey = ValueKey<String>('left-pane');
    const rightPaneKey = ValueKey<String>('right-pane');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgentAwesomeTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1000,
              height: 520,
              child: ConfigWorkspaceShell(
                stacked: false,
                collectionPane: Container(key: leftPaneKey),
                detailPane: Container(key: rightPaneKey),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dividerFinder = find.byKey(
      const ValueKey<String>('config-workspace-divider'),
    );
    final handleFinder = find.byKey(
      const ValueKey<String>('config-workspace-divider-handle'),
    );

    final leftWidthBefore = tester.getSize(find.byKey(leftPaneKey)).width;
    final handleHeightBefore = tester.getSize(handleFinder).height;
    expect(handleHeightBefore, 52);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(dividerFinder));
    await tester.pumpAndSettle();

    final handleHeightHovered = tester.getSize(handleFinder).height;
    expect(handleHeightHovered, greaterThan(handleHeightBefore));

    final drag = await tester.startGesture(
      tester.getCenter(dividerFinder),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveBy(const Offset(120, 0));
    await tester.pumpAndSettle();

    final leftWidthAfter = tester.getSize(find.byKey(leftPaneKey)).width;
    final rightWidthAfter = tester.getSize(find.byKey(rightPaneKey)).width;
    final dividerWidthDragging = tester.getSize(dividerFinder).width;

    expect(leftWidthAfter, greaterThan(leftWidthBefore));
    expect(rightWidthAfter, lessThan(490));
    expect(dividerWidthDragging, 12);

    await drag.up();
    await tester.pumpAndSettle();
    await mouse.removePointer();
  });
}
