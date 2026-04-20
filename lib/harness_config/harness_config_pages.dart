import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/harness_config/harness_document_state.dart';
import 'package:ui/harness_config/harness_tools_workspace.dart';
import 'package:ui/harness_config/harness_workflows_workspace.dart';
import 'package:ui/shared/side_panel.dart';
import 'package:ui/shared/ui.dart';
import 'package:ui/shared/workspace_shell.dart';

class HarnessAgentsPage extends StatefulWidget {
  const HarnessAgentsPage({
    super.key,
    required this.harnessConfigApi,
    required this.harnessConfigAvailable,
    required this.headerActionsController,
  });

  final HarnessConfigApi harnessConfigApi;
  final bool harnessConfigAvailable;
  final ScreenHeaderActionsController headerActionsController;

  @override
  State<HarnessAgentsPage> createState() => _HarnessAgentsPageState();
}

class _HarnessAgentsPageState
    extends HarnessDocumentPageState<HarnessAgentsPage, HarnessAgentCatalog> {
  @override
  ScreenHeaderActionsController get headerActionsController =>
      widget.headerActionsController;

  @override
  bool get headerActionsEnabled => widget.harnessConfigAvailable;

  @override
  String get emptyBody =>
      'The control plane returned no harness agent document.';

  @override
  String get emptyTitle => 'No harness agent data';

  @override
  String get savedMessage => 'Harness agent configuration saved.';

  @override
  String catalogYaml(HarnessAgentCatalog catalog) => catalog.yaml;

  @override
  Future<HarnessAgentCatalog> fetchCatalog() {
    return widget.harnessConfigApi.getAgents();
  }

  @override
  Future<HarnessAgentCatalog> saveCatalog(String yaml) {
    return widget.harnessConfigApi.saveAgents(yaml);
  }

  @override
  Future<HarnessConfigValidationReport> validateCatalog(String yaml) {
    return widget.harnessConfigApi.validateAgents(yaml);
  }

  @override
  Widget build(BuildContext context) {
    return buildDocumentUnavailable(
      available: widget.harnessConfigAvailable,
      unavailableTitle: 'Harness config unavailable',
      unavailableBody:
          'This deployment mode disables local harness config management routes. Switch to local mode to manage harness agents.',
      builder: (HarnessAgentCatalog catalog) {
        return HarnessAgentsWorkspace(
          catalog: catalog,
          controller: controller,
          validation: validation,
        );
      },
    );
  }
}

enum _AgentWorkspaceEntryKind { catalog, template, agent }

enum _AgentDetailTab { overview, advanced }

class _AgentWorkspaceEntry {
  const _AgentWorkspaceEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.subtitle,
    required this.badges,
    this.sourceIndex,
  });

  final String id;
  final _AgentWorkspaceEntryKind kind;
  final String name;
  final String subtitle;
  final List<String> badges;
  final int? sourceIndex;
}

class HarnessAgentsWorkspace extends StatefulWidget {
  const HarnessAgentsWorkspace({
    super.key,
    required this.catalog,
    required this.controller,
    required this.validation,
  });

  final HarnessAgentCatalog catalog;
  final TextEditingController controller;
  final HarnessConfigValidationReport? validation;

  @override
  State<HarnessAgentsWorkspace> createState() => _HarnessAgentsWorkspaceState();
}

class _HarnessAgentsWorkspaceState extends State<HarnessAgentsWorkspace> {
  String? _selectedEntryId;
  _AgentDetailTab _detailTab = _AgentDetailTab.overview;

  List<_AgentWorkspaceEntry> get _entries => <_AgentWorkspaceEntry>[
    _AgentWorkspaceEntry(
      id: 'catalog',
      kind: _AgentWorkspaceEntryKind.catalog,
      name: 'Agent catalog',
      subtitle: _joinNonEmpty(<String>[
        blankAsUnknown(widget.catalog.leadAgent),
        '${widget.catalog.agents.length} agents',
        '${widget.catalog.roleTemplates.length} templates',
      ]),
      badges: const <String>[],
    ),
    for (int index = 0; index < widget.catalog.roleTemplates.length; index++)
      _AgentWorkspaceEntry(
        id: 'template:$index',
        kind: _AgentWorkspaceEntryKind.template,
        name: widget.catalog.roleTemplates[index].name,
        subtitle: _joinNonEmpty(<String>[
          widget.catalog.roleTemplates[index].role,
          widget.catalog.roleTemplates[index].policyPreset,
          widget.catalog.roleTemplates[index].maxSteps == 0
              ? ''
              : '${widget.catalog.roleTemplates[index].maxSteps} steps',
        ]),
        badges: widget.catalog.roleTemplates[index].allowedToolGroups,
        sourceIndex: index,
      ),
    for (int index = 0; index < widget.catalog.agents.length; index++)
      _AgentWorkspaceEntry(
        id: 'agent:$index',
        kind: _AgentWorkspaceEntryKind.agent,
        name: widget.catalog.agents[index].name,
        subtitle: _joinNonEmpty(<String>[
          widget.catalog.agents[index].template,
          widget.catalog.agents[index].role,
          widget.catalog.agents[index].model,
        ]),
        badges: <String>[
          if (widget.catalog.agents[index].policyPreset.isNotEmpty)
            widget.catalog.agents[index].policyPreset,
          if (widget.catalog.agents[index].maxSteps != 0)
            '${widget.catalog.agents[index].maxSteps} steps',
        ],
        sourceIndex: index,
      ),
  ];

  @override
  void initState() {
    super.initState();
    _ensureSelection();
  }

  @override
  void didUpdateWidget(covariant HarnessAgentsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog.yaml != widget.catalog.yaml ||
        oldWidget.catalog.configPath != widget.catalog.configPath ||
        oldWidget.catalog.agents.length != widget.catalog.agents.length ||
        oldWidget.catalog.roleTemplates.length !=
            widget.catalog.roleTemplates.length) {
      _ensureSelection();
    }
  }

  void _ensureSelection() {
    if (_selectedEntryId != null &&
        _entries.any(
          (_AgentWorkspaceEntry entry) => entry.id == _selectedEntryId,
        )) {
      return;
    }
    _selectedEntryId = _entries.isEmpty ? null : _entries.first.id;
  }

  void _selectFirstEntryForKind(_AgentWorkspaceEntryKind kind) {
    final nextEntry = _entries
        .where((_AgentWorkspaceEntry entry) => entry.kind == kind)
        .firstOrNull;
    if (nextEntry == null || nextEntry.id == _selectedEntryId) {
      return;
    }
    setState(() {
      _selectedEntryId = nextEntry.id;
      _detailTab = _AgentDetailTab.overview;
    });
  }

  _AgentWorkspaceEntry? get _selectedEntry {
    final selectedId = _selectedEntryId;
    if (selectedId == null) {
      return null;
    }
    for (final entry in _entries) {
      if (entry.id == selectedId) {
        return entry;
      }
    }
    return _entries.isEmpty ? null : _entries.first;
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntry = _selectedEntry;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1240;
        final collectionPane = _AgentCollectionPane(
          entries: _entries,
          selectedEntryId: _selectedEntryId,
          initialSectionId: selectedEntry?.kind.sectionId,
          onSectionChanged: (_AgentWorkspaceEntryKind kind) {
            _selectFirstEntryForKind(kind);
          },
          onSelectEntry: (_AgentWorkspaceEntry entry) {
            setState(() {
              _selectedEntryId = entry.id;
              _detailTab = _AgentDetailTab.overview;
            });
          },
        );
        final detailPane = _AgentDetailPane(
          catalog: widget.catalog,
          selectedEntry: selectedEntry,
          activeTab: _detailTab,
          controller: widget.controller,
          validation: widget.validation,
          onTabChanged: (_AgentDetailTab tab) {
            setState(() => _detailTab = tab);
          },
        );

        return ConfigWorkspaceShell(
          stacked: stacked,
          collectionPane: collectionPane,
          detailPane: detailPane,
          collectionFlex: 10,
          detailFlex: 11,
        );
      },
    );
  }
}

class _AgentCollectionPane extends StatelessWidget {
  const _AgentCollectionPane({
    required this.entries,
    required this.selectedEntryId,
    required this.initialSectionId,
    required this.onSectionChanged,
    required this.onSelectEntry,
  });

  final List<_AgentWorkspaceEntry> entries;
  final String? selectedEntryId;
  final String? initialSectionId;
  final ValueChanged<_AgentWorkspaceEntryKind> onSectionChanged;
  final ValueChanged<_AgentWorkspaceEntry> onSelectEntry;

  @override
  Widget build(BuildContext context) {
    return AppDenseSidePanel<_AgentWorkspaceEntry>(
      selectedEntryId: selectedEntryId,
      entryId: (_AgentWorkspaceEntry entry) => entry.id,
      onSelectEntry: onSelectEntry,
      initialSectionId: initialSectionId,
      searchHintText: 'Filter catalog, templates, and agents...',
      emptyTitle: 'No agent panels',
      emptyBody: 'Agent catalog sections will appear here once data is loaded.',
      onSectionChanged: (String sectionId) {
        onSectionChanged(
          _AgentWorkspaceEntryKind.values.firstWhere(
            (_AgentWorkspaceEntryKind kind) => kind.sectionId == sectionId,
          ),
        );
      },
      sections: _AgentWorkspaceEntryKind.values
          .map((_AgentWorkspaceEntryKind kind) {
            return AppDenseSidePanelSection<_AgentWorkspaceEntry>(
              id: kind.sectionId,
              label: kind.panelLabel,
              icon: kind.panelIcon,
              entries: entries
                  .where((_AgentWorkspaceEntry entry) => entry.kind == kind)
                  .toList(growable: false),
              searchFields: (_AgentWorkspaceEntry entry) => <String>[
                entry.name,
                entry.subtitle,
                ...entry.badges,
                entry.kind.label,
              ],
              emptyTitle: 'No matching ${kind.emptyLabel}',
              emptyBody:
                  'Try a different search term to find ${kind.emptySearchDescription}.',
              rowBuilder:
                  (
                    BuildContext context,
                    _AgentWorkspaceEntry entry,
                    bool selected,
                    VoidCallback onTap,
                  ) {
                    return AppDenseSidePanelRow(
                      title: entry.name,
                      subtitle: entry.subtitle,
                      selected: selected,
                      onTap: onTap,
                      trailing: StatusPill(
                        label: entry.kind.label,
                        color: entry.kind.tone,
                      ),
                      footer: entry.badges
                          .take(4)
                          .map(
                            (String value) =>
                                StatusPill(label: value, color: infoColor),
                          )
                          .toList(growable: false),
                    );
                  },
            );
          })
          .toList(growable: false),
    );
  }
}

class _AgentDetailPane extends StatelessWidget {
  const _AgentDetailPane({
    required this.catalog,
    required this.selectedEntry,
    required this.activeTab,
    required this.controller,
    required this.validation,
    required this.onTabChanged,
  });

  final HarnessAgentCatalog catalog;
  final _AgentWorkspaceEntry? selectedEntry;
  final _AgentDetailTab activeTab;
  final TextEditingController controller;
  final HarnessConfigValidationReport? validation;
  final ValueChanged<_AgentDetailTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final entry = selectedEntry;
    if (entry == null) {
      return const Center(
        child: EmptyState(
          title: 'No agent selected',
          body:
              'Pick the catalog, a role template, or an agent to inspect it here.',
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: textPrimaryColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.kind == _AgentWorkspaceEntryKind.catalog &&
                        entry.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        entry.subtitle,
                        style: const TextStyle(
                          color: textMutedColor,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _AgentDetailTabs(activeTab: activeTab, onTabChanged: onTabChanged),
        Expanded(
          child: switch (activeTab) {
            _AgentDetailTab.overview => _AgentOverviewTab(
              catalog: catalog,
              entry: entry,
            ),
            _AgentDetailTab.advanced => _HarnessDocumentEditor(
              title: 'Agent YAML',
              controller: controller,
              validation: validation,
            ),
          },
        ),
      ],
    );
  }
}

class _AgentDetailTabs extends StatelessWidget {
  const _AgentDetailTabs({required this.activeTab, required this.onTabChanged});

  final _AgentDetailTab activeTab;
  final ValueChanged<_AgentDetailTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return ConfigWorkspaceTabBar<_AgentDetailTab>(
      items: _AgentDetailTab.values,
      value: activeTab,
      labelBuilder: (_AgentDetailTab tab) => tab.label,
      onChanged: onTabChanged,
    );
  }
}

class _AgentOverviewTab extends StatelessWidget {
  const _AgentOverviewTab({required this.catalog, required this.entry});

  final HarnessAgentCatalog catalog;
  final _AgentWorkspaceEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: switch (entry.kind) {
        _AgentWorkspaceEntryKind.catalog => _buildCatalogOverview(),
        _AgentWorkspaceEntryKind.template => _buildTemplateOverview(),
        _AgentWorkspaceEntryKind.agent => _buildAgentOverview(),
      },
    );
  }

  List<Widget> _buildCatalogOverview() {
    return <Widget>[
      InfoPanel(title: 'Config path', body: blankAsUnknown(catalog.configPath)),
      const SizedBox(height: 14),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          MetricCard(
            label: 'Lead agent',
            value: blankAsUnknown(catalog.leadAgent),
            tone: accentColor,
            detail: 'Resolved bootstrap lead role.',
          ),
          MetricCard(
            label: 'Agents',
            value: '${catalog.agents.length}',
            tone: infoColor,
            detail: 'Concrete runtime roles in `agent.yaml`.',
          ),
          MetricCard(
            label: 'Templates',
            value: '${catalog.roleTemplates.length}',
            tone: successColor,
            detail: 'Reusable role defaults.',
          ),
          MetricCard(
            label: 'Policies',
            value: '${catalog.policyPresets.length}',
            tone: warningColor,
            detail: 'Named policy preset entries.',
          ),
        ],
      ),
      const SizedBox(height: 18),
      _CatalogKeyValueSection(
        title: 'Runtime defaults',
        rows: <MapEntry<String, String>>[
          MapEntry('Approval mode', blankAsUnknown(catalog.approvalMode)),
          MapEntry(
            'Default max steps',
            catalog.defaultMaxSteps == 0
                ? 'not set'
                : '${catalog.defaultMaxSteps}',
          ),
          MapEntry(
            'Recent ledger limit',
            catalog.recentLedgerLimit == 0
                ? 'not set'
                : '${catalog.recentLedgerLimit}',
          ),
          MapEntry(
            'Memory retention days',
            catalog.memoryRetentionDays == 0
                ? 'not set'
                : '${catalog.memoryRetentionDays}',
          ),
          MapEntry(
            'Subagents',
            catalog.subagentsEnabled ? 'enabled' : 'disabled',
          ),
          MapEntry(
            'Subagent max steps',
            catalog.subagentDefaultMaxSteps == 0
                ? 'not set'
                : '${catalog.subagentDefaultMaxSteps}',
          ),
        ],
      ),
      const SizedBox(height: 18),
      TagSection(title: 'Policy presets', tags: catalog.policyPresets),
      const SizedBox(height: 18),
      _CatalogListSection(
        title: 'Role templates',
        emptyTitle: 'No role templates',
        emptyBody:
            'Role templates will appear here after the harness agent config loads them.',
        children: catalog.roleTemplates
            .map(
              (HarnessAgentTemplateSummary template) => _ConfigSummaryCard(
                title: template.name,
                subtitle: _joinNonEmpty(<String>[
                  template.role,
                  template.policyPreset,
                  template.maxSteps == 0 ? '' : '${template.maxSteps} steps',
                ]),
                tags: template.allowedToolGroups,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 18),
      _CatalogListSection(
        title: 'Agents',
        emptyTitle: 'No agents',
        emptyBody:
            'Agent instances will appear here after the harness agent config loads them.',
        children: catalog.agents
            .map(
              (HarnessAgentSummary agent) => _ConfigSummaryCard(
                title: agent.name,
                subtitle: _joinNonEmpty(<String>[
                  agent.template,
                  agent.role,
                  agent.model,
                  agent.maxSteps == 0 ? '' : '${agent.maxSteps} steps',
                  agent.policyPreset,
                ]),
                tags: <String>[...agent.toolGroups, ...agent.allowedTools],
              ),
            )
            .toList(),
      ),
    ];
  }

  List<Widget> _buildTemplateOverview() {
    final template = catalog.roleTemplates[entry.sourceIndex ?? 0];
    return <Widget>[
      _AgentSectionCard(
        title: 'Role template',
        child: _AgentPropertyList(
          rows: <MapEntry<String, String>>[
            MapEntry('Name', blankAsUnknown(template.name)),
            MapEntry('Role', blankAsUnknown(template.role)),
            MapEntry('Policy preset', blankAsUnknown(template.policyPreset)),
            MapEntry(
              'Max steps',
              template.maxSteps == 0 ? 'not set' : '${template.maxSteps}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      template.allowedToolGroups.isEmpty
          ? const InfoPanel(
              title: 'No tool groups',
              body: 'This template does not currently allow any tool groups.',
            )
          : TagSection(
              title: 'Allowed tool groups',
              tags: template.allowedToolGroups,
            ),
    ];
  }

  List<Widget> _buildAgentOverview() {
    final agent = catalog.agents[entry.sourceIndex ?? 0];
    return <Widget>[
      _AgentSectionCard(
        title: 'Agent settings',
        child: _AgentPropertyList(
          rows: <MapEntry<String, String>>[
            MapEntry('Name', blankAsUnknown(agent.name)),
            MapEntry('Template', blankAsUnknown(agent.template)),
            MapEntry('Role', blankAsUnknown(agent.role)),
            MapEntry('Model', blankAsUnknown(agent.model)),
            MapEntry(
              'Max steps',
              agent.maxSteps == 0 ? 'not set' : '${agent.maxSteps}',
            ),
            MapEntry('Policy preset', blankAsUnknown(agent.policyPreset)),
          ],
        ),
      ),
      const SizedBox(height: 18),
      agent.toolGroups.isEmpty
          ? const InfoPanel(
              title: 'No tool groups',
              body: 'This agent does not reference any tool groups yet.',
            )
          : TagSection(title: 'Tool groups', tags: agent.toolGroups),
      const SizedBox(height: 18),
      agent.allowedTools.isEmpty
          ? const InfoPanel(
              title: 'No explicit tools',
              body:
                  'This agent does not currently declare any additional allowed tools.',
            )
          : TagSection(title: 'Allowed tools', tags: agent.allowedTools),
    ];
  }
}

class _AgentSectionCard extends StatelessWidget {
  const _AgentSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConfigWorkspaceSectionCard(title: title, child: child);
  }
}

class _AgentPropertyList extends StatelessWidget {
  const _AgentPropertyList({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: rows
            .map(
              (MapEntry<String, String> row) => ListTile(
                dense: true,
                title: Text(
                  row.key,
                  style: const TextStyle(color: textMutedColor),
                ),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    row.value,
                    style: const TextStyle(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

extension on _AgentWorkspaceEntryKind {
  String get sectionId {
    return switch (this) {
      _AgentWorkspaceEntryKind.catalog => 'catalog',
      _AgentWorkspaceEntryKind.template => 'role-templates',
      _AgentWorkspaceEntryKind.agent => 'agents',
    };
  }

  String get panelLabel {
    return switch (this) {
      _AgentWorkspaceEntryKind.catalog => 'Catalog',
      _AgentWorkspaceEntryKind.template => 'Templates',
      _AgentWorkspaceEntryKind.agent => 'Agents',
    };
  }

  IconData get panelIcon {
    return switch (this) {
      _AgentWorkspaceEntryKind.catalog => Icons.inventory_2_outlined,
      _AgentWorkspaceEntryKind.template => Icons.auto_awesome_mosaic_outlined,
      _AgentWorkspaceEntryKind.agent => Icons.smart_toy_outlined,
    };
  }

  String get emptyLabel {
    return switch (this) {
      _AgentWorkspaceEntryKind.catalog => 'catalog entries',
      _AgentWorkspaceEntryKind.template => 'templates',
      _AgentWorkspaceEntryKind.agent => 'agents',
    };
  }

  String get emptySearchDescription {
    return switch (this) {
      _AgentWorkspaceEntryKind.catalog => 'catalog settings',
      _AgentWorkspaceEntryKind.template => 'role templates',
      _AgentWorkspaceEntryKind.agent => 'agents',
    };
  }

  String get label {
    return switch (this) {
      _AgentWorkspaceEntryKind.catalog => 'Catalog',
      _AgentWorkspaceEntryKind.template => 'Template',
      _AgentWorkspaceEntryKind.agent => 'Agent',
    };
  }

  Color get tone {
    return switch (this) {
      _AgentWorkspaceEntryKind.catalog => accentColor,
      _AgentWorkspaceEntryKind.template => successColor,
      _AgentWorkspaceEntryKind.agent => infoColor,
    };
  }
}

extension on _AgentDetailTab {
  String get label {
    return switch (this) {
      _AgentDetailTab.overview => 'Overview',
      _AgentDetailTab.advanced => 'Advanced',
    };
  }
}

class HarnessToolsPage extends StatefulWidget {
  const HarnessToolsPage({
    super.key,
    required this.harnessConfigApi,
    required this.harnessConfigAvailable,
    required this.headerActionsController,
  });

  final HarnessConfigApi harnessConfigApi;
  final bool harnessConfigAvailable;
  final ScreenHeaderActionsController headerActionsController;

  @override
  State<HarnessToolsPage> createState() => _HarnessToolsPageState();
}

class _HarnessToolsPageState
    extends HarnessDocumentPageState<HarnessToolsPage, HarnessToolCatalog> {
  HarnessToolCatalog? draftCatalog;

  @override
  ScreenHeaderActionsController get headerActionsController =>
      widget.headerActionsController;

  @override
  bool get headerActionsEnabled => widget.harnessConfigAvailable;

  @override
  String get emptyBody =>
      'The control plane returned no harness tool document.';

  @override
  String get emptyTitle => 'No harness tool data';

  @override
  String get savedMessage => 'Harness tool configuration saved.';

  @override
  String catalogYaml(HarnessToolCatalog catalog) => catalog.yaml;

  @override
  void onCatalogLoaded(HarnessToolCatalog loadedCatalog) {
    draftCatalog = loadedCatalog;
  }

  @override
  void onCatalogSaved(HarnessToolCatalog savedCatalog) {
    draftCatalog = savedCatalog;
  }

  @override
  Future<HarnessToolCatalog> fetchCatalog() {
    return widget.harnessConfigApi.getTools();
  }

  @override
  Future<HarnessToolCatalog> saveCatalog(String yaml) {
    return widget.harnessConfigApi.saveTools(yaml);
  }

  @override
  Future<HarnessConfigValidationReport> validateCatalog(String yaml) {
    return widget.harnessConfigApi.validateTools(yaml);
  }

  void _updateDraft(HarnessToolCatalog value) {
    setState(() {
      draftCatalog = value;
    });
  }

  @override
  Future<void> validateDocument() async {
    final current = draftCatalog;
    if (current == null) {
      return;
    }
    setState(() => busy = true);
    try {
      final report = await widget.harnessConfigApi.validateToolsCatalog(
        current,
      );
      if (!mounted) {
        return;
      }
      setState(() => validation = report);
      showAppMessage(context, report.summary);
    } catch (validationError) {
      if (!mounted) {
        return;
      }
      showAppMessage(context, validationError.toString());
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Future<void> saveDocumentState() async {
    final current = draftCatalog;
    if (current == null) {
      return;
    }
    setState(() => busy = true);
    try {
      final savedCatalog = await widget.harnessConfigApi.saveToolsCatalog(
        current,
      );
      if (!mounted) {
        return;
      }
      controller.text = catalogYaml(savedCatalog);
      onCatalogSaved(savedCatalog);
      setState(() {
        catalog = savedCatalog;
        validation = null;
      });
      showAppMessage(context, savedMessage);
    } catch (saveError) {
      if (!mounted) {
        return;
      }
      showAppMessage(context, saveError.toString());
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildDocumentUnavailable(
      available: widget.harnessConfigAvailable,
      unavailableTitle: 'Harness config unavailable',
      unavailableBody:
          'This deployment mode disables local harness config management routes. Switch to local mode to manage harness tools.',
      builder: (HarnessToolCatalog catalog) {
        final currentDraft = draftCatalog ?? catalog;
        return HarnessToolsWorkspace(
          catalog: currentDraft,
          documentYaml: controller.text,
          validation: validation,
          onCatalogChanged: _updateDraft,
        );
      },
    );
  }
}

class _HarnessDocumentEditor extends StatelessWidget {
  const _HarnessDocumentEditor({
    required this.title,
    required this.controller,
    required this.validation,
  });

  final String title;
  final TextEditingController controller;
  final HarnessConfigValidationReport? validation;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: title,
      fill: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This editor round-trips the full harness YAML document through the control plane. Validation runs the real harness config checks before save.',
            style: TextStyle(color: textMutedColor),
          ),
          if (validation != null) ...[
            const SizedBox(height: 16),
            _HarnessValidationPanel(report: validation!),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              style: const TextStyle(
                color: textPrimaryColor,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
              ),
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'YAML document',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HarnessValidationPanel extends StatelessWidget {
  const _HarnessValidationPanel({required this.report});

  final HarnessConfigValidationReport report;

  @override
  Widget build(BuildContext context) {
    final ok = report.status.toLowerCase() == 'ok';
    final tags = <String>[
      if (report.leadAgent.isNotEmpty) 'lead:${report.leadAgent}',
      if (report.agentCount > 0) 'agents:${report.agentCount}',
      if (report.externalToolCount > 0) 'external:${report.externalToolCount}',
      if (report.mcpServerCount > 0) 'mcp:${report.mcpServerCount}',
      if (report.probedModelCount > 0) 'models:${report.probedModelCount}',
      if (report.toolPlatform.isNotEmpty) report.toolPlatform,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ok ? successColor : dangerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: ok ? 'valid' : 'invalid',
                color: ok ? successColor : dangerColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.summary.isEmpty
                      ? 'Validation finished.'
                      : report.summary,
                  style: const TextStyle(color: textPrimaryColor),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map((String tag) => StatusPill(label: tag, color: infoColor))
                  .toList(),
            ),
          ],
          if (report.validatedModels.isNotEmpty ||
              report.availableExternalTools.isNotEmpty ||
              report.availableMcpServers.isNotEmpty ||
              report.failedModels.isNotEmpty ||
              report.unavailableExternalTools.isNotEmpty ||
              report.unavailableMcpServers.isNotEmpty) ...[
            const SizedBox(height: 14),
            if (report.validatedModels.isNotEmpty)
              TagSection(
                title: 'Validated models',
                tags: report.validatedModels,
              ),
            if (report.availableExternalTools.isNotEmpty) ...[
              if (report.validatedModels.isNotEmpty) const SizedBox(height: 12),
              TagSection(
                title: 'Available external tools',
                tags: report.availableExternalTools,
              ),
            ],
            if (report.availableMcpServers.isNotEmpty) ...[
              if (report.validatedModels.isNotEmpty ||
                  report.availableExternalTools.isNotEmpty)
                const SizedBox(height: 12),
              TagSection(
                title: 'Available MCP servers',
                tags: report.availableMcpServers,
              ),
            ],
            if (report.failedModels.isNotEmpty ||
                report.unavailableExternalTools.isNotEmpty ||
                report.unavailableMcpServers.isNotEmpty) ...[
              const SizedBox(height: 12),
              TagSection(
                title: 'Unavailable or failed entries',
                tags: <String>[
                  ...report.failedModels,
                  ...report.unavailableExternalTools,
                  ...report.unavailableMcpServers,
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CatalogKeyValueSection extends StatelessWidget {
  const _CatalogKeyValueSection({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsectionTitle(title),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: panelAltColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: rows
                .map(
                  (MapEntry<String, String> row) => ListTile(
                    dense: true,
                    title: Text(
                      row.key,
                      style: const TextStyle(color: textMutedColor),
                    ),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          color: textPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _CatalogListSection extends StatelessWidget {
  const _CatalogListSection({
    required this.title,
    required this.emptyTitle,
    required this.emptyBody,
    required this.children,
  });

  final String title;
  final String emptyTitle;
  final String emptyBody;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsectionTitle(title),
        const SizedBox(height: 10),
        if (children.isEmpty)
          InfoPanel(title: emptyTitle, body: emptyBody)
        else
          Column(
            children:
                children
                    .expand(
                      (Widget child) => <Widget>[
                        child,
                        const SizedBox(height: 10),
                      ],
                    )
                    .toList()
                  ..removeLast(),
          ),
      ],
    );
  }
}

class _ConfigSummaryCard extends StatelessWidget {
  const _ConfigSummaryCard({
    required this.title,
    required this.subtitle,
    required this.tags,
  });

  final String title;
  final String subtitle;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: textMutedColor)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .where((String value) => value.trim().isNotEmpty)
                  .map(
                    (String value) =>
                        StatusPill(label: value, color: infoColor),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

String _joinNonEmpty(List<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' • ');
}

class HarnessWorkflowsPage extends StatefulWidget {
  const HarnessWorkflowsPage({
    super.key,
    required this.harnessConfigApi,
    required this.harnessConfigAvailable,
    required this.headerActionsController,
  });

  final HarnessConfigApi harnessConfigApi;
  final bool harnessConfigAvailable;
  final ScreenHeaderActionsController headerActionsController;

  @override
  State<HarnessWorkflowsPage> createState() => _HarnessWorkflowsPageState();
}

class _HarnessWorkflowsPageState
    extends
        HarnessDocumentPageState<HarnessWorkflowsPage, HarnessWorkflowCatalog> {
  List<String> _runTargetOptions = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadRunTargetOptions();
  }

  @override
  void didUpdateWidget(covariant HarnessWorkflowsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.harnessConfigApi != widget.harnessConfigApi ||
        oldWidget.harnessConfigAvailable != widget.harnessConfigAvailable) {
      _loadRunTargetOptions();
    }
  }

  @override
  ScreenHeaderActionsController get headerActionsController =>
      widget.headerActionsController;

  @override
  bool get headerActionsEnabled => widget.harnessConfigAvailable;

  @override
  String get emptyBody =>
      'The control plane returned no harness workflow document.';

  @override
  String get emptyTitle => 'No harness workflow data';

  @override
  String get savedMessage => 'Harness workflow configuration saved.';

  @override
  String catalogYaml(HarnessWorkflowCatalog catalog) => catalog.yaml;

  @override
  Future<HarnessWorkflowCatalog> fetchCatalog() {
    return widget.harnessConfigApi.getWorkflows();
  }

  @override
  Future<HarnessWorkflowCatalog> saveCatalog(String yaml) {
    return widget.harnessConfigApi.saveWorkflows(yaml);
  }

  @override
  Future<HarnessConfigValidationReport> validateCatalog(String yaml) {
    return widget.harnessConfigApi.validateWorkflows(yaml);
  }

  Future<void> _loadRunTargetOptions() async {
    if (!widget.harnessConfigAvailable) {
      if (mounted) {
        setState(() => _runTargetOptions = const <String>[]);
      }
      return;
    }

    try {
      final HarnessAgentCatalog agentCatalog =
          await widget.harnessConfigApi.getAgents();
      final HarnessToolCatalog toolCatalog = await widget.harnessConfigApi
          .getTools();
      final LinkedHashSet<String> options = LinkedHashSet<String>.from(<String>[
        ...agentCatalog.agents.map((HarnessAgentSummary agent) => agent.name),
        ...toolCatalog.toolGroups.expand(
          (HarnessToolGroupSummary group) => group.tools,
        ),
        ...toolCatalog.externalTools.map(
          (HarnessExternalToolSummary tool) => tool.name,
        ),
      ]..removeWhere((String value) => value.trim().isEmpty));
      if (!mounted) {
        return;
      }
      setState(() => _runTargetOptions = options.toList(growable: false));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _runTargetOptions = const <String>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildDocumentUnavailable(
      available: widget.harnessConfigAvailable,
      unavailableTitle: 'Harness config unavailable',
      unavailableBody:
          'This deployment mode disables local harness config management routes. Switch to local mode to manage harness workflows.',
      builder: (HarnessWorkflowCatalog catalog) {
        return HarnessWorkflowsWorkspace(
          catalog: catalog,
          controller: controller,
          runTargetOptions: _runTargetOptions,
          validation: validation,
        );
      },
    );
  }
}
