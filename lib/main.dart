import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ui/control_plane_api.dart';
import 'package:ui/operations_api.dart';
import 'package:ui/provider_catalog_api.dart';

void main() {
  runApp(
    AgentAwesomeBetaApp(
      controlPlaneBaseUrl: const String.fromEnvironment(
        'CONTROL_PLANE_BASE_URL',
        defaultValue: 'http://127.0.0.1:8080',
      ),
      controlPlaneApi: HttpControlPlaneApi.fromEnvironment(),
      operationsApi: HttpOperationsApi.fromEnvironment(),
      providerApi: HttpProviderCatalogApi.fromEnvironment(),
    ),
  );
}

class AgentAwesomeBetaApp extends StatelessWidget {
  const AgentAwesomeBetaApp({
    super.key,
    required this.controlPlaneBaseUrl,
    required this.controlPlaneApi,
    required this.operationsApi,
    required this.providerApi,
  });

  final String controlPlaneBaseUrl;
  final ControlPlaneApi controlPlaneApi;
  final OperationsApi operationsApi;
  final ProviderCatalogApi providerApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _info,
          surface: _panel,
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
          bodyMedium: TextStyle(color: _textMuted, height: 1.45),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panelAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accent),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
      home: _BetaShell(
        controlPlaneBaseUrl: controlPlaneBaseUrl,
        controlPlaneApi: controlPlaneApi,
        operationsApi: operationsApi,
        providerApi: providerApi,
      ),
    );
  }
}

const _bg = Color(0xFF10151C);
const _panel = Color(0xFF17202B);
const _panelAlt = Color(0xFF1D2835);
const _panelRaised = Color(0xFF233142);
const _border = Color(0xFF324355);
const _textPrimary = Color(0xFFF4F7FA);
const _textMuted = Color(0xFFB8C4D3);
const _textSubtle = Color(0xFF7E8DA0);
const _accent = Color(0xFFE28A2B);
const _info = Color(0xFF3BA0FF);
const _success = Color(0xFF26C281);
const _warning = Color(0xFFF4B942);
const _danger = Color(0xFFE25C5C);

enum AppSection {
  runs('Runs', Icons.play_circle_outline_rounded),
  artifacts('Artifacts', Icons.inventory_2_outlined),
  audits('Audits', Icons.gavel_outlined),
  controlPlane('Control Plane', Icons.hub_outlined),
  providers('Providers', Icons.cloud_outlined);

  const AppSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _BetaShell extends StatefulWidget {
  const _BetaShell({
    required this.controlPlaneBaseUrl,
    required this.controlPlaneApi,
    required this.operationsApi,
    required this.providerApi,
  });

  final String controlPlaneBaseUrl;
  final ControlPlaneApi controlPlaneApi;
  final OperationsApi operationsApi;
  final ProviderCatalogApi providerApi;

  @override
  State<_BetaShell> createState() => _BetaShellState();
}

class _BetaShellState extends State<_BetaShell> {
  AppSection _section = AppSection.runs;
  String? _pendingRunSelection;
  final _deploymentMode = const String.fromEnvironment(
    'CONTROL_PLANE_DEPLOYMENT',
    defaultValue: 'local',
  ).toLowerCase();

  void _openRun(String runId) {
    setState(() {
      _section = AppSection.runs;
      _pendingRunSelection = runId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_section) {
      AppSection.runs => _RunsPage(
        operationsApi: widget.operationsApi,
        initialRunId: _pendingRunSelection,
      ),
      AppSection.artifacts => _ArtifactsPage(operationsApi: widget.operationsApi),
      AppSection.audits => _AuditsPage(operationsApi: widget.operationsApi),
      AppSection.controlPlane => _ControlPlanePage(
        controlPlaneApi: widget.controlPlaneApi,
        operationsApi: widget.operationsApi,
      ),
      AppSection.providers => _ProvidersPage(
        providerApi: widget.providerApi,
        providerCatalogAvailable: _deploymentMode != 'cloudflare',
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              selected: _section,
              onSelect: (AppSection section) {
                setState(() {
                  _section = section;
                  if (section != AppSection.runs) {
                    _pendingRunSelection = null;
                  }
                });
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderBar(
                      section: _section,
                      controlPlaneBaseUrl: widget.controlPlaneBaseUrl,
                      deploymentMode: _deploymentMode,
                    ),
                    const SizedBox(height: 18),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0D131A),
        border: Border(right: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 24),
          const _NavLabel('Operations'),
          const SizedBox(height: 8),
          _NavButton(
            section: AppSection.runs,
            selected: selected == AppSection.runs,
            onTap: onSelect,
          ),
          const SizedBox(height: 8),
          _NavButton(
            section: AppSection.artifacts,
            selected: selected == AppSection.artifacts,
            onTap: onSelect,
          ),
          const SizedBox(height: 8),
          _NavButton(
            section: AppSection.audits,
            selected: selected == AppSection.audits,
            onTap: onSelect,
          ),
          const SizedBox(height: 20),
          const _NavLabel('Control Plane'),
          const SizedBox(height: 8),
          _NavButton(
            section: AppSection.controlPlane,
            selected: selected == AppSection.controlPlane,
            onTap: onSelect,
          ),
          const SizedBox(height: 20),
          const _NavLabel('Harness Config'),
          const SizedBox(height: 8),
          _NavButton(
            section: AppSection.providers,
            selected: selected == AppSection.providers,
            onTap: onSelect,
          ),
          const Spacer(),
          const _InfoPanel(
            title: 'Beta mode',
            body:
                'This shell exposes only live control-plane-backed surfaces. Seed data and design-only sections have been removed from the beta path.',
          ),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFE28A2B), Color(0xFFB85417)],
            ),
          ),
          child: const Icon(Icons.hub_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agent Awesome',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Beta operator console',
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: _textSubtle,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final ValueChanged<AppSection> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _panelRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(section),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                section.icon,
                color: selected ? _textPrimary : _textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _textPrimary : _textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.section,
    required this.controlPlaneBaseUrl,
    required this.deploymentMode,
  });

  final AppSection section;
  final String controlPlaneBaseUrl;
  final String deploymentMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Connected to $controlPlaneBaseUrl (${deploymentMode.toUpperCase()})',
                style: const TextStyle(color: _textMuted),
              ),
            ],
          ),
        ),
        _StatusPill(
          label: deploymentMode == 'cloudflare' ? 'Deployed mode' : 'Live API',
          color: deploymentMode == 'cloudflare' ? _warning : _success,
        ),
      ],
    );
  }
}

class _OverviewPage extends StatefulWidget {
  const _OverviewPage({required this.operationsApi, required this.onOpenRun});

  final OperationsApi operationsApi;
  final ValueChanged<String> onOpenRun;

  @override
  State<_OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<_OverviewPage> {
  bool _loading = true;
  String? _error;
  MetricsSnapshot? _metrics;
  List<RunRecord> _runs = <RunRecord>[];
  List<ApprovalRecord> _pendingApprovals = <ApprovalRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.operationsApi.getMetrics(),
        widget.operationsApi.listRuns(),
        widget.operationsApi.listApprovals(
          query: const ApprovalQuery(decision: 'pending'),
        ),
      ]);
      setState(() {
        _metrics = results[0] as MetricsSnapshot;
        _runs = results[1] as List<RunRecord>;
        _pendingApprovals = results[2] as List<ApprovalRecord>;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _load());
    }

    final metrics = _metrics!;
    final runningCount = _statusCount(metrics, const <String>[
      'running',
      'waiting_approval',
      'waiting_user',
    ]);
    final problemCount = _statusCount(metrics, const <String>[
      'blocked',
      'failed',
      'cancelled',
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _MetricCard(
                    label: 'Active runs',
                    value: '$runningCount',
                    tone: _info,
                    detail: 'Running or waiting',
                  ),
                  _MetricCard(
                    label: 'Completed runs',
                    value:
                        '${_statusCount(metrics, const <String>['completed'])}',
                    tone: _success,
                    detail: 'Completed successfully',
                  ),
                  _MetricCard(
                    label: 'Problem runs',
                    value: '$problemCount',
                    tone: _danger,
                    detail: 'Blocked, failed, or cancelled',
                  ),
                  _MetricCard(
                    label: 'Installations',
                    value: '${metrics.installations}',
                    tone: _accent,
                    detail: 'Known integrations',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Panel(
                title: 'Operational latency',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KeyValueRow(
                      label: 'Average run latency',
                      value: _formatDurationSeconds(metrics.runLatencySecs),
                    ),
                    const SizedBox(height: 10),
                    _KeyValueRow(
                      label: 'Average approval latency',
                      value: _formatDurationSeconds(
                        metrics.approvalLatencySecs,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _KeyValueRow(
                      label: 'Integration errors',
                      value: '${metrics.integrationErrors}',
                    ),
                    const SizedBox(height: 10),
                    _KeyValueRow(
                      label: 'Failed provisionings',
                      value: '${metrics.failedProvisionings}',
                    ),
                    const SizedBox(height: 10),
                    _KeyValueRow(
                      label: 'Secret rotations',
                      value: '${metrics.secretRotations}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Panel(
                title: 'Run status counts',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: metrics.runStatusCounts.entries
                      .map(
                        (MapEntry<String, int> entry) => _StatusCountChip(
                          status: entry.key,
                          count: entry.value,
                        ),
                      )
                      .toList(),
                ),
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
                child: _Panel(
                  title: 'Recent runs',
                  fill: true,
                  child: _runs.isEmpty
                      ? const _EmptyState(
                          title: 'No runs yet',
                          body:
                              'The control plane is reachable, but it has not recorded any runs yet.',
                        )
                      : ListView.separated(
                          itemCount: math.min(_runs.length, 12),
                          separatorBuilder: (_, _) =>
                              const Divider(color: _border),
                          itemBuilder: (BuildContext context, int index) {
                            final run = _runs[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                run.resultSummary.isNotEmpty
                                    ? run.resultSummary
                                    : run.runId,
                              ),
                              subtitle: Text(
                                '${run.tenantId} • ${run.agentId} • ${_formatDateTime(run.createdAt)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _StatusPill(
                                    label: run.status,
                                    color: _statusColor(run.status),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                              onTap: () => widget.onOpenRun(run.runId),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 360,
                child: _Panel(
                  title: 'Pending approvals',
                  fill: true,
                  child: _pendingApprovals.isEmpty
                      ? const _EmptyState(
                          title: 'No approvals waiting',
                          body:
                              'Manual approvals will show up here when runs stop for operator review.',
                        )
                      : ListView.separated(
                          itemCount: _pendingApprovals.length,
                          separatorBuilder: (_, _) =>
                              const Divider(color: _border),
                          itemBuilder: (BuildContext context, int index) {
                            final approval = _pendingApprovals[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(approval.runId),
                              subtitle: Text(
                                'Created ${_formatDateTime(approval.createdAt)}',
                              ),
                              trailing: const _StatusPill(
                                label: 'pending',
                                color: _warning,
                              ),
                              onTap: () => widget.onOpenRun(approval.runId),
                            );
                          },
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

class _RunsPage extends StatefulWidget {
  const _RunsPage({required this.operationsApi, required this.initialRunId});

  final OperationsApi operationsApi;
  final String? initialRunId;

  @override
  State<_RunsPage> createState() => _RunsPageState();
}

class _RunsPageState extends State<_RunsPage> {
  bool _loadingRuns = true;
  bool _loadingDetail = false;
  bool _resolvingApproval = false;
  String? _runsError;
  String? _detailError;
  String? _approvalError;
  List<RunRecord> _runs = <RunRecord>[];
  String? _selectedRunId;
  RunRecord? _runDetail;
  ApprovalRecord? _approval;
  List<ArtifactRecord> _artifacts = <ArtifactRecord>[];
  List<AuditRecord> _audits = <AuditRecord>[];
  String _tenantFilter = '';
  String _agentFilter = '';
  String _actorFilter = '';
  String _statusFilter = '';
  String _invocationFilter = '';
  final TextEditingController _approverController = TextEditingController();
  final TextEditingController _approvalReasonController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRuns(preferredRunId: widget.initialRunId);
  }

  @override
  void dispose() {
    _approverController.dispose();
    _approvalReasonController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RunsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRunId != null &&
        widget.initialRunId != oldWidget.initialRunId &&
        widget.initialRunId != _selectedRunId) {
      _selectRun(widget.initialRunId!);
    }
  }

  Future<void> _loadRuns({String? preferredRunId}) async {
    setState(() {
      _loadingRuns = true;
      _runsError = null;
    });
    try {
      final runs = await widget.operationsApi.listRuns(query: _currentQuery());
      final selected =
          preferredRunId ??
          _selectedRunId ??
          (runs.isNotEmpty ? runs.first.runId : null);
      setState(() {
        _runs = runs;
        _selectedRunId = selected;
        _loadingRuns = false;
      });
      if (selected != null) {
        await _selectRun(selected);
      } else {
        setState(() {
          _runDetail = null;
          _approval = null;
          _artifacts = <ArtifactRecord>[];
          _audits = <AuditRecord>[];
        });
      }
    } catch (error) {
      setState(() {
        _runsError = error.toString();
        _loadingRuns = false;
      });
    }
  }

  Future<void> _selectRun(String runId) async {
    setState(() {
      _selectedRunId = runId;
      _loadingDetail = true;
      _detailError = null;
      _approvalError = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.operationsApi.getRun(runId),
        widget.operationsApi.listApprovals(query: ApprovalQuery(runId: runId)),
        widget.operationsApi.listArtifacts(runId: runId),
        widget.operationsApi.listAudits(runId: runId),
      ]);
      setState(() {
        _runDetail = results[0] as RunRecord;
        final approvals = results[1] as List<ApprovalRecord>;
        _approval = approvals.isEmpty ? null : approvals.first;
        _artifacts = results[2] as List<ArtifactRecord>;
        _audits = results[3] as List<AuditRecord>;
        _approvalError = null;
        _loadingDetail = false;
      });
    } catch (error) {
      setState(() {
        _detailError = error.toString();
        _loadingDetail = false;
      });
    }
  }

  RunQuery _currentQuery() {
    return RunQuery(
      tenantId: _tenantFilter,
      agentId: _agentFilter,
      actorId: _actorFilter,
      status: _statusFilter,
      invocationMode: _invocationFilter,
    );
  }

  Future<void> _applyFilters() async {
    await _loadRuns();
  }

  void _clearFilters() {
    setState(() {
      _tenantFilter = '';
      _agentFilter = '';
      _actorFilter = '';
      _statusFilter = '';
      _invocationFilter = '';
    });
    _loadRuns();
  }

  Future<void> _resolveApproval(String decision) async {
    final approval = _approval;
    if (approval == null) {
      return;
    }
    if (_approverController.text.trim().isEmpty) {
      setState(() {
        _approvalError = 'Approver ID is required to resolve approval.';
      });
      return;
    }
    setState(() {
      _resolvingApproval = true;
      _approvalError = null;
    });
    try {
      await widget.operationsApi.resolveApproval(
        approvalRequestId: approval.approvalRequestId,
        approverId: _approverController.text.trim(),
        decision: decision,
        reason: _approvalReasonController.text.trim(),
      );
      await _loadRuns(preferredRunId: approval.runId);
    } catch (error) {
      setState(() {
        _approvalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _resolvingApproval = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRuns) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_runsError != null) {
      return _ErrorState(message: _runsError!, onRetry: () => _loadRuns());
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1150;
        final listPane = _RunListPane(
          runs: _runs,
          selectedRunId: _selectedRunId,
          tenantFilter: _tenantFilter,
          agentFilter: _agentFilter,
          actorFilter: _actorFilter,
          statusFilter: _statusFilter,
          invocationFilter: _invocationFilter,
          onTenantFilterChanged: (String value) {
            setState(() => _tenantFilter = value);
          },
          onAgentFilterChanged: (String value) {
            setState(() => _agentFilter = value);
          },
          onActorFilterChanged: (String value) {
            setState(() => _actorFilter = value);
          },
          onStatusFilterChanged: (String value) {
            setState(() => _statusFilter = value);
          },
          onInvocationFilterChanged: (String value) {
            setState(() => _invocationFilter = value);
          },
          onApplyFilters: _applyFilters,
          onClearFilters: _clearFilters,
          onRefresh: _loadRuns,
          onSelect: _selectRun,
        );
        final detailPane = _RunDetailPane(
          loading: _loadingDetail,
          error: _detailError,
          run: _runDetail,
          approval: _approval,
          approvalError: _approvalError,
          resolvingApproval: _resolvingApproval,
          approverController: _approverController,
          approvalReasonController: _approvalReasonController,
          artifacts: _artifacts,
          audits: _audits,
          onApprove: () => _resolveApproval('approved'),
          onReject: () => _resolveApproval('rejected'),
          onRetry: _selectedRunId == null
              ? null
              : () => _selectRun(_selectedRunId!),
        );

        if (stacked) {
          return Column(
            children: [
              SizedBox(height: 420, child: listPane),
              const SizedBox(height: 14),
              Expanded(child: detailPane),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 380, child: listPane),
            const SizedBox(width: 14),
            Expanded(child: detailPane),
          ],
        );
      },
    );
  }
}

class _RunListPane extends StatelessWidget {
  const _RunListPane({
    required this.runs,
    required this.selectedRunId,
    required this.tenantFilter,
    required this.agentFilter,
    required this.actorFilter,
    required this.statusFilter,
    required this.invocationFilter,
    required this.onTenantFilterChanged,
    required this.onAgentFilterChanged,
    required this.onActorFilterChanged,
    required this.onStatusFilterChanged,
    required this.onInvocationFilterChanged,
    required this.onApplyFilters,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onSelect,
  });

  final List<RunRecord> runs;
  final String? selectedRunId;
  final String tenantFilter;
  final String agentFilter;
  final String actorFilter;
  final String statusFilter;
  final String invocationFilter;
  final ValueChanged<String> onTenantFilterChanged;
  final ValueChanged<String> onAgentFilterChanged;
  final ValueChanged<String> onActorFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onInvocationFilterChanged;
  final Future<void> Function() onApplyFilters;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Runs',
      fill: true,
      trailing: FilledButton.icon(
        onPressed: () => onRefresh(),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 160,
                child: TextFormField(
                  key: ValueKey<String>('tenant-$tenantFilter'),
                  initialValue: tenantFilter,
                  onChanged: onTenantFilterChanged,
                  decoration: const InputDecoration(labelText: 'Tenant'),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  key: ValueKey<String>('agent-$agentFilter'),
                  initialValue: agentFilter,
                  onChanged: onAgentFilterChanged,
                  decoration: const InputDecoration(labelText: 'Agent'),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  key: ValueKey<String>('actor-$actorFilter'),
                  initialValue: actorFilter,
                  onChanged: onActorFilterChanged,
                  decoration: const InputDecoration(labelText: 'Actor'),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: statusFilter.isEmpty ? '' : statusFilter,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: '',
                      child: Text('All statuses'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'queued',
                      child: Text('queued'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'running',
                      child: Text('running'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'waiting_approval',
                      child: Text('waiting_approval'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'waiting_user',
                      child: Text('waiting_user'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'blocked',
                      child: Text('blocked'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'completed',
                      child: Text('completed'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'failed',
                      child: Text('failed'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'cancelled',
                      child: Text('cancelled'),
                    ),
                  ],
                  onChanged: (String? value) =>
                      onStatusFilterChanged(value ?? ''),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: invocationFilter.isEmpty
                      ? ''
                      : invocationFilter,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: '',
                      child: Text('All modes'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'direct_task',
                      child: Text('direct_task'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'conversation_turn',
                      child: Text('conversation_turn'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'trigger',
                      child: Text('trigger'),
                    ),
                  ],
                  onChanged: (String? value) =>
                      onInvocationFilterChanged(value ?? ''),
                  decoration: const InputDecoration(labelText: 'Invocation'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: () => onApplyFilters(),
                child: const Text('Apply filters'),
              ),
              const SizedBox(width: 10),
              TextButton(onPressed: onClearFilters, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: runs.isEmpty
                ? const _EmptyState(
                    title: 'No runs found',
                    body:
                        'Start a run through the control plane to inspect it here.',
                  )
                : ListView.separated(
                    itemCount: runs.length,
                    separatorBuilder: (_, _) => const Divider(color: _border),
                    itemBuilder: (BuildContext context, int index) {
                      final run = runs[index];
                      final selected = run.runId == selectedRunId;
                      return InkWell(
                        onTap: () => onSelect(run.runId),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected ? _panelRaised : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? _accent : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      run.resultSummary.isNotEmpty
                                          ? run.resultSummary
                                          : run.runId,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _StatusPill(
                                    label: run.status,
                                    color: _statusColor(run.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                run.runId,
                                style: const TextStyle(
                                  color: _textSubtle,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${run.tenantId} • ${run.agentId} • ${_blankAsUnknown(run.invocationMode)}',
                                style: const TextStyle(color: _textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(run.createdAt),
                                style: const TextStyle(color: _textSubtle),
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
    );
  }
}

class _RunDetailPane extends StatelessWidget {
  const _RunDetailPane({
    required this.loading,
    required this.error,
    required this.run,
    required this.approval,
    required this.approvalError,
    required this.resolvingApproval,
    required this.approverController,
    required this.approvalReasonController,
    required this.artifacts,
    required this.audits,
    required this.onApprove,
    required this.onReject,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final RunRecord? run;
  final ApprovalRecord? approval;
  final String? approvalError;
  final bool resolvingApproval;
  final TextEditingController approverController;
  final TextEditingController approvalReasonController;
  final List<ArtifactRecord> artifacts;
  final List<AuditRecord> audits;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _Panel(
        title: 'Run detail',
        fill: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return _Panel(
        title: 'Run detail',
        fill: true,
        child: _ErrorState(message: error!, onRetry: onRetry),
      );
    }
    if (run == null) {
      return const _Panel(
        title: 'Run detail',
        fill: true,
        child: _EmptyState(
          title: 'No run selected',
          body: 'Choose a run from the list to inspect its runtime state.',
        ),
      );
    }

    final profile = run!.profileSnapshot;
    return _Panel(
      title: 'Run detail',
      fill: true,
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  run!.resultSummary.isNotEmpty
                      ? run!.resultSummary
                      : run!.runId,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: run!.status, color: _statusColor(run!.status)),
            ],
          ),
          const SizedBox(height: 14),
          _InfoPanel(
            title: 'Identity',
            body:
                'Run: ${run!.runId}\nTenant: ${run!.tenantId}\nAgent: ${run!.agentId}\nActor: ${run!.actorId}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Timing',
            body:
                'Created: ${_formatDateTime(run!.createdAt)}\nStarted: ${_formatDateTime(run!.startedAt)}\nCompleted: ${_formatDateTime(run!.completedAt)}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Execution',
            body:
                'Invocation mode: ${_blankAsUnknown(run!.invocationMode)}\nRequested autonomy: ${_blankAsUnknown(run!.requestedAutonomyMode)}\nWait reason: ${_blankAsUnknown(run!.waitReason)}\nArtifact manifest: ${_blankAsUnknown(run!.artifactManifestReference)}',
          ),
          const SizedBox(height: 12),
          _ApprovalPanel(
            approval: approval,
            approvalError: approvalError,
            resolvingApproval: resolvingApproval,
            approverController: approverController,
            approvalReasonController: approvalReasonController,
            onApprove: onApprove,
            onReject: onReject,
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Source context',
            body:
                'Interface: ${_blankAsUnknown(run!.source.interface)}\nInstallation: ${_blankAsUnknown(run!.source.installationId)}\nWorkspace: ${_blankAsUnknown(run!.source.externalWorkspaceId)}\nConversation: ${_blankAsUnknown(run!.source.conversationId)}\nChannel: ${_blankAsUnknown(run!.source.channelId)}\nThread: ${_blankAsUnknown(run!.source.threadId)}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Runtime profile',
            body:
                'Profile: ${profile.profileId}\nVersion: ${profile.version}\nModel: ${_blankAsUnknown(profile.model)}\nProvider: ${_blankAsUnknown(profile.provider)}\nApproval mode: ${_blankAsUnknown(profile.approvalPolicy.mode)}\nMax run seconds: ${profile.runtimeLimits.maxRunSeconds}\nMax turns: ${profile.runtimeLimits.maxTurns}',
          ),
          const SizedBox(height: 12),
          _TagSection(
            title: 'Allowed capabilities',
            tags: profile.allowedCapabilities,
          ),
          const SizedBox(height: 12),
          _TagSection(
            title: 'Denied capabilities',
            tags: profile.deniedCapabilities,
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Storage scope',
            body:
                'Namespace: ${_blankAsUnknown(profile.storageScope.namespace)}\nArtifact prefix: ${_blankAsUnknown(profile.storageScope.artifactPrefix)}\nRetention days: ${profile.storageScope.retentionDays}',
          ),
          const SizedBox(height: 12),
          _TagSection(
            title: 'Secret bindings',
            tags: profile.secretBindings
                .map(
                  (SecretBindingRefSnapshot binding) =>
                      '${binding.name} (${binding.provider})',
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _SubsectionTitle('Operator actions'),
          const SizedBox(height: 8),
          if (run!.operatorActions.isEmpty)
            const _InfoPanel(
              title: 'Operator actions',
              body: 'No operator actions were recorded for this run.',
            )
          else
            ...run!.operatorActions.map(
              (OperatorActionRecord action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InfoPanel(
                  title: action.action,
                  body:
                      'Actor: ${_blankAsUnknown(action.actorId)}\nReason: ${_blankAsUnknown(action.reason)}\nOccurred: ${_formatDateTime(action.occurredAt)}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          _SubsectionTitle('Artifacts'),
          const SizedBox(height: 8),
          if (artifacts.isEmpty)
            const _InfoPanel(
              title: 'Artifacts',
              body: 'No artifacts recorded for this run.',
            )
          else
            ...artifacts.map(
              (ArtifactRecord artifact) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InfoPanel(
                  title: artifact.kind,
                  body:
                      'Reference: ${artifact.reference}\nCreated: ${_formatDateTime(artifact.createdAt)}\nRetention days: ${artifact.retentionDays}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          _SubsectionTitle('Audit trail'),
          const SizedBox(height: 8),
          if (audits.isEmpty)
            const _InfoPanel(
              title: 'Audit',
              body: 'No audit records found for this run.',
            )
          else
            ...audits.map(
              (AuditRecord audit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InfoPanel(
                  title: audit.action,
                  body:
                      'Resource: ${audit.resourceType}/${audit.resourceId}\nUser: ${_blankAsUnknown(audit.userId)}\nOccurred: ${_formatDateTime(audit.occurredAt)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtifactsPage extends StatefulWidget {
  const _ArtifactsPage({required this.operationsApi});

  final OperationsApi operationsApi;

  @override
  State<_ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends State<_ArtifactsPage> {
  bool _loading = true;
  String? _error;
  final TextEditingController _tenantController = TextEditingController();
  final TextEditingController _runController = TextEditingController();
  List<ArtifactRecord> _artifacts = <ArtifactRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _runController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.operationsApi.listArtifacts(
        tenantId: _tenantController.text.trim().isEmpty
            ? null
            : _tenantController.text.trim(),
        runId: _runController.text.trim().isEmpty
            ? null
            : _runController.text.trim(),
      );
      setState(() {
        _artifacts = records;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        _Panel(
          title: 'Artifact filters',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _tenantController,
                  decoration: const InputDecoration(labelText: 'Tenant ID'),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _runController,
                  decoration: const InputDecoration(labelText: 'Run ID'),
                ),
              ),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Apply'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Artifacts',
          child: _artifacts.isEmpty
              ? const _EmptyState(
                  title: 'No artifacts found',
                  body: 'No artifact records match the current filters.',
                )
              : Column(
                  children: _artifacts
                      .map(
                        (ArtifactRecord artifact) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InfoPanel(
                            title: artifact.kind,
                            body:
                                'Artifact ${artifact.artifactId}\nTenant: ${artifact.tenantId}\nAgent: ${artifact.agentId}\nRun: ${artifact.runId}\nReference: ${artifact.reference}\nCreated: ${_formatDateTime(artifact.createdAt)}\nRetention days: ${artifact.retentionDays}',
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

class _AuditsPage extends StatefulWidget {
  const _AuditsPage({required this.operationsApi});

  final OperationsApi operationsApi;

  @override
  State<_AuditsPage> createState() => _AuditsPageState();
}

class _AuditsPageState extends State<_AuditsPage> {
  bool _loading = true;
  String? _error;
  final TextEditingController _tenantController = TextEditingController();
  final TextEditingController _runController = TextEditingController();
  List<AuditRecord> _audits = <AuditRecord>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _runController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.operationsApi.listAudits(
        tenantId: _tenantController.text.trim().isEmpty
            ? null
            : _tenantController.text.trim(),
        runId: _runController.text.trim().isEmpty
            ? null
            : _runController.text.trim(),
      );
      setState(() {
        _audits = records;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    return ListView(
      children: [
        _Panel(
          title: 'Audit filters',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _tenantController,
                  decoration: const InputDecoration(labelText: 'Tenant ID'),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _runController,
                  decoration: const InputDecoration(labelText: 'Run ID'),
                ),
              ),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Apply'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Audit records',
          child: _audits.isEmpty
              ? const _EmptyState(
                  title: 'No audits found',
                  body: 'No audit records match the current filters.',
                )
              : Column(
                  children: _audits
                      .map(
                        (AuditRecord audit) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InfoPanel(
                            title: audit.action,
                            body:
                                'Audit ${audit.auditId}\nTenant: ${audit.tenantId}\nAgent: ${audit.agentId}\nRun: ${audit.runId}\nResource: ${audit.resourceType}/${audit.resourceId}\nUser: ${_blankAsUnknown(audit.userId)}\nAdministrative: ${audit.administrative}\nOccurred: ${_formatDateTime(audit.occurredAt)}',
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

class _ControlPlanePage extends StatefulWidget {
  const _ControlPlanePage({
    required this.controlPlaneApi,
    required this.operationsApi,
  });

  final ControlPlaneApi controlPlaneApi;
  final OperationsApi operationsApi;

  @override
  State<_ControlPlanePage> createState() => _ControlPlanePageState();
}

class _ControlPlanePageState extends State<_ControlPlanePage> {
  bool _loading = true;
  String? _error;
  List<UserRecord> _users = <UserRecord>[];
  List<TenantRecord> _tenants = <TenantRecord>[];
  List<MembershipRecord> _memberships = <MembershipRecord>[];
  List<AgentRecord> _agents = <AgentRecord>[];
  List<InstallationRecord> _installations = <InstallationRecord>[];
  List<ConversationRecord> _conversations = <ConversationRecord>[];
  List<ChannelRouteRecord> _routes = <ChannelRouteRecord>[];
  List<RunRecord> _runs = <RunRecord>[];
  List<ApprovalRecord> _approvals = <ApprovalRecord>[];
  String? _selectedConversationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.controlPlaneApi.listUsers(),
        widget.controlPlaneApi.listTenants(),
        widget.controlPlaneApi.listMemberships(),
        widget.controlPlaneApi.listAgents(),
        widget.controlPlaneApi.listInstallations(),
        widget.controlPlaneApi.listConversations(),
        widget.controlPlaneApi.listChannelRoutes(),
        widget.operationsApi.listRuns(),
        widget.operationsApi.listApprovals(),
      ]);
      setState(() {
        _users = results[0] as List<UserRecord>;
        _tenants = results[1] as List<TenantRecord>;
        _memberships = results[2] as List<MembershipRecord>;
        _agents = results[3] as List<AgentRecord>;
        _installations = results[4] as List<InstallationRecord>;
        _conversations = results[5] as List<ConversationRecord>;
        _routes = results[6] as List<ChannelRouteRecord>;
        _runs = results[7] as List<RunRecord>;
        _approvals = results[8] as List<ApprovalRecord>;
        _selectedConversationId = _conversations.isEmpty
            ? null
            : (_selectedConversationId != null &&
                      _conversations.any(
                        (ConversationRecord record) =>
                            record.conversationId == _selectedConversationId,
                      )
                  ? _selectedConversationId
                  : _conversations.first.conversationId);
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _MetricCard(
                    label: 'Tenants',
                    value: '${_tenants.length}',
                    tone: _accent,
                    detail: 'Provisioned workspaces',
                  ),
                  _MetricCard(
                    label: 'Users',
                    value: '${_users.length}',
                    tone: _info,
                    detail: 'Known identities',
                  ),
                  _MetricCard(
                    label: 'Agents',
                    value: '${_agents.length}',
                    tone: _success,
                    detail: 'Control-plane agents',
                  ),
                  _MetricCard(
                    label: 'Installations',
                    value: '${_installations.length}',
                    tone: _warning,
                    detail: 'Bound integrations',
                  ),
                  _MetricCard(
                    label: 'Conversations',
                    value: '${_conversations.length}',
                    tone: _info,
                    detail: 'Active threads',
                  ),
                  _MetricCard(
                    label: 'Routes',
                    value: '${_routes.length}',
                    tone: _danger,
                    detail: 'Channel mappings',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Tenants',
            items: _tenants
                .map(
                  (TenantRecord tenant) => _EntityItem(
                    title: tenant.displayName,
                    subtitle:
                        '${tenant.tenantId} • ${tenant.status} • ${tenant.type}',
                    meta: 'Owner ${tenant.ownerUserId}',
                  ),
                )
                .toList(),
          ),
          right: _EntityPanel(
            title: 'Users',
            items: _users
                .map(
                  (UserRecord user) => _EntityItem(
                    title: user.displayName,
                    subtitle: '${user.userId} • ${user.status}',
                    meta: user.kind,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Control-plane agents',
            items: _agents
                .map(
                  (AgentRecord agent) => _EntityItem(
                    title: agent.name,
                    subtitle:
                        '${agent.agentId} • ${agent.status} • ${agent.tenantId}',
                    meta: 'Template ${agent.templateId}',
                    tags: <String>[
                      ...agent.integrationBindings,
                      ...agent.enabledCapabilities.take(3),
                    ],
                  ),
                )
                .toList(),
          ),
          right: _EntityPanel(
            title: 'Installations',
            items: _installations
                .map(
                  (InstallationRecord installation) => _EntityItem(
                    title: installation.externalWorkspaceId,
                    subtitle:
                        '${installation.installationId} • ${installation.providerType} • ${installation.status}',
                    meta:
                        '${installation.mappedTenantId} -> ${installation.mappedDefaultAgentId}',
                    tags: installation.allowedChannelIds.take(3).toList(),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Memberships',
            items: _memberships
                .map(
                  (MembershipRecord membership) => _EntityItem(
                    title: membership.userId,
                    subtitle: membership.tenantId,
                    meta: membership.role,
                  ),
                )
                .toList(),
          ),
          right: _EntityPanel(
            title: 'Conversations',
            items: _conversations
                .map(
                  (ConversationRecord conversation) => _EntityItem(
                    title: conversation.name.isEmpty
                        ? conversation.conversationId
                        : conversation.name,
                    subtitle:
                        '${conversation.conversationId} • ${conversation.status}',
                    meta:
                        '${conversation.tenantId} • ${conversation.agentId} • ${_blankAsUnknown(conversation.kind)}',
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        _EntityPanel(
          title: 'Channel routes',
          items: _routes
              .map(
                (ChannelRouteRecord route) => _EntityItem(
                  title:
                      '${route.providerType}:${_blankAsUnknown(route.channelId)}',
                  subtitle:
                      '${route.routeId} • ${route.tenantId} • ${route.agentId}',
                  meta:
                      'Conversation ${route.conversationId} • Thread ${_blankAsUnknown(route.threadId)}',
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        _buildConversationDetail(),
      ],
    );
  }

  Widget _buildConversationDetail() {
    if (_conversations.isEmpty) {
      return const _InfoPanel(
        title: 'Conversation detail',
        body: 'No conversations available.',
      );
    }
    final selected = _conversations.firstWhere(
      (ConversationRecord record) => record.conversationId == _selectedConversationId,
      orElse: () => _conversations.first,
    );
    final scopedRuns = _runs
        .where(
          (RunRecord run) => run.source.conversationId == selected.conversationId,
        )
        .toList()
      ..sort(
        (RunRecord a, RunRecord b) =>
            (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
      );
    final latestRun = scopedRuns.isEmpty ? null : scopedRuns.first;
    final latestApprovals = latestRun == null
        ? <ApprovalRecord>[]
        : _approvals
              .where((ApprovalRecord record) => record.runId == latestRun.runId)
              .toList()
          ..sort(
            (ApprovalRecord a, ApprovalRecord b) =>
                (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                    ),
          );
    final approval = latestApprovals.isEmpty ? null : latestApprovals.first;
    final scopedRoutes = _routes
        .where(
          (ChannelRouteRecord route) =>
              route.conversationId == selected.conversationId,
        )
        .toList();
    final installations = scopedRoutes.isEmpty
        ? <InstallationRecord>[]
        : _installations.where((InstallationRecord install) {
            return scopedRoutes.any(
              (ChannelRouteRecord route) =>
                  route.installationId == install.installationId,
            );
          }).toList();

    return _Panel(
      title: 'Conversation detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: selected.conversationId,
            decoration: const InputDecoration(labelText: 'Conversation'),
            items: _conversations
                .map(
                  (ConversationRecord record) => DropdownMenuItem<String>(
                    value: record.conversationId,
                    child: Text(
                      record.name.isEmpty ? record.conversationId : record.name,
                    ),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedConversationId = value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Status: ${selected.status}\nTenant: ${selected.tenantId}\nAgent: ${selected.agentId}\nCreated: ${_formatDateTime(selected.createdAt)}',
            style: const TextStyle(color: _textMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Recent activity',
            body: latestRun == null
                ? 'No runs linked to this conversation.'
                : 'Latest run: ${latestRun.runId}\nStatus: ${latestRun.status}\nCreated: ${_formatDateTime(latestRun.createdAt)}\nWait reason: ${_blankAsUnknown(latestRun.waitReason)}',
          ),
          const SizedBox(height: 10),
          _InfoPanel(
            title: 'Latest approval',
            body: approval == null
                ? 'No approvals attached to the latest run.'
                : 'Approval: ${approval.approvalRequestId}\nDecision: ${approval.decision}\nApprover: ${_blankAsUnknown(approval.approverId)}\nCreated: ${_formatDateTime(approval.createdAt)}',
          ),
          const SizedBox(height: 10),
          _InfoPanel(
            title: 'Route and install health',
            body:
                'Routes: ${scopedRoutes.length}\nInstallations: ${installations.length}\nUnhealthy routes: ${scopedRoutes.where((ChannelRouteRecord route) => route.status != 'active').length}',
          ),
        ],
      ),
    );
  }
}

class _ApprovalPanel extends StatelessWidget {
  const _ApprovalPanel({
    required this.approval,
    required this.approvalError,
    required this.resolvingApproval,
    required this.approverController,
    required this.approvalReasonController,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalRecord? approval;
  final String? approvalError;
  final bool resolvingApproval;
  final TextEditingController approverController;
  final TextEditingController approvalReasonController;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    if (approval == null) {
      return const _InfoPanel(
        title: 'Approval',
        body: 'No approval record is attached to this run.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Approval',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPill(
                label: approval!.decision,
                color: approval!.decision == 'approved'
                    ? _success
                    : approval!.decision == 'rejected'
                    ? _danger
                    : _warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Request ${approval!.approvalRequestId}\nCreated ${_formatDateTime(approval!.createdAt)}\nApprover ${_blankAsUnknown(approval!.approverId)}\nReason ${_blankAsUnknown(approval!.reason)}',
            style: const TextStyle(color: _textMuted, height: 1.45),
          ),
          if (approval!.decision == 'pending') ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              controller: approverController,
              decoration: const InputDecoration(labelText: 'Approver ID'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: approvalReasonController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Resolution note'),
            ),
            if (approvalError != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(approvalError!, style: const TextStyle(color: _danger)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: resolvingApproval ? null : onApprove,
                  child: resolvingApproval
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Approve'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: resolvingApproval ? null : onReject,
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TwoPanelRow extends StatelessWidget {
  const _TwoPanelRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 1100) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _EntityItem {
  const _EntityItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    this.tags = const <String>[],
  });

  final String title;
  final String subtitle;
  final String meta;
  final List<String> tags;
}

class _EntityPanel extends StatelessWidget {
  const _EntityPanel({required this.title, required this.items});

  final String title;
  final List<_EntityItem> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: items.isEmpty
          ? const _EmptyState(
              title: 'No records',
              body:
                  'No live records were returned for this control-plane view.',
            )
          : Column(
              children: items
                  .take(8)
                  .map(
                    (_EntityItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _panelAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.subtitle,
                              style: const TextStyle(color: _textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.meta,
                              style: const TextStyle(color: _textSubtle),
                            ),
                            if (item.tags.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: item.tags
                                    .where(
                                      (String tag) => tag.trim().isNotEmpty,
                                    )
                                    .map((String tag) => _InlineTag(label: tag))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  const _InlineTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _panelRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProvidersPage extends StatefulWidget {
  const _ProvidersPage({
    required this.providerApi,
    required this.providerCatalogAvailable,
  });

  final ProviderCatalogApi providerApi;
  final bool providerCatalogAvailable;

  @override
  State<_ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends State<_ProvidersPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _configPath = '';
  List<ProviderConfig> _providers = <ProviderConfig>[];
  ProviderConfig _draft = ProviderConfig.empty();
  bool _isNew = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders({String? selectAlias}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.providerApi.listProviders();
      final providers = catalog.providers;
      ProviderConfig draft = ProviderConfig.empty();
      var isNew = true;
      if (providers.isNotEmpty) {
        final selected = selectAlias == null
            ? providers.first
            : providers.firstWhere(
                (ProviderConfig provider) => provider.alias == selectAlias,
                orElse: () => providers.first,
              );
        draft = selected.copy();
        isNew = false;
      }
      setState(() {
        _configPath = catalog.configPath;
        _providers = providers;
        _draft = draft;
        _isNew = isNew;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _selectProvider(ProviderConfig provider) {
    setState(() {
      _draft = provider.copy();
      _isNew = false;
    });
  }

  void _startNewProvider() {
    setState(() {
      _draft = ProviderConfig.empty();
      _isNew = true;
    });
  }

  Future<void> _saveProvider() async {
    if (_draft.alias.trim().isEmpty) {
      _showMessage('Provider alias is required.');
      return;
    }

    setState(() => _busy = true);
    try {
      final payload = _normalizedDraft();
      final result = _isNew
          ? await widget.providerApi.createProvider(payload)
          : await widget.providerApi.updateProvider(
              _draft.persistedAlias,
              payload,
            );
      await _loadProviders(selectAlias: result.provider.alias);
      _showMessage(_isNew ? 'Provider created.' : 'Provider settings saved.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyProvider() async {
    if (_isNew || _draft.alias.trim().isEmpty) {
      _showMessage('Save the provider before verification.');
      return;
    }
    setState(() => _busy = true);
    try {
      final report = await widget.providerApi.verifyProvider(_draft.alias);
      setState(() {
        _draft.verificationSummary = report.summary;
      });
      _showMessage(report.summary);
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteProvider() async {
    if (_isNew || _draft.persistedAlias.trim().isEmpty) {
      _showMessage('Nothing to delete.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.providerApi.deleteProvider(_draft.persistedAlias);
      await _loadProviders();
      _showMessage('Provider deleted.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  ProviderConfig _normalizedDraft() {
    final copy = _draft.copy();
    copy.models = copy.models
        .where((ProviderModelConfig model) => model.name.trim().isNotEmpty)
        .toList();
    return copy;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.providerCatalogAvailable) {
      return const _InfoPanel(
        title: 'Provider catalog unavailable',
        body:
            'This deployment mode disables local harness provider catalog mutation routes. Switch to local mode to manage providers.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _loadProviders());
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1150;
        final listPane = _Panel(
          title: 'Providers',
          fill: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _startNewProvider,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _busy ? null : () => _loadProviders(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
          child: _providers.isEmpty
              ? const _EmptyState(
                  title: 'No providers configured',
                  body:
                      'Create a provider here to manage the harness provider catalog through the control plane.',
                )
              : ListView.separated(
                  itemCount: _providers.length,
                  separatorBuilder: (_, _) => const Divider(color: _border),
                  itemBuilder: (BuildContext context, int index) {
                    final provider = _providers[index];
                    final selected =
                        !_isNew && provider.alias == _draft.persistedAlias;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(provider.alias),
                      subtitle: Text(
                        provider.adapter.isEmpty
                            ? 'adapter not set'
                            : provider.adapter,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider.isDefault)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: _StatusPill(
                                label: 'default',
                                color: _info,
                              ),
                            ),
                          _StatusPill(
                            label: provider.enabled ? 'enabled' : 'disabled',
                            color: provider.enabled ? _success : _warning,
                          ),
                          if (selected)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.check_circle, color: _accent),
                            ),
                        ],
                      ),
                      onTap: () => _selectProvider(provider),
                    );
                  },
                ),
        );

        final editorPane = _ProviderEditorPane(
          draft: _draft,
          isNew: _isNew,
          busy: _busy,
          configPath: _configPath,
          onChanged: () => setState(() {}),
          onSave: _saveProvider,
          onVerify: _verifyProvider,
          onDelete: _deleteProvider,
        );

        if (stacked) {
          return Column(
            children: [
              SizedBox(height: 300, child: listPane),
              const SizedBox(height: 14),
              Expanded(child: editorPane),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 360, child: listPane),
            const SizedBox(width: 14),
            Expanded(child: editorPane),
          ],
        );
      },
    );
  }
}

class _ProviderEditorPane extends StatelessWidget {
  const _ProviderEditorPane({
    required this.draft,
    required this.isNew,
    required this.busy,
    required this.configPath,
    required this.onChanged,
    required this.onSave,
    required this.onVerify,
    required this.onDelete,
  });

  final ProviderConfig draft;
  final bool isNew;
  final bool busy;
  final String configPath;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onVerify;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: isNew ? 'New provider' : 'Provider editor',
      fill: true,
      trailing: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton(
            onPressed: busy ? null : onSave,
            child: Text(isNew ? 'Create' : 'Save'),
          ),
          OutlinedButton(
            onPressed: busy || isNew ? null : onVerify,
            child: const Text('Verify'),
          ),
          OutlinedButton(
            onPressed: busy || isNew ? null : onDelete,
            child: const Text('Delete'),
          ),
        ],
      ),
      child: ListView(
        children: [
          if (configPath.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoPanel(title: 'Catalog path', body: configPath),
            ),
          _SubsectionTitle('General'),
          const SizedBox(height: 8),
          _FieldLabel('Alias'),
          TextFormField(
            initialValue: draft.alias,
            key: ValueKey<String>(
              'provider-alias-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.alias = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Adapter'),
          TextFormField(
            initialValue: draft.adapter,
            key: ValueKey<String>(
              'provider-adapter-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.adapter = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Base URL'),
          TextFormField(
            initialValue: draft.endpoint,
            key: ValueKey<String>(
              'provider-url-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.endpoint = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('API key environment variable'),
          TextFormField(
            initialValue: draft.apiKeyEnv,
            key: ValueKey<String>(
              'provider-key-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.apiKeyEnv = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Allowed hosts (comma separated)'),
          TextFormField(
            initialValue: draft.allowedHosts.join(', '),
            key: ValueKey<String>(
              'provider-hosts-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) {
              draft.allowedHosts = value
                  .split(',')
                  .map((String host) => host.trim())
                  .where((String host) => host.isNotEmpty)
                  .toList();
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: draft.enabled,
            onChanged: (bool value) {
              draft.enabled = value;
              onChanged();
            },
            title: const Text('Enabled'),
            subtitle: const Text(
              'Expose this provider to the harness catalog.',
            ),
          ),
          SwitchListTile(
            value: draft.isDefault,
            onChanged: (bool value) {
              draft.isDefault = value;
              onChanged();
            },
            title: const Text('Default provider'),
            subtitle: const Text('Mark this provider as the catalog default.'),
          ),
          SwitchListTile(
            value: draft.local,
            onChanged: (bool value) {
              draft.local = value;
              onChanged();
            },
            title: const Text('Local endpoint'),
            subtitle: const Text('Allow loopback or local provider access.'),
          ),
          SwitchListTile(
            value: draft.accessVerified,
            onChanged: (bool value) {
              draft.accessVerified = value;
              onChanged();
            },
            title: const Text('Access verified'),
            subtitle: const Text('Persist provider-level verification state.'),
          ),
          const SizedBox(height: 12),
          _FieldLabel('Timeout seconds'),
          TextFormField(
            initialValue: draft.timeoutSecs == 0 ? '' : '${draft.timeoutSecs}',
            key: ValueKey<String>(
              'provider-timeout-${draft.persistedAlias}-${isNew.toString()}',
            ),
            keyboardType: TextInputType.number,
            onChanged: (String value) {
              draft.timeoutSecs = int.tryParse(value.trim()) ?? 0;
            },
          ),
          const SizedBox(height: 12),
          _FieldLabel('API version'),
          TextFormField(
            initialValue: draft.apiVersion,
            key: ValueKey<String>(
              'provider-version-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.apiVersion = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Account ID'),
          TextFormField(
            initialValue: draft.accountId,
            key: ValueKey<String>(
              'provider-account-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.accountId = value,
          ),
          const SizedBox(height: 12),
          _FieldLabel('Gateway ID'),
          TextFormField(
            initialValue: draft.gatewayId,
            key: ValueKey<String>(
              'provider-gateway-${draft.persistedAlias}-${isNew.toString()}',
            ),
            onChanged: (String value) => draft.gatewayId = value,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: _SubsectionTitle('Models')),
              FilledButton.icon(
                onPressed: () {
                  draft.models.add(
                    ProviderModelConfig(
                      name: '',
                      enabled: false,
                      accessVerified: false,
                    ),
                  );
                  onChanged();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add model'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (draft.models.isEmpty)
            const _InfoPanel(title: 'Models', body: 'No models configured yet.')
          else
            ...List<Widget>.generate(draft.models.length, (int index) {
              final model = draft.models[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _panelAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: model.name,
                              key: ValueKey<String>(
                                'provider-model-${draft.persistedAlias}-$index-${model.name}',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Model name',
                              ),
                              onChanged: (String value) => model.name = value,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () {
                              draft.models.removeAt(index);
                              onChanged();
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        value: model.enabled,
                        onChanged: (bool value) {
                          model.enabled = value;
                          onChanged();
                        },
                        title: const Text('Enabled'),
                      ),
                      SwitchListTile(
                        value: model.accessVerified,
                        onChanged: (bool value) {
                          model.accessVerified = value;
                          onChanged();
                        },
                        title: const Text('Access verified'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 18),
          _InfoPanel(title: 'Verification', body: draft.verificationSummary),
          const SizedBox(height: 18),
          _SubsectionTitle('YAML preview'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panelAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: SelectableText(
              draft.alias.trim().isEmpty
                  ? 'Set an alias to preview YAML.'
                  : draft.toYamlSnippet(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: _textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
    this.fill = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                trailing ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 16),
            if (fill) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.tone,
    required this.detail,
  });

  final String label;
  final String value;
  final Color tone;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textMuted)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: tone,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(color: _textSubtle)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusCountChip extends StatelessWidget {
  const _StatusCountChip({required this.status, required this.count});

  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Text(
        '$status: $count',
        style: const TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: _textMuted, height: 1.5)),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _textMuted)),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SubsectionTitle extends StatelessWidget {
  const _SubsectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: _textMuted)),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubsectionTitle(title),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const _InfoPanel(title: 'None', body: 'No values recorded.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (String tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _panelAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(color: _textPrimary),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 42, color: _textSubtle),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: _danger),
            const SizedBox(height: 14),
            const Text(
              'The control plane request failed',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: _textMuted),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

int _statusCount(MetricsSnapshot metrics, List<String> keys) {
  var total = 0;
  for (final String key in keys) {
    total += metrics.runStatusCounts[key] ?? 0;
  }
  return total;
}

Color _statusColor(String status) {
  switch (status) {
    case 'running':
      return _info;
    case 'waiting_approval':
    case 'waiting_user':
      return _warning;
    case 'completed':
      return _success;
    case 'blocked':
    case 'failed':
    case 'cancelled':
      return _danger;
    case 'queued':
      return _accent;
    default:
      return _textMuted;
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'not recorded';
  }
  final twoDigitMonth = value.month.toString().padLeft(2, '0');
  final twoDigitDay = value.day.toString().padLeft(2, '0');
  final twoDigitHour = value.hour.toString().padLeft(2, '0');
  final twoDigitMinute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
}

String _formatDurationSeconds(double seconds) {
  if (seconds <= 0) {
    return 'n/a';
  }
  if (seconds < 60) {
    return '${seconds.toStringAsFixed(1)}s';
  }
  final minutes = seconds / 60;
  if (minutes < 60) {
    return '${minutes.toStringAsFixed(1)}m';
  }
  final hours = minutes / 60;
  return '${hours.toStringAsFixed(1)}h';
}

String _blankAsUnknown(String value) {
  return value.trim().isEmpty ? 'not set' : value.trim();
}
