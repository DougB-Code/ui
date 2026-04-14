import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ui/provider_catalog_api.dart';

void main() {
  runApp(AgentWorkbenchApp());
}

class AgentWorkbenchApp extends StatelessWidget {
  AgentWorkbenchApp({super.key, this.providerApi});

  final ProviderCatalogApi? providerApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _success,
          surface: _surface,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
          bodyLarge: TextStyle(color: _textPrimary),
          bodyMedium: TextStyle(color: _textMuted),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surfaceAlt,
          hintStyle: const TextStyle(color: _textSubtle),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _accent),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      home: _WorkbenchShell(
        providerApi: providerApi ?? HttpProviderCatalogApi.fromEnvironment(),
      ),
    );
  }
}

const _bg = Color(0xFF171717);
const _surface = Color(0xFF232323);
const _surfaceAlt = Color(0xFF1E1E1E);
const _surfaceRaised = Color(0xFF2A2A2A);
const _border = Color(0xFF3A3A3A);
const _textPrimary = Color(0xFFF1E7DA);
const _textMuted = Color(0xFFACB1C1);
const _textSubtle = Color(0xFF7B8090);
const _accent = Color(0xFFA541F2);
const _blue = Color(0xFF2D8CFF);
const _orange = Color(0xFFFF7A21);
const _lime = Color(0xFF7EE12F);
const _success = Color(0xFF1FCF7C);
const _danger = Color(0xFFD36842);
const _warning = Color(0xFFC99337);

enum ShellSection {
  dashboard('Dashboard', Icons.grid_view_rounded),
  providers('Providers', Icons.cloud_outlined),
  agents('Agents', Icons.copy_all_rounded),
  tools('Tools', Icons.construction_rounded),
  workflows('Workflows', Icons.account_tree_outlined),
  runs('Runs', Icons.play_circle_outline_rounded),
  settings('Settings', Icons.settings_outlined);

  const ShellSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _WorkbenchShell extends StatefulWidget {
  const _WorkbenchShell({required this.providerApi});

  final ProviderCatalogApi providerApi;

  @override
  State<_WorkbenchShell> createState() => _WorkbenchShellState();
}

class _WorkbenchShellState extends State<_WorkbenchShell> {
  ShellSection _section = ShellSection.dashboard;
  bool _sidebarCollapsed = false;
  int _selectedProvider = 0;
  int _selectedAgent = 0;
  int _selectedTool = 0;
  int _selectedWorkflow = 0;
  int _selectedWorkflowNode = 0;
  String _workflowPrompt =
      'Add a manual approval gate before finish and preserve the current finish node.';
  bool _workflowListening = false;
  int _providerTab = 0;
  bool _providersLoading = true;
  bool _providerMutationInFlight = false;
  String? _providerError;
  String _providerConfigPath = '';

  final List<ProviderConfig> _providers = <ProviderConfig>[];
  late final List<AgentConfig> _agents = _seedAgents();
  late final List<ToolConfig> _tools = _seedTools();
  late final List<WorkflowConfig> _workflows = _seedWorkflows();

  ProviderConfig? get _currentProviderOrNull {
    if (_providers.isEmpty) {
      return null;
    }
    final index = _selectedProvider.clamp(0, _providers.length - 1);
    return _providers[index];
  }

  AgentConfig get _currentAgent => _agents[_selectedAgent];
  ToolConfig get _currentTool => _tools[_selectedTool];
  WorkflowConfig get _currentWorkflow => _workflows[_selectedWorkflow];
  WorkflowNodeConfig get _currentNode =>
      _currentWorkflow.nodes[_selectedWorkflowNode.clamp(
        0,
        _currentWorkflow.nodes.length - 1,
      )];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final forceCompact = constraints.maxWidth < 1080;
        final compactRail = forceCompact || _sidebarCollapsed;
        final selector = _selectorConfig();

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                _SideRail(
                  section: _section,
                  compact: compactRail,
                  onSelect: (section) => setState(() => _section = section),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
                    child: Column(
                      children: [
                        _TopBar(
                          allowCollapse: !forceCompact,
                          onMenuTap: forceCompact
                              ? null
                              : () => setState(
                                  () => _sidebarCollapsed = !_sidebarCollapsed,
                                ),
                          selectorConfig: selector,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: _buildPage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage() {
    switch (_section) {
      case ShellSection.dashboard:
        return _DashboardPage(
          key: const ValueKey('dashboard'),
          providers: _providers,
          agents: _agents,
          tools: _tools,
          workflows: _workflows,
        );
      case ShellSection.providers:
        final provider = _currentProviderOrNull;
        if (_providersLoading) {
          return const _PlaceholderPage(
            key: ValueKey('providers-loading'),
            title: 'Providers',
            description: 'Loading provider catalog from the control plane.',
          );
        }
        if (_providerError != null) {
          return _PlaceholderPage(
            key: const ValueKey('providers-error'),
            title: 'Providers',
            description: _providerError!,
          );
        }
        if (provider == null) {
          return const _PlaceholderPage(
            key: ValueKey('providers-empty'),
            title: 'Providers',
            description:
                'Create a provider to start building the harness catalog.',
          );
        }
        return _ProviderPage(
          key: const ValueKey('providers'),
          provider: provider,
          providerConfigPath: _providerConfigPath,
          tab: _providerTab,
          busy: _providerMutationInFlight,
          onTabChanged: (tab) => setState(() => _providerTab = tab),
          onChanged: () => setState(() {}),
          onSave: _saveProvider,
          onVerify: _verifyProvider,
          onDelete: _deleteProvider,
          onMarkDefault: (value) => setState(() => provider.isDefault = value),
          onAddModel: _addProviderModel,
          onDeleteModel: _deleteProviderModel,
        );
      case ShellSection.agents:
        return _AgentPage(
          key: const ValueKey('agents'),
          agent: _currentAgent,
          providers: _providers,
          onChanged: () => setState(() {}),
          onSave: () => _showBanner('Agent settings saved.'),
          onDelete: _deleteAgent,
        );
      case ShellSection.tools:
        return _ToolPage(
          key: const ValueKey('tools'),
          tool: _currentTool,
          onChanged: () => setState(() {}),
          onSave: () => _showBanner('Tool settings saved.'),
          onDelete: _deleteTool,
        );
      case ShellSection.workflows:
        return _buildWorkflowPage();
      case ShellSection.runs:
        return const _PlaceholderPage(
          key: ValueKey('runs'),
          title: 'Runs',
          description:
              'Execution timelines, approvals, and traces will fit into this shell when runtime wiring is ready.',
        );
      case ShellSection.settings:
        return const _PlaceholderPage(
          key: ValueKey('settings'),
          title: 'Settings',
          description:
              'Workspace, auth, and global runtime settings can slot into this surface later.',
        );
    }
  }

  Widget _buildWorkflowPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 1080;
        final canvas = _WorkflowCanvas(
          workflow: _currentWorkflow,
          selectedNodeId: _currentNode.id,
          onNodeSelect: (index) =>
              setState(() => _selectedWorkflowNode = index),
          onDropNewNode: _addWorkflowNode,
          onMoveNode: _moveWorkflowNode,
          onToggleConnection: _toggleWorkflowConnection,
        );
        final assistant = _WorkflowAssistantPane(
          prompt: _workflowPrompt,
          isListening: _workflowListening,
          workflow: _currentWorkflow,
          onPromptChanged: (value) => setState(() => _workflowPrompt = value),
          onToggleListening: () =>
              setState(() => _workflowListening = !_workflowListening),
          onApply: _applyWorkflowAssist,
          onCancel: () => setState(
            () => _workflowPrompt =
                'Add a manual approval gate before finish and preserve the current finish node.',
          ),
        );
        final inspector = _WorkflowInspector(
          workflow: _currentWorkflow,
          node: _currentNode,
          onNodeSelect: (index) =>
              setState(() => _selectedWorkflowNode = index),
        );

        if (singleColumn) {
          final canvasHeight = math.max(360.0, constraints.maxHeight * 0.46);
          final panelHeight = math.max(280.0, constraints.maxHeight * 0.3);

          return SingleChildScrollView(
            key: const ValueKey('workflows-vertical'),
            child: Column(
              children: [
                SizedBox(height: canvasHeight, child: canvas),
                const SizedBox(height: 14),
                SizedBox(height: panelHeight, child: assistant),
                const SizedBox(height: 14),
                SizedBox(height: panelHeight, child: inspector),
              ],
            ),
          );
        }

        return Row(
          key: const ValueKey('workflows-horizontal'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: canvas),
            const SizedBox(width: 14),
            SizedBox(
              width: 380,
              child: Column(
                children: [
                  Expanded(child: assistant),
                  const SizedBox(height: 14),
                  Expanded(child: inspector),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  _SelectorConfig? _selectorConfig() {
    switch (_section) {
      case ShellSection.providers:
        return _SelectorConfig(
          buttonLabel: _currentProviderOrNull?.alias ?? 'Providers',
          createLabel: 'New',
          searchHint: 'Search providers',
          selectedIndex: _providers.isEmpty
              ? 0
              : _selectedProvider.clamp(0, _providers.length - 1),
          onCreate: () {
            _createProvider();
          },
          onSelect: (index) => setState(() => _selectedProvider = index),
          items: [
            for (final provider in _providers)
              _SelectorItem(
                title: provider.alias,
                subtitle: provider.adapter,
                statusLabel: provider.isDefault
                    ? 'Default'
                    : provider.enabled
                    ? 'Enabled'
                    : 'Draft',
                statusColor: provider.isDefault
                    ? _blue
                    : provider.enabled
                    ? _success
                    : _warning,
              ),
          ],
        );
      case ShellSection.agents:
        return _SelectorConfig(
          buttonLabel: _currentAgent.name,
          createLabel: 'New',
          searchHint: 'Search agents',
          selectedIndex: _selectedAgent,
          onCreate: _createAgent,
          onSelect: (index) => setState(() => _selectedAgent = index),
          items: [
            for (final agent in _agents)
              _SelectorItem(
                title: agent.name,
                subtitle: '${agent.template} • ${agent.model}',
                meta: agent.stages.join(' • '),
              ),
          ],
        );
      case ShellSection.tools:
        return _SelectorConfig(
          buttonLabel: _currentTool.name,
          createLabel: 'New',
          searchHint: 'Search tools',
          selectedIndex: _selectedTool,
          onCreate: _createTool,
          onSelect: (index) => setState(() => _selectedTool = index),
          items: [
            for (final tool in _tools)
              _SelectorItem(
                title: tool.name,
                subtitle: tool.group,
                statusLabel: tool.enabled ? 'Enabled' : 'Disabled',
                statusColor: tool.enabled ? _success : _textSubtle,
              ),
          ],
        );
      case ShellSection.workflows:
        return _SelectorConfig(
          buttonLabel: _currentWorkflow.name,
          createLabel: 'New',
          searchHint: 'Search workflows',
          selectedIndex: _selectedWorkflow,
          onCreate: _createWorkflow,
          onSelect: (index) => setState(() {
            _selectedWorkflow = index;
            _selectedWorkflowNode = 0;
          }),
          items: [
            for (final workflow in _workflows)
              _SelectorItem(
                title: workflow.name,
                subtitle:
                    '${workflow.nodes.length} nodes • starts at ${workflow.startNodeId}',
                meta:
                    '${workflow.nodes.where((node) => node.kind == WorkflowNodeKind.gate).length} gates',
              ),
          ],
        );
      default:
        return null;
    }
  }

  Future<void> _loadProviders() async {
    setState(() {
      _providersLoading = true;
      _providerError = null;
    });
    try {
      final catalog = await widget.providerApi.listProviders();
      setState(() {
        _providerConfigPath = catalog.configPath;
        _providers
          ..clear()
          ..addAll(catalog.providers);
        _selectedProvider = _providers.isEmpty
            ? 0
            : _selectedProvider.clamp(0, _providers.length - 1);
        _providersLoading = false;
      });
    } on ProviderCatalogException catch (error) {
      setState(() {
        _providerError = error.message;
        _providersLoading = false;
      });
    } catch (error) {
      setState(() {
        _providerError = error.toString();
        _providersLoading = false;
      });
    }
  }

  Future<void> _createProvider() async {
    final alias = 'provider-${_providers.length + 1}';
    final draft = ProviderConfig.draft(alias: alias);
    setState(() => _providerMutationInFlight = true);
    try {
      final result = await widget.providerApi.createProvider(draft);
      setState(() {
        _providerConfigPath = result.catalog.configPath;
        _providers
          ..clear()
          ..addAll(result.catalog.providers);
        _selectedProvider = _providers.indexWhere(
          (ProviderConfig provider) => provider.alias == result.provider.alias,
        );
        if (_selectedProvider < 0) {
          _selectedProvider = 0;
        }
        _providerMutationInFlight = false;
        _providerError = null;
      });
      _showBanner('Provider created in the control plane.');
    } on ProviderCatalogException catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.message);
    } catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.toString());
    }
  }

  void _createAgent() {
    final defaultProvider = _providers.isEmpty
        ? ProviderConfig.draft(alias: 'provider-1')
        : _providers.first;
    setState(() {
      _agents.add(
        AgentConfig(
          name: 'New Agent ${_agents.length + 1}',
          template: 'Knowledge Worker',
          providerName: defaultProvider.alias,
          model: defaultProvider.primaryModelName,
          stages: ['General', 'Gate', 'Finish'],
          maxSteps: 8,
        ),
      );
      _selectedAgent = _agents.length - 1;
    });
  }

  void _createTool() {
    setState(() {
      _tools.add(
        ToolConfig(
          name: 'New Tool ${_tools.length + 1}',
          group: 'Workspace Tools',
          enabled: false,
          command: './build/agent-awesome cli run',
          description: 'Fresh tool definition ready for configuration.',
          schema: const ['goal', 'workspace_root'],
        ),
      );
      _selectedTool = _tools.length - 1;
    });
  }

  void _createWorkflow() {
    setState(() {
      _workflows.add(
        WorkflowConfig(
          name: 'new_workflow_${_workflows.length + 1}',
          startNodeId: 'plan',
          nodes: [
            WorkflowNodeConfig(
              id: 'plan',
              title: 'Plan Request',
              uses: 'planner',
              kind: WorkflowNodeKind.task,
              position: const Offset(80, 120),
              transitions: ['finish'],
            ),
            WorkflowNodeConfig(
              id: 'finish',
              title: 'Finish',
              uses: 'finisher',
              kind: WorkflowNodeKind.finish,
              position: const Offset(360, 120),
              transitions: const [],
            ),
          ],
        ),
      );
      _selectedWorkflow = _workflows.length - 1;
      _selectedWorkflowNode = 0;
    });
  }

  Future<void> _saveProvider() async {
    final provider = _currentProviderOrNull;
    if (provider == null) {
      return;
    }
    setState(() => _providerMutationInFlight = true);
    try {
      final result = await widget.providerApi.updateProvider(
        provider.persistedAlias,
        provider,
      );
      setState(() {
        _providerConfigPath = result.catalog.configPath;
        _providers
          ..clear()
          ..addAll(result.catalog.providers);
        _selectedProvider = _providers.indexWhere(
          (ProviderConfig entry) => entry.alias == result.provider.alias,
        );
        if (_selectedProvider < 0) {
          _selectedProvider = 0;
        }
        _providerMutationInFlight = false;
        _providerError = null;
      });
      _showBanner('Provider settings saved to the control plane.');
    } on ProviderCatalogException catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.message);
    } catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.toString());
    }
  }

  Future<void> _verifyProvider() async {
    final provider = _currentProviderOrNull;
    if (provider == null) {
      return;
    }
    setState(() => _providerMutationInFlight = true);
    try {
      final report = await widget.providerApi.verifyProvider(provider.alias);
      setState(() {
        provider.verificationSummary = report.summary;
        _providerMutationInFlight = false;
      });
      _showBanner(report.summary);
    } on ProviderCatalogException catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.message);
    } catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.toString());
    }
  }

  Future<void> _deleteProvider() async {
    final provider = _currentProviderOrNull;
    if (provider == null) {
      return;
    }
    setState(() => _providerMutationInFlight = true);
    try {
      final catalog = await widget.providerApi.deleteProvider(provider.alias);
      setState(() {
        _providerConfigPath = catalog.configPath;
        _providers
          ..clear()
          ..addAll(catalog.providers);
        _selectedProvider = _providers.isEmpty
            ? 0
            : math
                  .max(0, _selectedProvider - 1)
                  .clamp(0, _providers.length - 1);
        _providerMutationInFlight = false;
      });
      _showBanner('Provider deleted from the control plane.');
    } on ProviderCatalogException catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.message);
    } catch (error) {
      setState(() => _providerMutationInFlight = false);
      _showBanner(error.toString());
    }
  }

  void _addProviderModel() {
    final provider = _currentProviderOrNull;
    if (provider == null) {
      return;
    }
    setState(() {
      provider.models.add(
        ProviderModelConfig(
          name: 'model-${provider.models.length + 1}',
          enabled: false,
          accessVerified: false,
        ),
      );
    });
  }

  void _deleteProviderModel(int index) {
    final provider = _currentProviderOrNull;
    if (provider == null || index < 0 || index >= provider.models.length) {
      return;
    }
    setState(() {
      provider.models.removeAt(index);
    });
  }

  void _deleteAgent() {
    if (_agents.length == 1) {
      _showBanner('Keep at least one agent in the shell.');
      return;
    }
    setState(() {
      _agents.removeAt(_selectedAgent);
      _selectedAgent = math.max(0, _selectedAgent - 1);
    });
  }

  void _deleteTool() {
    if (_tools.length == 1) {
      _showBanner('Keep at least one tool in the shell.');
      return;
    }
    setState(() {
      _tools.removeAt(_selectedTool);
      _selectedTool = math.max(0, _selectedTool - 1);
    });
  }

  void _addWorkflowNode(WorkflowNodeKind kind, Offset offset) {
    setState(() {
      _currentWorkflow.nodes.add(
        WorkflowNodeConfig(
          id: '${kind.name}_${_currentWorkflow.nodes.length + 1}',
          title: kind.label,
          uses: kind.defaultUse,
          kind: kind,
          position: Offset(offset.dx.clamp(40, 520), offset.dy.clamp(40, 420)),
          transitions: [],
        ),
      );
      _selectedWorkflowNode = _currentWorkflow.nodes.length - 1;
    });
  }

  void _moveWorkflowNode(String nodeId, Offset offset) {
    final node = _currentWorkflow.nodes.firstWhere(
      (entry) => entry.id == nodeId,
    );
    setState(() {
      node.position = Offset(
        offset.dx.clamp(40, 520),
        offset.dy.clamp(40, 420),
      );
    });
  }

  void _applyWorkflowAssist() {
    if (_currentWorkflow.nodes.any((node) => node.id == 'manual_approval')) {
      _showBanner('Manual approval is already part of this workflow.');
      return;
    }

    setState(() {
      final approvalGateIndex = _currentWorkflow.nodes.indexWhere(
        (node) => node.id == 'approval_gate',
      );
      if (approvalGateIndex != -1) {
        _currentWorkflow.nodes[approvalGateIndex].transitions = [
          'manual_approval',
        ];
      }
      _currentWorkflow.nodes.add(
        WorkflowNodeConfig(
          id: 'manual_approval',
          title: 'Manual Approval',
          uses: 'approval_gate',
          kind: WorkflowNodeKind.gate,
          position: const Offset(420, 250),
          transitions: ['finish'],
        ),
      );
      _selectedWorkflowNode = _currentWorkflow.nodes.length - 1;
    });
    _showBanner('Workflow updated with a manual approval gate.');
  }

  void _toggleWorkflowConnection(String sourceNodeId, String targetNodeId) {
    if (sourceNodeId == targetNodeId) {
      _showBanner('A node cannot connect to itself.');
      return;
    }

    final sourceNode = _currentWorkflow.nodes.firstWhere(
      (entry) => entry.id == sourceNodeId,
    );
    final alreadyConnected = sourceNode.transitions.contains(targetNodeId);

    setState(() {
      sourceNode.transitions = alreadyConnected
          ? [
              for (final transition in sourceNode.transitions)
                if (transition != targetNodeId) transition,
            ]
          : [...sourceNode.transitions, targetNodeId];
    });

    _showBanner(
      alreadyConnected ? 'Connection removed.' : 'Connection created.',
    );
  }

  void _showBanner(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.section,
    required this.compact,
    required this.onSelect,
  });

  final ShellSection section;
  final bool compact;
  final ValueChanged<ShellSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final groups = [
      (
        title: 'Workspace',
        items: const [
          ShellSection.dashboard,
          ShellSection.providers,
          ShellSection.agents,
          ShellSection.tools,
          ShellSection.workflows,
        ],
      ),
      (
        title: 'Operations',
        items: const [ShellSection.runs, ShellSection.settings],
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: compact ? 94 : 320,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 28,
          18,
          compact ? 20 : 22,
          18,
        ),
        child: Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                const _BrandMark(),
                if (!compact) ...[
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Agent Awesome',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            for (final group in groups) ...[
              if (!compact)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 10),
                  child: Text(
                    group.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _textSubtle,
                    ),
                  ),
                ),
              for (final item in group.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RailButton(
                    compact: compact,
                    label: item.label,
                    icon: item.icon,
                    selected: item == section,
                    onTap: () => onSelect(item),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          Positioned(left: 0, top: 2, child: _MarkCircle()),
          Positioned(left: 16, top: 14, child: _MarkCircle()),
        ],
      ),
    );
  }
}

class _MarkCircle extends StatelessWidget {
  const _MarkCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.compact,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final bool compact;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _surfaceAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 54,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? _textPrimary : _textMuted),
              if (!compact) ...[
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _textPrimary : _textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.allowCollapse,
    required this.onMenuTap,
    required this.selectorConfig,
  });

  final bool allowCollapse;
  final VoidCallback? onMenuTap;
  final _SelectorConfig? selectorConfig;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _GhostIconButton(
            icon: Icons.menu_rounded,
            onTap: allowCollapse ? onMenuTap : null,
          ),
          if (selectorConfig != null) ...[
            const SizedBox(width: 14),
            _SectionSelector(config: selectorConfig!),
            const SizedBox(width: 10),
            _TopPillButton(
              label: '+ ${selectorConfig!.createLabel}',
              onTap: selectorConfig!.onCreate,
            ),
          ],
          const Spacer(),
          const _GhostIconButton(icon: Icons.search_rounded),
          const SizedBox(width: 10),
          const _GhostIconButton(icon: Icons.dark_mode_outlined),
          const SizedBox(width: 10),
          const _GhostIconButton(icon: Icons.apps_rounded),
          const SizedBox(width: 10),
          const _GhostIconButton(icon: Icons.notifications_none_rounded),
        ],
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          color: _surfaceAlt,
        ),
        child: Icon(icon, size: 20, color: _textPrimary),
      ),
    );
  }
}

class _TopPillButton extends StatelessWidget {
  const _TopPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          color: _surfaceAlt,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorConfig {
  const _SelectorConfig({
    required this.buttonLabel,
    required this.createLabel,
    required this.searchHint,
    required this.selectedIndex,
    required this.items,
    required this.onCreate,
    required this.onSelect,
  });

  final String buttonLabel;
  final String createLabel;
  final String searchHint;
  final int selectedIndex;
  final List<_SelectorItem> items;
  final VoidCallback onCreate;
  final ValueChanged<int> onSelect;
}

class _SelectorItem {
  const _SelectorItem({
    required this.title,
    required this.subtitle,
    this.meta,
    this.statusLabel,
    this.statusColor,
  });

  final String title;
  final String subtitle;
  final String? meta;
  final String? statusLabel;
  final Color? statusColor;
}

class _SectionSelector extends StatefulWidget {
  const _SectionSelector({required this.config});

  final _SelectorConfig config;

  @override
  State<_SectionSelector> createState() => _SectionSelectorState();
}

class _SectionSelectorState extends State<_SectionSelector> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SectionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.buttonLabel != widget.config.buttonLabel) {
      _removeOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleOverlay,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 320,
          child: Ink(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              color: _surface,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.config.buttonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.unfold_more_rounded, color: _textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    _controller.clear();
    _overlayEntry = OverlayEntry(
      builder: (context) => _SelectorOverlay(
        link: _layerLink,
        searchHint: widget.config.searchHint,
        controller: _controller,
        focusNode: _focusNode,
        items: widget.config.items,
        selectedIndex: widget.config.selectedIndex,
        onDismiss: _removeOverlay,
        onSelect: (index) {
          widget.config.onSelect(index);
          _removeOverlay();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _SelectorOverlay extends StatefulWidget {
  const _SelectorOverlay({
    required this.link,
    required this.searchHint,
    required this.controller,
    required this.focusNode,
    required this.items,
    required this.selectedIndex,
    required this.onDismiss,
    required this.onSelect,
  });

  final LayerLink link;
  final String searchHint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_SelectorItem> items;
  final int selectedIndex;
  final VoidCallback onDismiss;
  final ValueChanged<int> onSelect;

  @override
  State<_SelectorOverlay> createState() => _SelectorOverlayState();
}

class _SelectorOverlayState extends State<_SelectorOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim().toLowerCase();
    final filtered = <int>[];
    for (var index = 0; index < widget.items.length; index++) {
      final item = widget.items[index];
      final haystack = '${item.title} ${item.subtitle} ${item.meta ?? ''}'
          .toLowerCase();
      if (query.isEmpty || _fuzzyMatches(query, haystack)) {
        filtered.add(index);
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 380,
              constraints: const BoxConstraints(maxHeight: 420),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF202020),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No matches yet.',
                                style: TextStyle(color: _textMuted),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, filteredIndex) {
                              final index = filtered[filteredIndex];
                              final item = widget.items[index];
                              final selected = index == widget.selectedIndex;

                              return InkWell(
                                onTap: () => widget.onSelect(index),
                                borderRadius: BorderRadius.circular(14),
                                child: Ink(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _surfaceRaised
                                        : _surfaceAlt,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected ? _accent : _border,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: _textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.subtitle,
                                              style: const TextStyle(
                                                color: _textMuted,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (item.meta case final meta?) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                meta,
                                                style: const TextStyle(
                                                  color: _textSubtle,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (item.statusLabel case final status?)
                                        _StatusChip(
                                          label: status,
                                          color: item.statusColor ?? _textMuted,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _fuzzyMatches(String query, String text) {
  if (query.isEmpty) {
    return true;
  }

  var cursor = 0;
  for (final rune in text.runes) {
    if (cursor < query.length && rune == query.codeUnitAt(cursor)) {
      cursor++;
    }
  }
  return cursor == query.length;
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    super.key,
    required this.providers,
    required this.agents,
    required this.tools,
    required this.workflows,
  });

  final List<ProviderConfig> providers;
  final List<AgentConfig> agents;
  final List<ToolConfig> tools;
  final List<WorkflowConfig> workflows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Verified Providers',
                value:
                    '${providers.where((provider) => provider.enabled).length}',
                delta: '+6.32%',
                color: _accent,
                icon: Icons.cloud_done_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _StatCard(
                title: 'Active Agents',
                value: '${agents.length}',
                delta: '+12.45%',
                color: _blue,
                icon: Icons.groups_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _StatCard(
                title: 'Enabled Tools',
                value: '${tools.where((tool) => tool.enabled).length}',
                delta: '+3.12%',
                color: _orange,
                icon: Icons.work_outline_rounded,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: _StatCard(
                title: 'Workflow Coverage',
                value: '22%',
                delta: '+8.52%',
                color: _lime,
                icon: Icons.bar_chart_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PanelCard(
                  title: 'Workflow Coverage',
                  child: ListView(
                    children: [
                      _CoverageRow(
                        color: _accent,
                        value: '2',
                        label: 'Providers',
                        meta: '1 verified',
                        trend: '25%',
                        positive: true,
                      ),
                      _CoverageRow(
                        color: const Color(0xFFFFB13B),
                        value: '2',
                        label: 'Agents',
                        meta: 'gpt-5.4 primary',
                        trend: '18%',
                        positive: true,
                      ),
                      _CoverageRow(
                        color: _success,
                        value: '${workflows.length}',
                        label: 'Workflows',
                        meta: 'AI-assisted + drag/drop',
                        trend: '14%',
                        positive: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _PanelCard(
                  title: 'Execution Readiness',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            '68%',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          SizedBox(width: 14),
                          Text(
                            '↑ 25%',
                            style: TextStyle(
                              color: _success,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: CustomPaint(
                          painter: _WavePainter(),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _PanelCard(
                  title: 'Tool Traffic',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Wrap(
                        spacing: 10,
                        children: [
                          _MiniLegend(
                            color: Color(0xFF4568F0),
                            label: 'CLI Calls',
                          ),
                          _MiniLegend(
                            color: Color(0xFF22B86C),
                            label: 'Validations',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: CustomPaint(
                          painter: _BarPainter(),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderPage extends StatelessWidget {
  const _ProviderPage({
    super.key,
    required this.provider,
    required this.providerConfigPath,
    required this.tab,
    required this.busy,
    required this.onTabChanged,
    required this.onChanged,
    required this.onSave,
    required this.onVerify,
    required this.onDelete,
    required this.onMarkDefault,
    required this.onAddModel,
    required this.onDeleteModel,
  });

  final ProviderConfig provider;
  final String providerConfigPath;
  final int tab;
  final bool busy;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onVerify;
  final Future<void> Function() onDelete;
  final ValueChanged<bool> onMarkDefault;
  final VoidCallback onAddModel;
  final ValueChanged<int> onDeleteModel;

  @override
  Widget build(BuildContext context) {
    final content = switch (tab) {
      0 => _buildGeneralTab(context),
      1 => _buildStatusTab(context),
      2 => _buildModelsTab(context),
      3 => _buildVerificationTab(context),
      _ => _buildYamlTab(context),
    };
    return _DetailCard(
      title: '${provider.alias} Provider Settings',
      actions: [
        _ActionChip(
          label: busy ? 'Saving...' : 'Save',
          onTap: busy ? null : () => onSave(),
        ),
        _ActionChip(
          label: busy ? 'Working...' : 'Verify',
          onTap: busy ? null : () => onVerify(),
          fill: _success,
        ),
        _ActionChip(
          label: busy ? 'Locked' : 'Delete',
          onTap: busy ? null : () => onDelete(),
          fill: _danger,
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SegmentTabs(
              labels: const [
                'General',
                'Status',
                'Models',
                'Verification',
                'YAML',
              ],
              selectedIndex: tab,
              onSelect: onTabChanged,
            ),
            const SizedBox(height: 18),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledField(
          label: 'Provider alias',
          child: TextFormField(
            initialValue: provider.alias,
            onChanged: (value) {
              provider.alias = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Adapter',
          child: TextFormField(
            initialValue: provider.adapter,
            onChanged: (value) {
              provider.adapter = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Base URL',
          child: TextFormField(
            initialValue: provider.endpoint,
            onChanged: (value) {
              provider.endpoint = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'API key env var',
          child: TextFormField(
            initialValue: provider.apiKeyEnv,
            onChanged: (value) {
              provider.apiKeyEnv = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Allowed hosts',
          child: TextFormField(
            initialValue: provider.allowedHosts.join(', '),
            onChanged: (value) {
              provider.allowedHosts = value
                  .split(',')
                  .map((String host) => host.trim())
                  .where((String host) => host.isNotEmpty)
                  .toList();
              onChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTab(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          value: provider.enabled,
          onChanged: (value) {
            provider.enabled = value;
            onChanged();
          },
          title: const Text('Enabled'),
          subtitle: const Text(
            'Allow this provider to serve configured agents.',
          ),
        ),
        SwitchListTile(
          value: provider.isDefault,
          onChanged: (value) {
            onMarkDefault(value);
            onChanged();
          },
          title: const Text('Default provider'),
          subtitle: const Text(
            'Use this provider when the harness model selection does not override it.',
          ),
        ),
        SwitchListTile(
          value: provider.local,
          onChanged: (value) {
            provider.local = value;
            onChanged();
          },
          title: const Text('Local endpoint'),
          subtitle: const Text(
            'Allow local HTTP when talking to loopback or private hosts.',
          ),
        ),
        SwitchListTile(
          value: provider.accessVerified,
          onChanged: (value) {
            provider.accessVerified = value;
            onChanged();
          },
          title: const Text('Access verified'),
          subtitle: const Text(
            'Persist the provider-level verification bit into provider.yaml.',
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Timeout seconds',
          child: TextFormField(
            initialValue: provider.timeoutSecs == 0
                ? ''
                : provider.timeoutSecs.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              provider.timeoutSecs = int.tryParse(value.trim()) ?? 0;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'API version',
          child: TextFormField(
            initialValue: provider.apiVersion,
            onChanged: (value) {
              provider.apiVersion = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Account ID',
          child: TextFormField(
            initialValue: provider.accountId,
            onChanged: (value) {
              provider.accountId = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(height: 16),
        _LabeledField(
          label: 'Gateway ID',
          child: TextFormField(
            initialValue: provider.gatewayId,
            onChanged: (value) {
              provider.gatewayId = value;
              onChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModelsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Models', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            _ActionChip(label: 'Add model', onTap: onAddModel, fill: _blue),
          ],
        ),
        const SizedBox(height: 12),
        if (provider.models.isEmpty)
          const _InfoBox(text: 'No models configured yet.')
        else
          for (var index = 0; index < provider.models.length; index++) ...[
            _ProviderModelCard(
              model: provider.models[index],
              onChanged: onChanged,
              onDelete: () => onDeleteModel(index),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildVerificationTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live verification summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _InfoBox(text: provider.verificationSummary),
        const SizedBox(height: 16),
        if (providerConfigPath.isNotEmpty)
          _InfoBox(text: 'Config path: $providerConfigPath'),
      ],
    );
  }

  Widget _buildYamlTab(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        color: _surfaceAlt,
      ),
      child: SelectableText(
        provider.toYamlSnippet(),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: _textPrimary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _AgentPage extends StatelessWidget {
  const _AgentPage({
    super.key,
    required this.agent,
    required this.providers,
    required this.onChanged,
    required this.onSave,
    required this.onDelete,
  });

  final AgentConfig agent;
  final List<ProviderConfig> providers;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Agent Details',
      actions: [
        _ActionChip(label: 'Save', onTap: onSave),
        _ActionChip(label: 'Delete', onTap: onDelete, fill: _danger),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'Agent name',
              child: TextFormField(
                initialValue: agent.name,
                onChanged: (value) {
                  agent.name = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Template',
              child: TextFormField(
                initialValue: agent.template,
                onChanged: (value) {
                  agent.template = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Provider',
              child: DropdownButtonFormField<String>(
                initialValue:
                    providers.any(
                      (ProviderConfig provider) =>
                          provider.alias == agent.providerName,
                    )
                    ? agent.providerName
                    : null,
                items: [
                  for (final provider in providers)
                    DropdownMenuItem(
                      value: provider.alias,
                      child: Text(provider.alias),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  agent.providerName = value;
                  onChanged();
                },
                dropdownColor: _surfaceAlt,
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Model',
              child: TextFormField(
                initialValue: agent.model,
                onChanged: (value) {
                  agent.model = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 18),
            Text('Lifecycle', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final stage in agent.stages)
                  _StatusChip(
                    label: stage,
                    color: switch (stage) {
                      'General' => const Color(0xFFE0B84E),
                      'Gate' => _success,
                      'Finish' => const Color(0xFFF1546D),
                      _ => _textMuted,
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoBox(text: 'Max steps: ${agent.maxSteps}'),
          ],
        ),
      ),
    );
  }
}

class _ProviderModelCard extends StatelessWidget {
  const _ProviderModelCard({
    required this.model,
    required this.onChanged,
    required this.onDelete,
  });

  final ProviderModelConfig model;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        color: _surfaceAlt,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: model.name,
                  decoration: const InputDecoration(labelText: 'Model name'),
                  onChanged: (value) {
                    model.name = value;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _ActionChip(label: 'Delete', onTap: onDelete, fill: _danger),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: model.enabled,
            onChanged: (value) {
              model.enabled = value;
              onChanged();
            },
            title: const Text('Enabled'),
            subtitle: const Text('Allow the harness to select this model.'),
          ),
          SwitchListTile(
            value: model.accessVerified,
            onChanged: (value) {
              model.accessVerified = value;
              onChanged();
            },
            title: const Text('Access verified'),
            subtitle: const Text(
              'Persist the model-level verification bit into provider.yaml.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolPage extends StatelessWidget {
  const _ToolPage({
    super.key,
    required this.tool,
    required this.onChanged,
    required this.onSave,
    required this.onDelete,
  });

  final ToolConfig tool;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: tool.name,
      actions: [
        _ActionChip(label: 'Save', onTap: onSave),
        _ActionChip(label: 'Delete', onTap: onDelete, fill: _danger),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SegmentTabs(
              labels: const [
                'Tools',
                'Tool Groups',
                'External Tools',
                'MCP Servers',
              ],
              selectedIndex: 0,
              onSelect: (_) {},
            ),
            const SizedBox(height: 18),
            _LabeledField(
              label: 'Tool name',
              child: TextFormField(
                initialValue: tool.name,
                onChanged: (value) {
                  tool.name = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: 'Command',
              child: TextFormField(
                initialValue: tool.command,
                onChanged: (value) {
                  tool.command = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: tool.enabled,
              onChanged: (value) {
                tool.enabled = value;
                onChanged();
              },
              title: const Text('Enabled'),
              subtitle: const Text('Allow this tool to be selected by agents'),
            ),
            const SizedBox(height: 18),
            Text('Schema', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final field in tool.schema)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InfoBox(text: field),
              ),
            const SizedBox(height: 12),
            _InfoBox(text: tool.description),
          ],
        ),
      ),
    );
  }
}

class _WorkflowCanvas extends StatefulWidget {
  const _WorkflowCanvas({
    required this.workflow,
    required this.selectedNodeId,
    required this.onNodeSelect,
    required this.onDropNewNode,
    required this.onMoveNode,
    required this.onToggleConnection,
  });

  final WorkflowConfig workflow;
  final String selectedNodeId;
  final ValueChanged<int> onNodeSelect;
  final void Function(WorkflowNodeKind kind, Offset offset) onDropNewNode;
  final void Function(String nodeId, Offset offset) onMoveNode;
  final void Function(String sourceNodeId, String targetNodeId)
  onToggleConnection;

  @override
  State<_WorkflowCanvas> createState() => _WorkflowCanvasState();
}

class _WorkflowCanvasState extends State<_WorkflowCanvas> {
  static const double _nodeWidth = 164;
  static const double _nodeHeight = 78;
  static const double _nodePaddingX = 24;
  static const double _nodePaddingY = 24;

  final GlobalKey _canvasKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  String? _linkSourceNodeId;
  String? _hoverTargetNodeId;
  Offset? _linkPointerLocalOffset;
  _WorkflowEdgeRef? _selectedEdge;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WorkflowCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedEdge = _selectedEdge;
    if (selectedEdge != null && !_edgeExists(selectedEdge)) {
      _selectedEdge = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final title = Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(
                      widget.workflow.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _StatusChip(
                      label: 'Start: ${widget.workflow.startNodeId}',
                      color: _accent,
                    ),
                  ],
                );
                final controls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _GhostIconButton(icon: Icons.zoom_in_map_outlined),
                    _GhostIconButton(icon: Icons.alt_route_rounded),
                    _GhostIconButton(icon: Icons.auto_fix_high_outlined),
                    _GhostIconButton(icon: Icons.lock_outline_rounded),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), controls],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    controls,
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return DragTarget<_CanvasPayload>(
                  onAcceptWithDetails: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) {
                      return;
                    }
                    final offset = box.globalToLocal(details.offset);
                    final payload = details.data;
                    switch (payload) {
                      case _NewNodePayload(kind: final kind):
                        widget.onDropNewNode(kind, offset);
                      case _MoveNodePayload(nodeId: final nodeId):
                        widget.onMoveNode(nodeId, offset);
                      case _LinkNodePayload():
                        break;
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Focus(
                      focusNode: _focusNode,
                      onKeyEvent: _handleCanvasKey,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _handleCanvasTap(
                          details.localPosition,
                          constraints,
                        ),
                        child: Container(
                          key: _canvasKey,
                          color: _surfaceAlt,
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: Size.infinite,
                                painter: _WorkflowEdgePainter(
                                  workflow: widget.workflow,
                                  selectedNodeId: widget.selectedNodeId,
                                  selectedEdge: _selectedEdge,
                                  previewStart: _previewStart(constraints),
                                  previewEnd: _linkPointerLocalOffset,
                                ),
                              ),
                              for (
                                var index = 0;
                                index < widget.workflow.nodes.length;
                                index++
                              )
                                Positioned(
                                  left: _clampedNodePosition(
                                    widget.workflow.nodes[index],
                                    constraints,
                                  ).dx,
                                  top: _clampedNodePosition(
                                    widget.workflow.nodes[index],
                                    constraints,
                                  ).dy,
                                  child: _CanvasNode(
                                    node: widget.workflow.nodes[index],
                                    selected:
                                        widget.workflow.nodes[index].id ==
                                        widget.selectedNodeId,
                                    highlightedTarget:
                                        widget.workflow.nodes[index].id ==
                                            _hoverTargetNodeId &&
                                        widget.workflow.nodes[index].id !=
                                            _linkSourceNodeId,
                                    linking:
                                        widget.workflow.nodes[index].id ==
                                        _linkSourceNodeId,
                                    onTap: () {
                                      _focusNode.requestFocus();
                                      setState(() => _selectedEdge = null);
                                      widget.onNodeSelect(index);
                                    },
                                    onLinkDragStart: _handleLinkDragStart,
                                    onLinkDragUpdate: _handleLinkDragUpdate,
                                    onLinkDragEnd: () =>
                                        _handleLinkDragEnd(constraints),
                                  ),
                                ),
                              Positioned(
                                left: 18,
                                bottom: 18,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xCC171A20),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Text(
                                    _selectedEdge == null
                                        ? 'Drag a node handle onto another node to connect it, or drag onto the same target again to disconnect.'
                                        : 'Selected connection: ${_selectedEdge!.sourceNodeId} -> ${_selectedEdge!.targetNodeId}. Press Delete to remove.',
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleLinkDragStart(String sourceNodeId, Offset globalPosition) {
    _focusNode.requestFocus();
    setState(() {
      _selectedEdge = null;
      _linkSourceNodeId = sourceNodeId;
      _linkPointerLocalOffset = _globalToCanvasLocal(globalPosition);
      _hoverTargetNodeId = _findHoveredNodeId(_linkPointerLocalOffset);
    });
  }

  void _handleLinkDragUpdate(Offset globalPosition) {
    setState(() {
      _linkPointerLocalOffset = _globalToCanvasLocal(globalPosition);
      _hoverTargetNodeId = _findHoveredNodeId(_linkPointerLocalOffset);
    });
  }

  void _handleLinkDragEnd(BoxConstraints constraints) {
    final sourceNodeId = _linkSourceNodeId;
    final targetNodeId = _hoverTargetNodeId;
    if (sourceNodeId != null &&
        targetNodeId != null &&
        sourceNodeId != targetNodeId) {
      widget.onToggleConnection(sourceNodeId, targetNodeId);
      final toggledEdge = _WorkflowEdgeRef(sourceNodeId, targetNodeId);
      final stillExists = _edgeExists(toggledEdge);
      _selectedEdge = stillExists ? toggledEdge : null;
    }

    setState(() {
      _linkSourceNodeId = null;
      _hoverTargetNodeId = null;
      _linkPointerLocalOffset = null;
    });
  }

  Offset? _globalToCanvasLocal(Offset globalPosition) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(globalPosition);
  }

  Offset _clampedNodePosition(
    WorkflowNodeConfig node,
    BoxConstraints constraints,
  ) {
    return Offset(
      node.position.dx.clamp(
        _nodePaddingX,
        math.max(_nodePaddingX, constraints.maxWidth - 190),
      ),
      node.position.dy.clamp(
        _nodePaddingY,
        math.max(_nodePaddingY, constraints.maxHeight - 94),
      ),
    );
  }

  String? _findHoveredNodeId(Offset? localOffset) {
    if (localOffset == null) {
      return null;
    }

    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) {
      return null;
    }

    final constraints = BoxConstraints.tight(box.size);
    for (final node in widget.workflow.nodes) {
      final position = _clampedNodePosition(node, constraints);
      final rect = Rect.fromLTWH(
        position.dx,
        position.dy,
        _nodeWidth,
        _nodeHeight,
      );
      if (rect.contains(localOffset)) {
        return node.id;
      }
    }
    return null;
  }

  Offset? _previewStart(BoxConstraints constraints) {
    final sourceNodeId = _linkSourceNodeId;
    if (sourceNodeId == null) {
      return null;
    }
    WorkflowNodeConfig? sourceNode;
    for (final entry in widget.workflow.nodes) {
      if (entry.id == sourceNodeId) {
        sourceNode = entry;
        break;
      }
    }
    if (sourceNode == null) {
      return null;
    }
    final position = _clampedNodePosition(sourceNode, constraints);
    return Offset(position.dx + _nodeWidth, position.dy + (_nodeHeight / 2));
  }

  void _handleCanvasTap(Offset localPosition, BoxConstraints constraints) {
    _focusNode.requestFocus();
    final selectedEdge = _findEdgeAt(localPosition, constraints);
    setState(() {
      _selectedEdge = selectedEdge;
    });
  }

  KeyEventResult _handleCanvasKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final selectedEdge = _selectedEdge;
    if (selectedEdge == null) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      widget.onToggleConnection(
        selectedEdge.sourceNodeId,
        selectedEdge.targetNodeId,
      );
      setState(() => _selectedEdge = null);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  _WorkflowEdgeRef? _findEdgeAt(
    Offset localPosition,
    BoxConstraints constraints,
  ) {
    _WorkflowEdgeRef? closestEdge;
    var closestDistance = double.infinity;

    for (final node in widget.workflow.nodes) {
      final startPosition = _clampedNodePosition(node, constraints);
      final start = Offset(
        startPosition.dx + _nodeWidth,
        startPosition.dy + (_nodeHeight / 2),
      );

      for (final targetId in node.transitions) {
        WorkflowNodeConfig? target;
        for (final entry in widget.workflow.nodes) {
          if (entry.id == targetId) {
            target = entry;
            break;
          }
        }
        if (target == null) {
          continue;
        }

        final endPosition = _clampedNodePosition(target, constraints);
        final end = Offset(endPosition.dx, endPosition.dy + (_nodeHeight / 2));
        final distance = _distanceToBezier(localPosition, start, end);
        if (distance < 12 && distance < closestDistance) {
          closestDistance = distance;
          closestEdge = _WorkflowEdgeRef(node.id, targetId);
        }
      }
    }

    return closestEdge;
  }

  double _distanceToBezier(Offset point, Offset start, Offset end) {
    final mid = (start.dx + end.dx) / 2;
    var minDistance = double.infinity;

    for (var step = 0; step <= 24; step++) {
      final t = step / 24;
      final sample = _sampleCubic(
        start,
        Offset(mid, start.dy),
        Offset(mid, end.dy),
        end,
        t,
      );
      final distance = (sample - point).distance;
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  Offset _sampleCubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1 - t;
    return Offset(
      (mt * mt * mt * p0.dx) +
          (3 * mt * mt * t * p1.dx) +
          (3 * mt * t * t * p2.dx) +
          (t * t * t * p3.dx),
      (mt * mt * mt * p0.dy) +
          (3 * mt * mt * t * p1.dy) +
          (3 * mt * t * t * p2.dy) +
          (t * t * t * p3.dy),
    );
  }

  bool _edgeExists(_WorkflowEdgeRef edge) {
    for (final node in widget.workflow.nodes) {
      if (node.id == edge.sourceNodeId &&
          node.transitions.contains(edge.targetNodeId)) {
        return true;
      }
    }
    return false;
  }
}

class _WorkflowAssistantPane extends StatelessWidget {
  const _WorkflowAssistantPane({
    required this.prompt,
    required this.isListening,
    required this.workflow,
    required this.onPromptChanged,
    required this.onToggleListening,
    required this.onApply,
    required this.onCancel,
  });

  final String prompt;
  final bool isListening;
  final WorkflowConfig workflow;
  final ValueChanged<String> onPromptChanged;
  final VoidCallback onToggleListening;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final hasApproval = workflow.nodes.any(
      (node) => node.id == 'manual_approval',
    );
    final preview = hasApproval
        ? const [
            'Manual approval already exists in the workflow.',
            'AI Assist is ready for the next edit request.',
          ]
        : const [
            'Insert a "Manual Approval" gate before the finish state.',
            'Connect success and blocked transitions into the new gate.',
            'Keep the existing finish node intact for final handoff.',
          ];

    return _ShellCard(
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: _accent),
                Text(
                  'AI Assist',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _StatusChip(
                  label: isListening ? 'Listening' : 'Ready',
                  color: isListening ? _warning : _success,
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: prompt,
              minLines: 3,
              maxLines: 4,
              onChanged: onPromptChanged,
              decoration: const InputDecoration(
                hintText:
                    'Describe the workflow change you want, or use the mic to dictate it.',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onToggleListening,
                  icon: Icon(
                    isListening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                  ),
                  label: Text(isListening ? 'Stop capture' : 'Voice input'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _InfoBox(
              text:
                  'Voice remains first-class in the UI even before speech-to-text is wired in.',
            ),
            const SizedBox(height: 18),
            Text(
              'Preview changes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            for (final item in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 18,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: _textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onApply,
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowInspector extends StatelessWidget {
  const _WorkflowInspector({
    required this.workflow,
    required this.node,
    required this.onNodeSelect,
  });

  final WorkflowConfig workflow;
  final WorkflowNodeConfig node;
  final ValueChanged<int> onNodeSelect;

  @override
  Widget build(BuildContext context) {
    final connectedNodes = [
      for (final targetId in node.transitions)
        for (final entry in workflow.nodes)
          if (entry.id == targetId) entry,
    ].whereType<WorkflowNodeConfig>().toList();
    return _ShellCard(
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: [
          Text('Inspector', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _StatusChip(label: workflow.name, color: _accent),
          const SizedBox(height: 18),
          Text('Node palette', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _PaletteNode(kind: WorkflowNodeKind.task),
              _PaletteNode(kind: WorkflowNodeKind.gate),
              _PaletteNode(kind: WorkflowNodeKind.finish),
            ],
          ),
          const SizedBox(height: 18),
          Text('Selected node', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${node.kind.label} • uses ${node.uses}',
                  style: const TextStyle(color: _textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  '${connectedNodes.length} outgoing connection${connectedNodes.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: _textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _InfoBox(
            text:
                'Drag the small link handle on the right edge of a node onto another node to create a connection. Drop it on the same target again to remove that connection.',
          ),
          const SizedBox(height: 18),
          Text('Connected to', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (connectedNodes.isEmpty)
            const _InfoBox(
              text:
                  'No outgoing connections yet. Drag from this node\'s link handle onto another node in the canvas to create one.',
            )
          else
            for (final target in connectedNodes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        target.kind.icon,
                        size: 18,
                        color: target.kind.color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.title,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              target.id,
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 18),
          Text('Node order', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (var index = 0; index < workflow.nodes.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onNodeSelect(index),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: workflow.nodes[index].id == node.id
                        ? _surfaceRaised
                        : _surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: workflow.nodes[index].id == node.id
                          ? _accent
                          : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        workflow.nodes[index].kind.icon,
                        size: 18,
                        color: workflow.nodes[index].kind.color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          workflow.nodes[index].title,
                          style: const TextStyle(color: _textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.actions,
    required this.child,
  });

  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 24),
                ),
              ),
              const SizedBox(width: 16),
              Wrap(spacing: 10, children: actions),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap, this.fill});

  final String label;
  final VoidCallback? onTap;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final filled = fill != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: onTap == null ? _surfaceRaised : fill ?? _surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: filled ? Colors.transparent : _border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? _textSubtle
                  : filled
                  ? Colors.white
                  : _textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var index = 0; index < labels.length; index++)
          InkWell(
            onTap: () => onSelect(index),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: index == selectedIndex ? _surfaceRaised : _surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: index == selectedIndex ? _accent : _border,
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: index == selectedIndex ? _textPrimary : _textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _textMuted, height: 1.45),
      ),
    );
  }
}

class _ShellCard extends StatelessWidget {
  const _ShellCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.delta,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String delta;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              Text(
                delta,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Icon(Icons.more_horiz_rounded, color: _textPrimary),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.color,
    required this.value,
    required this.label,
    required this.meta,
    required this.trend,
    required this.positive,
  });

  final Color color;
  final String value;
  final String label;
  final String meta;
  final String trend;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: const Icon(
              Icons.blur_on_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                Text(label, style: const TextStyle(color: _textPrimary)),
                Text(meta, style: const TextStyle(color: _textMuted)),
              ],
            ),
          ),
          Text(
            '${positive ? '↑' : '↓'} $trend',
            style: TextStyle(
              color: positive ? _success : const Color(0xFFF1546D),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLegend extends StatelessWidget {
  const _MiniLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _textMuted)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return _ShellCard(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers_clear_outlined, size: 48, color: _accent),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

sealed class _CanvasPayload {
  const _CanvasPayload();
}

class _NewNodePayload extends _CanvasPayload {
  const _NewNodePayload(this.kind);

  final WorkflowNodeKind kind;
}

class _MoveNodePayload extends _CanvasPayload {
  const _MoveNodePayload(this.nodeId);

  final String nodeId;
}

class _LinkNodePayload extends _CanvasPayload {
  const _LinkNodePayload(this.sourceNodeId);

  final String sourceNodeId;
}

enum WorkflowNodeKind {
  task('Task', Icons.circle_outlined, _blue, 'worker'),
  gate('Gate', Icons.alt_route_rounded, _accent, 'approval_gate'),
  finish('Finish', Icons.flag_outlined, Color(0xFFF1546D), 'finisher');

  const WorkflowNodeKind(this.label, this.icon, this.color, this.defaultUse);

  final String label;
  final IconData icon;
  final Color color;
  final String defaultUse;
}

class _PaletteNode extends StatelessWidget {
  const _PaletteNode({required this.kind});

  final WorkflowNodeKind kind;

  @override
  Widget build(BuildContext context) {
    return Draggable<_CanvasPayload>(
      data: _NewNodePayload(kind),
      feedback: Material(
        color: Colors.transparent,
        child: _NodeBadge(kind: kind, elevated: true),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _NodeBadge(kind: kind)),
      child: _NodeBadge(kind: kind),
    );
  }
}

class _NodeBadge extends StatelessWidget {
  const _NodeBadge({required this.kind, this.elevated = false});

  final WorkflowNodeKind kind;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kind.color.withValues(alpha: 0.7)),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 18, color: kind.color),
          const SizedBox(width: 8),
          Text(kind.label, style: const TextStyle(color: _textPrimary)),
        ],
      ),
    );
  }
}

class _CanvasNode extends StatelessWidget {
  const _CanvasNode({
    required this.node,
    required this.selected,
    required this.highlightedTarget,
    required this.linking,
    required this.onTap,
    required this.onLinkDragStart,
    required this.onLinkDragUpdate,
    required this.onLinkDragEnd,
  });

  final WorkflowNodeConfig node;
  final bool selected;
  final bool highlightedTarget;
  final bool linking;
  final VoidCallback onTap;
  final void Function(String sourceNodeId, Offset globalPosition)
  onLinkDragStart;
  final ValueChanged<Offset> onLinkDragUpdate;
  final VoidCallback onLinkDragEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Draggable<_CanvasPayload>(
          data: _MoveNodePayload(node.id),
          feedback: Material(
            color: Colors.transparent,
            child: _CanvasNodeCard(node: node, selected: true),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _CanvasNodeCard(
              node: node,
              selected: selected,
              highlightedTarget: highlightedTarget,
            ),
          ),
          child: GestureDetector(
            key: ValueKey('canvas-node-${node.id}'),
            onTap: onTap,
            child: _CanvasNodeCard(
              node: node,
              selected: selected,
              highlightedTarget: highlightedTarget,
            ),
          ),
        ),
        Positioned(
          left: -7,
          top: 28,
          child: _ConnectorSocket(
            color: node.kind.color,
            highlighted: highlightedTarget,
          ),
        ),
        Positioned(
          right: 6,
          top: 22,
          child: GestureDetector(
            key: ValueKey('connector-source-${node.id}'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) =>
                onLinkDragStart(node.id, details.globalPosition),
            onPanUpdate: (details) => onLinkDragUpdate(details.globalPosition),
            onPanEnd: (_) => onLinkDragEnd(),
            onPanCancel: onLinkDragEnd,
            child: _ConnectorHandle(
              color: node.kind.color,
              active: selected || linking,
            ),
          ),
        ),
      ],
    );
  }
}

class _CanvasNodeCard extends StatelessWidget {
  const _CanvasNodeCard({
    required this.node,
    required this.selected,
    this.highlightedTarget = false,
  });

  final WorkflowNodeConfig node;
  final bool selected;
  final bool highlightedTarget;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 164,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? _surfaceRaised : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightedTarget
              ? node.kind.color
              : (selected ? _accent : _border),
          width: highlightedTarget ? 1.6 : 1,
        ),
        boxShadow: highlightedTarget
            ? [
                BoxShadow(
                  color: node.kind.color.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(node.kind.icon, size: 18, color: node.kind.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            node.uses,
            style: const TextStyle(color: _textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ConnectorHandle extends StatelessWidget {
  const _ConnectorHandle({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _surface,
        border: Border.all(
          color: active ? color : color.withValues(alpha: 0.65),
          width: 2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(Icons.add_link_rounded, size: 11, color: color),
    );
  }
}

class _ConnectorSocket extends StatelessWidget {
  const _ConnectorSocket({required this.color, required this.highlighted});

  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? color.withValues(alpha: 0.2) : _surfaceAlt,
        border: Border.all(
          color: highlighted ? color : color.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
    );
  }
}

class _WorkflowEdgeRef {
  const _WorkflowEdgeRef(this.sourceNodeId, this.targetNodeId);

  final String sourceNodeId;
  final String targetNodeId;

  @override
  bool operator ==(Object other) {
    return other is _WorkflowEdgeRef &&
        other.sourceNodeId == sourceNodeId &&
        other.targetNodeId == targetNodeId;
  }

  @override
  int get hashCode => Object.hash(sourceNodeId, targetNodeId);
}

class _WorkflowEdgePainter extends CustomPainter {
  const _WorkflowEdgePainter({
    required this.workflow,
    required this.selectedNodeId,
    this.selectedEdge,
    this.previewStart,
    this.previewEnd,
  });

  final WorkflowConfig workflow;
  final String selectedNodeId;
  final _WorkflowEdgeRef? selectedEdge;
  final Offset? previewStart;
  final Offset? previewEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeById = {for (final node in workflow.nodes) node.id: node};

    for (final node in workflow.nodes) {
      for (final targetId in node.transitions) {
        final target = nodeById[targetId];
        if (target == null) {
          continue;
        }

        final edgeRef = _WorkflowEdgeRef(node.id, target.id);
        final selected = edgeRef == selectedEdge;
        final highlighted =
            selected ||
            node.id == selectedNodeId ||
            target.id == selectedNodeId;
        final stroke = Paint()
          ..color = selected
              ? const Color(0xFFFFC65C)
              : (highlighted
                    ? _accent.withValues(alpha: 0.82)
                    : const Color(0x44A541F2))
          ..strokeWidth = selected ? 4 : (highlighted ? 2.6 : 2)
          ..style = PaintingStyle.stroke;

        final start = Offset(node.position.dx + 164, node.position.dy + 36);
        final end = Offset(target.position.dx, target.position.dy + 36);
        final mid = (start.dx + end.dx) / 2;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
        canvas.drawPath(path, stroke);

        final arrowPaint = Paint()
          ..color = stroke.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          end,
          selected ? 5.2 : (highlighted ? 4.2 : 3.4),
          arrowPaint,
        );
      }
    }

    if (previewStart != null && previewEnd != null) {
      final previewPaint = Paint()
        ..color = _accent.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final start = previewStart!;
      final end = previewEnd!;
      final mid = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(mid, start.dy, mid, end.dy, end.dx, end.dy);
      canvas.drawPath(path, previewPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WorkflowEdgePainter oldDelegate) {
    return oldDelegate.workflow != workflow ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.selectedEdge != selectedEdge ||
        oldDelegate.previewStart != previewStart ||
        oldDelegate.previewEnd != previewEnd;
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, size.height * 0.8);
    path.cubicTo(
      size.width * 0.15,
      size.height * 0.82,
      size.width * 0.2,
      size.height * 0.12,
      size.width * 0.38,
      size.height * 0.24,
    );
    path.cubicTo(
      size.width * 0.55,
      size.height * 0.4,
      size.width * 0.56,
      size.height * 0.9,
      size.width * 0.72,
      size.height * 0.62,
    );
    path.cubicTo(
      size.width * 0.84,
      size.height * 0.42,
      size.width * 0.9,
      size.height * 0.24,
      size.width,
      size.height * 0.8,
    );

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x55A541F2), Color(0x11232323)],
      ).createShader(Offset.zero & size);

    final stroke = Paint()
      ..color = _accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _border
      ..strokeWidth = 1;
    final blue = Paint()
      ..color = const Color(0xFF4568F0)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    final green = Paint()
      ..color = const Color(0xFF22B86C)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;

    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), grid);
    }

    final valuesA = [0.2, 0.35, 0.78, 0.2, 0.35, 0.5];
    final valuesB = [0.28, 0.42, 0.7, 0.48, 0.58, 0.15];

    for (var i = 0; i < valuesA.length; i++) {
      final x = 52 + i * ((size.width - 104) / (valuesA.length - 1));
      canvas.drawLine(
        Offset(x, size.height * 0.72),
        Offset(x, size.height * (0.72 - valuesA[i] * 0.6)),
        blue,
      );
      canvas.drawLine(
        Offset(x + 18, size.height * 0.74),
        Offset(x + 18, size.height * (0.74 + valuesB[i] * 0.45)),
        green,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AgentConfig {
  AgentConfig({
    required this.name,
    required this.template,
    required this.providerName,
    required this.model,
    required this.stages,
    required this.maxSteps,
  });

  String name;
  String template;
  String providerName;
  String model;
  List<String> stages;
  int maxSteps;
}

class ToolConfig {
  ToolConfig({
    required this.name,
    required this.group,
    required this.enabled,
    required this.command,
    required this.description,
    required this.schema,
  });

  String name;
  String group;
  bool enabled;
  String command;
  String description;
  List<String> schema;
}

class WorkflowConfig {
  WorkflowConfig({
    required this.name,
    required this.startNodeId,
    required this.nodes,
  });

  String name;
  String startNodeId;
  List<WorkflowNodeConfig> nodes;
}

class WorkflowNodeConfig {
  WorkflowNodeConfig({
    required this.id,
    required this.title,
    required this.uses,
    required this.kind,
    required this.position,
    required this.transitions,
  });

  String id;
  String title;
  String uses;
  WorkflowNodeKind kind;
  Offset position;
  List<String> transitions;
}

List<AgentConfig> _seedAgents() => [
  AgentConfig(
    name: 'Research Assistant',
    template: 'Knowledge Worker',
    providerName: 'openai-prod',
    model: 'gpt-5.4',
    stages: ['General', 'Gate', 'Finish'],
    maxSteps: 8,
  ),
  AgentConfig(
    name: 'Change Implementer',
    template: 'Execution Worker',
    providerName: 'openai-prod',
    model: 'gpt-5.4-mini',
    stages: ['General', 'Finish'],
    maxSteps: 12,
  ),
];

List<ToolConfig> _seedTools() => [
  ToolConfig(
    name: 'Web Search Tool',
    group: 'Web, API Tools',
    enabled: true,
    command: './build/agent-awesome cli search',
    description:
        'Search across public web content and return ranked source snippets.',
    schema: ['query', 'domains', 'recency'],
  ),
  ToolConfig(
    name: 'Workspace Editor',
    group: 'Workspace Tools',
    enabled: true,
    command: './build/agent-awesome cli edit',
    description:
        'Read and patch local workspace files with audit-friendly changes.',
    schema: ['path', 'patch'],
  ),
];

List<WorkflowConfig> _seedWorkflows() => [
  WorkflowConfig(
    name: 'governed_change_execution',
    startNodeId: 'triage',
    nodes: [
      WorkflowNodeConfig(
        id: 'triage',
        title: 'Triage Request',
        uses: 'planner',
        kind: WorkflowNodeKind.task,
        position: const Offset(48, 130),
        transitions: ['plan'],
      ),
      WorkflowNodeConfig(
        id: 'plan',
        title: 'Plan Change',
        uses: 'planner',
        kind: WorkflowNodeKind.task,
        position: const Offset(270, 130),
        transitions: ['approval_gate'],
      ),
      WorkflowNodeConfig(
        id: 'approval_gate',
        title: 'Approval Gate',
        uses: 'approver',
        kind: WorkflowNodeKind.gate,
        position: const Offset(520, 130),
        transitions: ['finish'],
      ),
      WorkflowNodeConfig(
        id: 'finish',
        title: 'Finish',
        uses: 'finisher',
        kind: WorkflowNodeKind.finish,
        position: const Offset(740, 130),
        transitions: const [],
      ),
    ],
  ),
  WorkflowConfig(
    name: 'research_then_build',
    startNodeId: 'research',
    nodes: [
      WorkflowNodeConfig(
        id: 'research',
        title: 'Research',
        uses: 'researcher',
        kind: WorkflowNodeKind.task,
        position: const Offset(60, 220),
        transitions: ['build'],
      ),
      WorkflowNodeConfig(
        id: 'build',
        title: 'Build',
        uses: 'implementer',
        kind: WorkflowNodeKind.task,
        position: const Offset(310, 220),
        transitions: ['finish'],
      ),
      WorkflowNodeConfig(
        id: 'finish',
        title: 'Finish',
        uses: 'finisher',
        kind: WorkflowNodeKind.finish,
        position: const Offset(580, 220),
        transitions: const [],
      ),
    ],
  ),
];
