import 'package:flutter/material.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/shared/ui.dart';

class HarnessAgentsPage extends StatefulWidget {
  const HarnessAgentsPage({
    required this.harnessConfigApi,
    required this.harnessConfigAvailable,
  });

  final HarnessConfigApi harnessConfigApi;
  final bool harnessConfigAvailable;

  @override
  State<HarnessAgentsPage> createState() => _HarnessAgentsPageState();
}

class _HarnessAgentsPageState extends State<HarnessAgentsPage> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  HarnessAgentCatalog? _catalog;
  HarnessConfigValidationReport? _validation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.harnessConfigApi.getAgents();
      _controller.text = catalog.yaml;
      setState(() {
        _catalog = catalog;
        _validation = null;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _validate() async {
    setState(() => _busy = true);
    try {
      final report = await widget.harnessConfigApi.validateAgents(
        _controller.text,
      );
      setState(() => _validation = report);
      _showMessage(report.summary);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final catalog = await widget.harnessConfigApi.saveAgents(
        _controller.text,
      );
      _controller.text = catalog.yaml;
      setState(() {
        _catalog = catalog;
        _validation = null;
      });
      _showMessage('Harness agent configuration saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    showAppMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.harnessConfigAvailable) {
      return const InfoPanel(
        title: 'Harness config unavailable',
        body:
            'This deployment mode disables local harness config management routes. Switch to local mode to manage harness agents.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final catalog = _catalog;
    if (catalog == null) {
      return const EmptyState(
        title: 'No harness agent data',
        body: 'The control plane returned no harness agent document.',
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1200;
        final summaryPane = PanelCard(
          title: 'Harness Agents',
          fill: true,
          child: ListView(
            children: [
              InfoPanel(
                title: 'Config path',
                body: blankAsUnknown(catalog.configPath),
              ),
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
                  MapEntry(
                    'Approval mode',
                    blankAsUnknown(catalog.approvalMode),
                  ),
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
                      (HarnessAgentTemplateSummary template) =>
                          _ConfigSummaryCard(
                            title: template.name,
                            subtitle: _joinNonEmpty(<String>[
                              template.role,
                              template.policyPreset,
                              template.maxSteps == 0
                                  ? ''
                                  : '${template.maxSteps} steps',
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
                        tags: <String>[
                          ...agent.toolGroups,
                          ...agent.allowedTools,
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );

        final editorPane = _HarnessDocumentEditor(
          title: 'Agent YAML',
          controller: _controller,
          busy: _busy,
          validation: _validation,
          onReload: _load,
          onValidate: _validate,
          onSave: _save,
        );

        if (stacked) {
          return Column(
            children: [
              Expanded(child: summaryPane),
              const SizedBox(height: 16),
              Expanded(child: editorPane),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 11, child: summaryPane),
            const SizedBox(width: 16),
            Expanded(flex: 10, child: editorPane),
          ],
        );
      },
    );
  }
}

class HarnessToolsPage extends StatefulWidget {
  const HarnessToolsPage({
    required this.harnessConfigApi,
    required this.harnessConfigAvailable,
  });

  final HarnessConfigApi harnessConfigApi;
  final bool harnessConfigAvailable;

  @override
  State<HarnessToolsPage> createState() => _HarnessToolsPageState();
}

class _HarnessToolsPageState extends State<HarnessToolsPage> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  HarnessToolCatalog? _catalog;
  HarnessConfigValidationReport? _validation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.harnessConfigApi.getTools();
      _controller.text = catalog.yaml;
      setState(() {
        _catalog = catalog;
        _validation = null;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _validate() async {
    setState(() => _busy = true);
    try {
      final report = await widget.harnessConfigApi.validateTools(
        _controller.text,
      );
      setState(() => _validation = report);
      _showMessage(report.summary);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final catalog = await widget.harnessConfigApi.saveTools(_controller.text);
      _controller.text = catalog.yaml;
      setState(() {
        _catalog = catalog;
        _validation = null;
      });
      _showMessage('Harness tool configuration saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    showAppMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.harnessConfigAvailable) {
      return const InfoPanel(
        title: 'Harness config unavailable',
        body:
            'This deployment mode disables local harness config management routes. Switch to local mode to manage harness tools.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final catalog = _catalog;
    if (catalog == null) {
      return const EmptyState(
        title: 'No harness tool data',
        body: 'The control plane returned no harness tool document.',
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1200;
        final summaryPane = PanelCard(
          title: 'Harness Tools',
          fill: true,
          child: ListView(
            children: [
              InfoPanel(
                title: 'Config path',
                body: blankAsUnknown(catalog.configPath),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MetricCard(
                    label: 'Tool groups',
                    value: '${catalog.toolGroups.length}',
                    tone: accentColor,
                    detail: 'Reusable tool bundles.',
                  ),
                  MetricCard(
                    label: 'External tools',
                    value: '${catalog.externalTools.length}',
                    tone: infoColor,
                    detail: 'Executable runtime tools.',
                  ),
                  MetricCard(
                    label: 'MCP servers',
                    value: '${catalog.mcpServers.length}',
                    tone: successColor,
                    detail: 'Surfaced MCP processes.',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _CatalogListSection(
                title: 'Tool groups',
                emptyTitle: 'No tool groups',
                emptyBody:
                    'Tool groups will appear here after the harness tool config loads them.',
                children: catalog.toolGroups
                    .map(
                      (HarnessToolGroupSummary group) => _ConfigSummaryCard(
                        title: group.name,
                        subtitle:
                            '${group.tools.length} tool${group.tools.length == 1 ? '' : 's'}',
                        tags: group.tools,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              _CatalogListSection(
                title: 'External tools',
                emptyTitle: 'No external tools',
                emptyBody:
                    'External tool definitions will appear here after the harness tool config loads them.',
                children: catalog.externalTools
                    .map(
                      (HarnessExternalToolSummary tool) => _ConfigSummaryCard(
                        title: tool.name,
                        subtitle: _joinNonEmpty(<String>[
                          tool.toolClass,
                          tool.location,
                          tool.command.join(' '),
                          tool.platformOverrideCount == 0
                              ? ''
                              : '${tool.platformOverrideCount} platform override${tool.platformOverrideCount == 1 ? '' : 's'}',
                        ]),
                        tags: <String>[
                          tool.enabled ? 'enabled' : 'disabled',
                          tool.trusted ? 'trusted' : 'untrusted',
                        ],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              _CatalogListSection(
                title: 'MCP servers',
                emptyTitle: 'No MCP servers',
                emptyBody:
                    'MCP server definitions will appear here after the harness tool config loads them.',
                children: catalog.mcpServers
                    .map(
                      (HarnessMcpServerSummary server) => _ConfigSummaryCard(
                        title: server.name,
                        subtitle: _joinNonEmpty(<String>[
                          server.lifecycle,
                          server.transport,
                          server.url,
                          server.command.join(' '),
                          server.toolNamePrefix,
                          server.platformOverrideCount == 0
                              ? ''
                              : '${server.platformOverrideCount} platform override${server.platformOverrideCount == 1 ? '' : 's'}',
                        ]),
                        tags: <String>[
                          server.enabled ? 'enabled' : 'disabled',
                          server.trusted ? 'trusted' : 'untrusted',
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );

        final editorPane = _HarnessDocumentEditor(
          title: 'Tool YAML',
          controller: _controller,
          busy: _busy,
          validation: _validation,
          onReload: _load,
          onValidate: _validate,
          onSave: _save,
        );

        if (stacked) {
          return Column(
            children: [
              Expanded(child: summaryPane),
              const SizedBox(height: 16),
              Expanded(child: editorPane),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 11, child: summaryPane),
            const SizedBox(width: 16),
            Expanded(flex: 10, child: editorPane),
          ],
        );
      },
    );
  }
}

class _HarnessDocumentEditor extends StatelessWidget {
  const _HarnessDocumentEditor({
    required this.title,
    required this.controller,
    required this.busy,
    required this.validation,
    required this.onReload,
    required this.onValidate,
    required this.onSave,
  });

  final String title;
  final TextEditingController controller;
  final bool busy;
  final HarnessConfigValidationReport? validation;
  final VoidCallback onReload;
  final VoidCallback onValidate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: title,
      fill: true,
      trailing: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : onReload,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : onValidate,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Validate'),
          ),
          FilledButton.icon(
            onPressed: busy ? null : onSave,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
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
    required this.harnessConfigApi,
    required this.harnessConfigAvailable,
  });

  final HarnessConfigApi harnessConfigApi;
  final bool harnessConfigAvailable;

  @override
  State<HarnessWorkflowsPage> createState() => _HarnessWorkflowsPageState();
}

class _HarnessWorkflowsPageState extends State<HarnessWorkflowsPage> {
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  HarnessWorkflowCatalog? _catalog;
  HarnessConfigValidationReport? _validation;
  String _selectedWorkflowName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.harnessConfigApi.getWorkflows();
      _controller.text = catalog.yaml;
      final selected =
          catalog.workflows.any(
            (HarnessWorkflowSummary workflow) =>
                workflow.name == _selectedWorkflowName,
          )
          ? _selectedWorkflowName
          : (catalog.workflows.isEmpty ? '' : catalog.workflows.first.name);
      setState(() {
        _catalog = catalog;
        _selectedWorkflowName = selected;
        _validation = null;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _validate() async {
    setState(() => _busy = true);
    try {
      final report = await widget.harnessConfigApi.validateWorkflows(
        _controller.text,
      );
      setState(() => _validation = report);
      _showMessage(report.summary);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final catalog = await widget.harnessConfigApi.saveWorkflows(
        _controller.text,
      );
      _controller.text = catalog.yaml;
      final selected =
          catalog.workflows.any(
            (HarnessWorkflowSummary workflow) =>
                workflow.name == _selectedWorkflowName,
          )
          ? _selectedWorkflowName
          : (catalog.workflows.isEmpty ? '' : catalog.workflows.first.name);
      setState(() {
        _catalog = catalog;
        _selectedWorkflowName = selected;
        _validation = null;
      });
      _showMessage('Harness workflow configuration saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    showAppMessage(context, message);
  }

  HarnessWorkflowSummary? _selectedWorkflow(HarnessWorkflowCatalog catalog) {
    for (final workflow in catalog.workflows) {
      if (workflow.name == _selectedWorkflowName) {
        return workflow;
      }
    }
    return catalog.workflows.isEmpty ? null : catalog.workflows.first;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.harnessConfigAvailable) {
      return const InfoPanel(
        title: 'Harness config unavailable',
        body:
            'This deployment mode disables local harness config management routes. Switch to local mode to manage harness workflows.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final catalog = _catalog;
    if (catalog == null) {
      return const EmptyState(
        title: 'No harness workflow data',
        body: 'The control plane returned no harness workflow document.',
      );
    }
    final selectedWorkflow = _selectedWorkflow(catalog);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1280;
        final summaryPane = PanelCard(
          title: 'Harness Workflows',
          fill: true,
          child: ListView(
            children: [
              InfoPanel(
                title: 'Config path',
                body: blankAsUnknown(catalog.configPath),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MetricCard(
                    label: 'Workflows',
                    value: '${catalog.workflows.length}',
                    tone: accentColor,
                    detail: 'Named runtime workflow definitions.',
                  ),
                  MetricCard(
                    label: 'Nodes',
                    value:
                        '${catalog.workflows.fold<int>(0, (int total, HarnessWorkflowSummary workflow) => total + workflow.nodes.length)}',
                    tone: infoColor,
                    detail: 'Total nodes across `workflow.yaml`.',
                  ),
                  MetricCard(
                    label: 'Rule sets',
                    value:
                        '${catalog.workflows.fold<int>(0, (int total, HarnessWorkflowSummary workflow) => total + workflow.ruleSets.length)}',
                    tone: successColor,
                    detail: 'Reusable policy rule set entries.',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SubsectionTitle('Workflow catalog'),
              const SizedBox(height: 10),
              if (catalog.workflows.isEmpty)
                const InfoPanel(
                  title: 'No workflows',
                  body:
                      'Workflow definitions will appear here after the harness workflow config loads them.',
                )
              else
                Column(
                  children:
                      catalog.workflows
                          .map(
                            (HarnessWorkflowSummary workflow) =>
                                _WorkflowListCard(
                                  workflow: workflow,
                                  selected:
                                      workflow.name ==
                                      (selectedWorkflow?.name ?? ''),
                                  onTap: () {
                                    setState(() {
                                      _selectedWorkflowName = workflow.name;
                                    });
                                  },
                                ),
                          )
                          .expand(
                            (Widget card) => <Widget>[
                              card,
                              const SizedBox(height: 10),
                            ],
                          )
                          .toList()
                        ..removeLast(),
                ),
              if (selectedWorkflow != null) ...[
                const SizedBox(height: 18),
                _WorkflowDetailSection(workflow: selectedWorkflow),
              ],
            ],
          ),
        );

        final editorPane = _HarnessDocumentEditor(
          title: 'Workflow YAML',
          controller: _controller,
          busy: _busy,
          validation: _validation,
          onReload: _load,
          onValidate: _validate,
          onSave: _save,
        );

        if (stacked) {
          return Column(
            children: [
              Expanded(child: summaryPane),
              const SizedBox(height: 16),
              Expanded(child: editorPane),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 11, child: summaryPane),
            const SizedBox(width: 16),
            Expanded(flex: 10, child: editorPane),
          ],
        );
      },
    );
  }
}

class _WorkflowListCard extends StatelessWidget {
  const _WorkflowListCard({
    required this.workflow,
    required this.selected,
    required this.onTap,
  });

  final HarnessWorkflowSummary workflow;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? panelRaisedColor : panelAltColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? accentColor : borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    workflow.name,
                    style: const TextStyle(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: accentColor, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _joinNonEmpty(<String>[
                workflow.startNode.isEmpty ? '' : 'start ${workflow.startNode}',
                '${workflow.nodes.length} nodes',
                workflow.ruleSets.isEmpty
                    ? ''
                    : '${workflow.ruleSets.length} rule set${workflow.ruleSets.length == 1 ? '' : 's'}',
                workflow.maxTotalTransitions == 0
                    ? ''
                    : '${workflow.maxTotalTransitions} transitions',
              ]),
              style: const TextStyle(color: textMutedColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowDetailSection extends StatelessWidget {
  const _WorkflowDetailSection({required this.workflow});

  final HarnessWorkflowSummary workflow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsectionTitle('Workflow detail'),
        const SizedBox(height: 10),
        _CatalogKeyValueSection(
          title: workflow.name,
          rows: <MapEntry<String, String>>[
            MapEntry('Start node', blankAsUnknown(workflow.startNode)),
            MapEntry(
              'Max visits per node',
              workflow.maxVisitsPerNode == 0
                  ? 'not set'
                  : '${workflow.maxVisitsPerNode}',
            ),
            MapEntry(
              'Max total transitions',
              workflow.maxTotalTransitions == 0
                  ? 'not set'
                  : '${workflow.maxTotalTransitions}',
            ),
            MapEntry(
              'Duplicate result cap',
              workflow.duplicateResultCap == 0
                  ? 'not set'
                  : '${workflow.duplicateResultCap}',
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (workflow.ruleSets.isNotEmpty) ...[
          _CatalogListSection(
            title: 'Rule sets',
            emptyTitle: 'No rule sets',
            emptyBody: 'This workflow does not declare reusable rule sets.',
            children: workflow.ruleSets
                .map(
                  (HarnessWorkflowRuleSetSummary ruleSet) => _ConfigSummaryCard(
                    title: ruleSet.name,
                    subtitle: _joinNonEmpty(<String>[
                      ruleSet.sourceKind,
                      ruleSet.basePath,
                      ruleSet.patternCount == 0
                          ? ''
                          : '${ruleSet.patternCount} patterns',
                      ruleSet.embeddedRuleCount == 0
                          ? ''
                          : '${ruleSet.embeddedRuleCount} embedded rules',
                      ruleSet.knowledgeBaseName,
                      ruleSet.knowledgeBaseVersion,
                    ]),
                    tags: <String>[
                      if (ruleSet.sourceKind.isNotEmpty) ruleSet.sourceKind,
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
        ],
        SubsectionTitle('Transition graph'),
        const SizedBox(height: 10),
        _WorkflowTransitionGraph(workflow: workflow),
        const SizedBox(height: 18),
        _CatalogListSection(
          title: 'Nodes',
          emptyTitle: 'No nodes',
          emptyBody: 'This workflow does not declare any nodes.',
          children: workflow.nodes
              .map(
                (HarnessWorkflowNodeSummary node) =>
                    _WorkflowNodeDetailCard(workflow: workflow, node: node),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _WorkflowTransitionGraph extends StatelessWidget {
  const _WorkflowTransitionGraph({required this.workflow});

  final HarnessWorkflowSummary workflow;

  @override
  Widget build(BuildContext context) {
    if (workflow.nodes.isEmpty) {
      return const InfoPanel(
        title: 'No graph',
        body: 'Workflow graph data will appear after nodes are configured.',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: workflow.nodes
            .map(
              (HarnessWorkflowNodeSummary node) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: node.id == workflow.startNode
                        ? accentColor
                        : borderColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            node.id,
                            style: const TextStyle(
                              color: textPrimaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: node.kind.isEmpty ? 'node' : node.kind,
                          color: node.kind == 'gate'
                              ? warningColor
                              : node.kind == 'finish'
                              ? successColor
                              : infoColor,
                        ),
                        if (node.id == workflow.startNode) ...[
                          const SizedBox(width: 8),
                          const StatusPill(label: 'start', color: accentColor),
                        ],
                      ],
                    ),
                    if (node.uses.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        node.uses,
                        style: const TextStyle(color: textMutedColor),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (node.transitions.targets().isEmpty)
                      const Text(
                        'No outgoing transitions.',
                        style: TextStyle(color: textSubtleColor),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: node.transitions
                            .targets()
                            .map(
                              (MapEntry<String, String> target) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: panelRaisedColor,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  '${target.key} -> ${target.value}',
                                  style: const TextStyle(
                                    color: textPrimaryColor,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _WorkflowNodeDetailCard extends StatelessWidget {
  const _WorkflowNodeDetailCard({required this.workflow, required this.node});

  final HarnessWorkflowSummary workflow;
  final HarnessWorkflowNodeSummary node;

  @override
  Widget build(BuildContext context) {
    final subtitle = _joinNonEmpty(<String>[
      node.kind,
      node.uses,
      node.maxVisits == 0 ? '' : '${node.maxVisits} max visits',
      node.maxFailures == 0 ? '' : '${node.maxFailures} max failures',
      node.implementation ? 'implementation' : '',
      node.producesGateDecision ? 'gate decision' : '',
      node.promptInstructionCount == 0
          ? ''
          : '${node.promptInstructionCount} prompt instructions',
      node.policyGateEnabled ? 'policy gate' : '',
    ]);
    final tags = <String>[
      if (node.id == workflow.startNode) 'start',
      ...node.withKeys.map((String key) => 'with:$key'),
      ...node.requiresGates.map((String gate) => 'requires:$gate'),
      ...node.includeNodeResults.map((String ref) => 'include:$ref'),
      ...node.requiredToolCalls.map((String tool) => 'tool:$tool'),
      ...node.policyGateFactBindings.map((String binding) => 'fact:$binding'),
      ...node.policyGateRouteHints.map((String hint) => 'route:$hint'),
    ];

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
            node.id,
            style: const TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: textMutedColor)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (String value) =>
                        StatusPill(label: value, color: infoColor),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          _WorkflowNodeFieldSet(
            title: 'Transitions',
            values: node.transitions
                .targets()
                .map(
                  (MapEntry<String, String> target) =>
                      '${target.key} -> ${target.value}',
                )
                .toList(),
          ),
          if (node.requiredInputKeys.isNotEmpty ||
              node.optionalInputKeys.isNotEmpty ||
              node.requiredDataKeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WorkflowNodeFieldSet(
              title: 'Contracts',
              values: <String>[
                ...node.requiredInputKeys.map(
                  (String key) => 'input required:$key',
                ),
                ...node.optionalInputKeys.map(
                  (String key) => 'input optional:$key',
                ),
                ...node.requiredDataKeys.map(
                  (String key) => 'output required:$key',
                ),
              ],
            ),
          ],
          if (node.inputMappings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WorkflowNodeFieldSet(
              title: 'Input mappings',
              values: node.inputMappings
                  .map(
                    (HarnessWorkflowInputMapSummary mapping) =>
                        _joinNonEmpty(<String>[
                          mapping.fromNode,
                          mapping.outputKey.isEmpty
                              ? ''
                              : 'output ${mapping.outputKey}',
                          mapping.inputKey.isEmpty
                              ? ''
                              : 'input ${mapping.inputKey}',
                          mapping.required ? 'required' : '',
                          mapping.overwrite ? 'overwrite' : '',
                        ]),
                  )
                  .toList(),
            ),
          ],
          if (node.gatePassStatuses.isNotEmpty ||
              node.gateFailStatuses.isNotEmpty ||
              node.gatePassExitCodes.isNotEmpty ||
              node.gateFailExitCodes.isNotEmpty ||
              node.treatRetryableAsFail) ...[
            const SizedBox(height: 12),
            _WorkflowNodeFieldSet(
              title: 'Gate policy',
              values: <String>[
                if (node.gatePassStatuses.isNotEmpty)
                  'pass statuses: ${node.gatePassStatuses.join(', ')}',
                if (node.gateFailStatuses.isNotEmpty)
                  'fail statuses: ${node.gateFailStatuses.join(', ')}',
                if (node.gatePassExitCodes.isNotEmpty)
                  'pass exit codes: ${node.gatePassExitCodes.join(', ')}',
                if (node.gateFailExitCodes.isNotEmpty)
                  'fail exit codes: ${node.gateFailExitCodes.join(', ')}',
                if (node.treatRetryableAsFail) 'retryable => fail',
              ],
            ),
          ],
          if (node.policyGateEnabled ||
              node.policyGateRuleSet.isNotEmpty ||
              node.policyGateOnEvalError.isNotEmpty ||
              node.policyGateMergeFindings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WorkflowNodeFieldSet(
              title: 'Policy gate',
              values: <String>[
                if (node.policyGateEnabled) 'enabled',
                if (node.policyGateRuleSet.isNotEmpty)
                  'rule set: ${node.policyGateRuleSet}',
                if (node.policyGateOnEvalError.isNotEmpty)
                  'on evaluation error: ${node.policyGateOnEvalError}',
                if (node.policyGateMergeFindings.isNotEmpty)
                  'merge findings: ${node.policyGateMergeFindings}',
                if (node.policyGateOverrideStatus) 'override gate status',
              ],
            ),
          ],
          if (node.requiredChangedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            _WorkflowNodeFieldSet(
              title: 'Completion contract',
              values: node.requiredChangedFiles
                  .map((String pattern) => 'changed file: $pattern')
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkflowNodeFieldSet extends StatelessWidget {
  const _WorkflowNodeFieldSet({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final filtered = values
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered
              .map(
                (String value) => StatusPill(label: value, color: warningColor),
              )
              .toList(),
        ),
      ],
    );
  }
}
