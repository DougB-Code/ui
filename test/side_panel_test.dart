import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/shared/side_panel.dart';
import 'package:ui/shared/ui.dart';

void main() {
  testWidgets('side panel cycles, switches, and fuzzy filters content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgentAwesomeTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AppSidePanel(
              searchHintText: 'Filter panels...',
              sections: [
                AppSidePanelSection(
                  id: 'overview',
                  label: 'Overview',
                  icon: Icons.inventory_2_outlined,
                  builder: (BuildContext context, String query) {
                    final items = AppFuzzySearch.filter<String>(
                      const <String>['Alpha', 'Beta'],
                      query,
                      (String item) => <String>[item, 'overview'],
                    );
                    return _TestPanelContent(
                      items: items,
                      emptyTitle: 'No matching overview items',
                    );
                  },
                ),
                AppSidePanelSection(
                  id: 'topology',
                  label: 'Topology',
                  icon: Icons.hub_outlined,
                  builder: (BuildContext context, String query) {
                    final items = AppFuzzySearch.filter<String>(
                      const <String>['Production', 'Staging'],
                      query,
                      (String item) => <String>[item, 'topology'],
                    );
                    return _TestPanelContent(
                      items: items,
                      emptyTitle: 'No matching topology items',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Production'), findsNothing);

    await tester.tap(find.byTooltip('Cycle panels'));
    await tester.pumpAndSettle();

    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Staging'), findsOneWidget);

    await tester.tap(find.byTooltip('Open panel menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview').last);
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Production'), findsNothing);

    await tester.tap(find.byTooltip('Topology'));
    await tester.pumpAndSettle();

    expect(find.text('Production'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'prd');
    await tester.pumpAndSettle();

    expect(find.text('Production'), findsOneWidget);
    expect(find.text('Staging'), findsNothing);
  });

  testWidgets('dense side panel shares row and section behavior', (
    WidgetTester tester,
  ) async {
    final selectedId = ValueNotifier<String?>('alpha');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgentAwesomeTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ValueListenableBuilder<String?>(
              valueListenable: selectedId,
              builder: (BuildContext context, String? currentId, _) {
                return AppDenseSidePanel<_TestEntry>(
                  selectedEntryId: currentId,
                  entryId: (_TestEntry entry) => entry.id,
                  onSelectEntry: (_TestEntry entry) {
                    selectedId.value = entry.id;
                  },
                  searchHintText: 'Filter sections...',
                  sections: [
                    AppDenseSidePanelSection<_TestEntry>(
                      id: 'agents',
                      label: 'Agents',
                      icon: Icons.smart_toy_outlined,
                      entries: const <_TestEntry>[
                        _TestEntry(
                          id: 'alpha',
                          title: 'Alpha agent',
                          subtitle: 'Primary responder',
                          tags: <String>['lead'],
                        ),
                        _TestEntry(
                          id: 'beta',
                          title: 'Beta agent',
                          subtitle: 'Secondary responder',
                          tags: <String>['review'],
                        ),
                      ],
                      searchFields: (_TestEntry entry) => <String>[
                        entry.title,
                        entry.subtitle,
                        ...entry.tags,
                      ],
                      emptyTitle: 'No matching agents',
                      emptyBody: 'Try a different query.',
                      headerBuilder:
                          (
                            BuildContext context,
                            List<_TestEntry> entries,
                            List<_TestEntry> filteredEntries,
                            String searchQuery,
                          ) {
                            return Text(
                              '${filteredEntries.length} visible',
                              style: const TextStyle(color: textSubtleColor),
                            );
                          },
                      rowBuilder:
                          (
                            BuildContext context,
                            _TestEntry entry,
                            bool selected,
                            VoidCallback onTap,
                          ) {
                            return AppDenseSidePanelRow(
                              title: entry.title,
                              subtitle: entry.subtitle,
                              selected: selected,
                              onTap: onTap,
                              trailing: const StatusPill(
                                label: 'Agent',
                                color: infoColor,
                              ),
                              footer: entry.tags
                                  .map(
                                    (String tag) => StatusPill(
                                      label: tag,
                                      color: accentColor,
                                    ),
                                  )
                                  .toList(growable: false),
                            );
                          },
                    ),
                    AppDenseSidePanelSection<_TestEntry>(
                      id: 'graphs',
                      label: 'Graphs',
                      icon: Icons.hub_outlined,
                      entries: const <_TestEntry>[
                        _TestEntry(
                          id: 'prod',
                          title: 'Production graph',
                          subtitle: 'Primary runtime graph',
                          tags: <String>['runtime'],
                        ),
                      ],
                      searchFields: (_TestEntry entry) => <String>[
                        entry.title,
                        entry.subtitle,
                        ...entry.tags,
                      ],
                      emptyTitle: 'No matching graphs',
                      emptyBody: 'Try a different query.',
                      rowBuilder:
                          (
                            BuildContext context,
                            _TestEntry entry,
                            bool selected,
                            VoidCallback onTap,
                          ) {
                            return AppDenseSidePanelRow(
                              title: entry.title,
                              subtitle: entry.subtitle,
                              selected: selected,
                              onTap: onTap,
                              trailing: const StatusPill(
                                label: 'Graph',
                                color: successColor,
                              ),
                            );
                          },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha agent'), findsOneWidget);
    expect(find.text('2 visible'), findsOneWidget);

    await tester.tap(find.text('Beta agent'));
    await tester.pumpAndSettle();

    expect(selectedId.value, 'beta');

    await tester.tap(find.byTooltip('Graphs'));
    await tester.pumpAndSettle();

    expect(find.text('Production graph'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'prd');
    await tester.pumpAndSettle();

    expect(find.text('Production graph'), findsOneWidget);
  });
}

class _TestPanelContent extends StatelessWidget {
  const _TestPanelContent({required this.items, required this.emptyTitle});

  final List<String> items;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        body: 'Change the query to surface matching side panel content.',
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        return Text(
          items[index],
          style: const TextStyle(color: textPrimaryColor),
        );
      },
    );
  }
}

class _TestEntry {
  const _TestEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tags,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> tags;
}
