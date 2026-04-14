import 'package:flutter/material.dart';
import 'package:ui/operations/operations_api.dart';
import 'package:ui/shared/ui.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({required this.operationsApi});

  final OperationsApi operationsApi;

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
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
      return ErrorState(message: _error!, onRetry: _load);
    }

    final metrics = _metrics!;
    final recentRuns = _runs.take(6).toList();
    final sortedStatusEntries = metrics.runStatusCounts.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
        final valueCompare = b.value.compareTo(a.value);
        if (valueCompare != 0) {
          return valueCompare;
        }
        return a.key.compareTo(b.key);
      });

    return ListView(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            MetricCard(
              label: 'Pending approvals',
              value: '${_pendingApprovals.length}',
              tone: warningColor,
              detail: 'Live operator queue',
            ),
            MetricCard(
              label: 'Avg run latency',
              value: '${metrics.runLatencySecs.toStringAsFixed(1)}s',
              tone: infoColor,
              detail: 'Completed runs',
            ),
            MetricCard(
              label: 'Avg approval latency',
              value: '${metrics.approvalLatencySecs.toStringAsFixed(1)}s',
              tone: accentColor,
              detail: 'Resolved approvals',
            ),
            MetricCard(
              label: 'Integration errors',
              value: '${metrics.integrationErrors}',
              tone: metrics.integrationErrors > 0 ? dangerColor : successColor,
              detail: 'Observed control-plane errors',
            ),
            MetricCard(
              label: 'Installations',
              value: '${metrics.installations}',
              tone: successColor,
              detail: 'Bound channel integrations',
            ),
          ],
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Run status counts',
          trailing: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          child: sortedStatusEntries.isEmpty
              ? const EmptyState(
                  title: 'No run metrics',
                  body:
                      'Run metrics will appear once the control plane records execution history.',
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: sortedStatusEntries
                      .map(
                        (MapEntry<String, int> entry) => Container(
                          width: 180,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: panelAltColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusPill(
                                label: entry.key,
                                color: statusColor(entry.key),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${entry.value}',
                                style: const TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Pending approval queue',
          child: _pendingApprovals.isEmpty
              ? const InfoPanel(
                  title: 'Approvals',
                  body: 'There are no pending approvals right now.',
                )
              : Column(
                  children: _pendingApprovals
                      .take(6)
                      .map(
                        (ApprovalRecord approval) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InfoPanel(
                            title: approval.approvalRequestId,
                            body:
                                'Run: ${approval.runId}\nDecision: ${approval.decision}\nCreated: ${formatDateTime(approval.createdAt)}\nExpires: ${formatDateTime(approval.expiresAt)}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Recent runs',
          child: recentRuns.isEmpty
              ? const EmptyState(
                  title: 'No recent runs',
                  body:
                      'Submit a run through the control plane to see it here.',
                )
              : Column(
                  children: recentRuns
                      .map(
                        (RunRecord run) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InfoPanel(
                            title: run.resultSummary.isEmpty
                                ? run.runId
                                : run.resultSummary,
                            body:
                                'Run: ${run.runId}\nTenant: ${run.tenantId}\nAgent: ${run.agentId}\nStatus: ${run.status}\nCreated: ${formatDateTime(run.createdAt)}',
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

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({required this.operationsApi});

  final OperationsApi operationsApi;

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  bool _loading = true;
  bool _resolving = false;
  String? _error;
  String? _selectedApprovalId;
  String? _approvalError;
  final TextEditingController _tenantController = TextEditingController();
  final TextEditingController _agentController = TextEditingController();
  final TextEditingController _approverController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  List<ApprovalRecord> _approvals = <ApprovalRecord>[];
  RunRecord? _run;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _agentController.dispose();
    _approverController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load({String? preferredApprovalId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final approvals = await widget.operationsApi.listApprovals(
        query: ApprovalQuery(
          tenantId: _tenantController.text.trim(),
          agentId: _agentController.text.trim(),
          decision: 'pending',
        ),
      );
      String? selectedApprovalId;
      for (final candidate in <String?>[
        preferredApprovalId,
        _selectedApprovalId,
        approvals.isEmpty ? null : approvals.first.approvalRequestId,
      ]) {
        if (candidate != null &&
            approvals.any(
              (ApprovalRecord record) => record.approvalRequestId == candidate,
            )) {
          selectedApprovalId = candidate;
          break;
        }
      }
      RunRecord? run;
      if (selectedApprovalId != null) {
        final selected = approvals.firstWhere(
          (ApprovalRecord record) =>
              record.approvalRequestId == selectedApprovalId,
          orElse: () => approvals.first,
        );
        run = await widget.operationsApi.getRun(selected.runId);
      }
      setState(() {
        _approvals = approvals;
        _selectedApprovalId = selectedApprovalId;
        _run = run;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectApproval(String approvalId) async {
    setState(() {
      _selectedApprovalId = approvalId;
      _loading = true;
      _error = null;
      _approvalError = null;
    });
    await _load(preferredApprovalId: approvalId);
  }

  Future<void> _resolve(String decision) async {
    final selected = _selectedApproval;
    if (selected == null) {
      return;
    }
    if (_approverController.text.trim().isEmpty) {
      setState(() {
        _approvalError = 'Approver ID is required to resolve approval.';
      });
      return;
    }
    setState(() {
      _resolving = true;
      _approvalError = null;
    });
    try {
      await widget.operationsApi.resolveApproval(
        approvalRequestId: selected.approvalRequestId,
        approverId: _approverController.text.trim(),
        decision: decision,
        reason: _reasonController.text.trim(),
      );
      _reasonController.clear();
      await _load();
    } catch (error) {
      setState(() {
        _approvalError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _resolving = false);
      }
    }
  }

  ApprovalRecord? get _selectedApproval {
    if (_selectedApprovalId == null) {
      return null;
    }
    for (final approval in _approvals) {
      if (approval.approvalRequestId == _selectedApprovalId) {
        return approval;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final approval = _selectedApproval;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1120;
        final queuePane = PanelCard(
          title: 'Pending approvals',
          fill: true,
          trailing: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: _tenantController,
                      decoration: const InputDecoration(labelText: 'Tenant'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: _agentController,
                      decoration: const InputDecoration(labelText: 'Agent'),
                    ),
                  ),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _approvals.isEmpty
                    ? const EmptyState(
                        title: 'No pending approvals',
                        body:
                            'The live approval queue is empty for the current filters.',
                      )
                    : ListView.separated(
                        itemCount: _approvals.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: borderColor),
                        itemBuilder: (BuildContext context, int index) {
                          final record = _approvals[index];
                          final selected =
                              record.approvalRequestId == _selectedApprovalId;
                          return InkWell(
                            onTap: () =>
                                _selectApproval(record.approvalRequestId),
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? panelRaisedColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? accentColor
                                      : Colors.transparent,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          record.approvalRequestId,
                                          style: const TextStyle(
                                            color: textPrimaryColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      StatusPill(
                                        label: record.decision,
                                        color: warningColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Run ${record.runId}',
                                    style: const TextStyle(
                                      color: textMutedColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created ${formatDateTime(record.createdAt)}',
                                    style: const TextStyle(
                                      color: textSubtleColor,
                                    ),
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

        final detailPane = PanelCard(
          title: 'Approval detail',
          fill: true,
          child: approval == null
              ? const EmptyState(
                  title: 'No approval selected',
                  body:
                      'Choose a pending approval from the queue to inspect and resolve it.',
                )
              : ListView(
                  children: [
                    if (_run != null)
                      InfoPanel(
                        title: 'Linked run',
                        body:
                            'Run: ${_run!.runId}\nTenant: ${_run!.tenantId}\nAgent: ${_run!.agentId}\nStatus: ${_run!.status}\nSummary: ${blankAsUnknown(_run!.resultSummary)}',
                      ),
                    if (_run != null) const SizedBox(height: 12),
                    _ApprovalPanel(
                      approval: approval,
                      approvalError: _approvalError,
                      resolvingApproval: _resolving,
                      approverController: _approverController,
                      approvalReasonController: _reasonController,
                      onApprove: () => _resolve('approved'),
                      onReject: () => _resolve('rejected'),
                    ),
                  ],
                ),
        );

        if (stacked) {
          return Column(
            children: [
              SizedBox(height: 420, child: queuePane),
              const SizedBox(height: 14),
              Expanded(child: detailPane),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 390, child: queuePane),
            const SizedBox(width: 14),
            Expanded(child: detailPane),
          ],
        );
      },
    );
  }
}

class RunsPage extends StatefulWidget {
  const RunsPage({required this.operationsApi, required this.initialRunId});

  final OperationsApi operationsApi;
  final String? initialRunId;

  @override
  State<RunsPage> createState() => _RunsPageState();
}

class _RunsPageState extends State<RunsPage> {
  bool _loadingRuns = true;
  bool _loadingDetail = false;
  bool _resolvingApproval = false;
  String? _runsError;
  String? _detailError;
  String? _approvalError;
  List<RunRecord> _runs = <RunRecord>[];
  String? _selectedRunId;
  RunRecord? _runDetail;
  HarnessExecutionStateRecord? _harnessExecutionState;
  bool _harnessExecutionStateUnavailable = false;
  String? _harnessExecutionStateError;
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
  void didUpdateWidget(covariant RunsPage oldWidget) {
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
      String? selected;
      for (final candidate in <String?>[
        preferredRunId,
        _selectedRunId,
        runs.isNotEmpty ? runs.first.runId : null,
      ]) {
        if (candidate != null &&
            runs.any((RunRecord run) => run.runId == candidate)) {
          selected = candidate;
          break;
        }
      }
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
          _harnessExecutionState = null;
          _harnessExecutionStateUnavailable = false;
          _harnessExecutionStateError = null;
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
      _harnessExecutionStateError = null;
      _approvalError = null;
    });
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        widget.operationsApi.getRun(runId),
        widget.operationsApi.listApprovals(query: ApprovalQuery(runId: runId)),
        widget.operationsApi.listArtifacts(runId: runId),
        widget.operationsApi.listAudits(runId: runId),
      ]);
      HarnessExecutionStateRecord? harnessExecutionState;
      var harnessExecutionStateUnavailable = false;
      String? harnessExecutionStateError;
      try {
        harnessExecutionState = await widget.operationsApi
            .getRunHarnessExecutionState(runId);
      } catch (error) {
        final message = error.toString();
        if (message.toLowerCase().contains('unavailable')) {
          harnessExecutionStateUnavailable = true;
        } else {
          harnessExecutionStateError = message;
        }
      }
      setState(() {
        _runDetail = results[0] as RunRecord;
        final approvals = results[1] as List<ApprovalRecord>;
        _harnessExecutionState = harnessExecutionState;
        _harnessExecutionStateUnavailable = harnessExecutionStateUnavailable;
        _harnessExecutionStateError = harnessExecutionStateError;
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
      return ErrorState(message: _runsError!, onRetry: () => _loadRuns());
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
          harnessExecutionState: _harnessExecutionState,
          harnessExecutionStateUnavailable: _harnessExecutionStateUnavailable,
          harnessExecutionStateError: _harnessExecutionStateError,
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
    return PanelCard(
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
                ? const EmptyState(
                    title: 'No runs found',
                    body:
                        'Start a run through the control plane to inspect it here.',
                  )
                : ListView.separated(
                    itemCount: runs.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: borderColor),
                    itemBuilder: (BuildContext context, int index) {
                      final run = runs[index];
                      final selected = run.runId == selectedRunId;
                      return InkWell(
                        onTap: () => onSelect(run.runId),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? panelRaisedColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? accentColor
                                  : Colors.transparent,
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
                                        color: textPrimaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  StatusPill(
                                    label: run.status,
                                    color: statusColor(run.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                run.runId,
                                style: const TextStyle(
                                  color: textSubtleColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${run.tenantId} • ${run.agentId} • ${blankAsUnknown(run.invocationMode)}',
                                style: const TextStyle(color: textMutedColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatDateTime(run.createdAt),
                                style: const TextStyle(color: textSubtleColor),
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
    required this.harnessExecutionState,
    required this.harnessExecutionStateUnavailable,
    required this.harnessExecutionStateError,
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
  final HarnessExecutionStateRecord? harnessExecutionState;
  final bool harnessExecutionStateUnavailable;
  final String? harnessExecutionStateError;
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
      return const PanelCard(
        title: 'Run detail',
        fill: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return PanelCard(
        title: 'Run detail',
        fill: true,
        child: ErrorState(message: error!, onRetry: onRetry),
      );
    }
    if (run == null) {
      return const PanelCard(
        title: 'Run detail',
        fill: true,
        child: EmptyState(
          title: 'No run selected',
          body: 'Choose a run from the list to inspect its runtime state.',
        ),
      );
    }

    final profile = run!.profileSnapshot;
    return PanelCard(
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
              StatusPill(label: run!.status, color: statusColor(run!.status)),
            ],
          ),
          const SizedBox(height: 14),
          InfoPanel(
            title: 'Identity',
            body:
                'Run: ${run!.runId}\nTenant: ${run!.tenantId}\nAgent: ${run!.agentId}\nActor: ${run!.actorId}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Timing',
            body:
                'Created: ${formatDateTime(run!.createdAt)}\nStarted: ${formatDateTime(run!.startedAt)}\nCompleted: ${formatDateTime(run!.completedAt)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Execution',
            body:
                'Invocation mode: ${blankAsUnknown(run!.invocationMode)}\nRequested autonomy: ${blankAsUnknown(run!.requestedAutonomyMode)}\nWait reason: ${blankAsUnknown(run!.waitReason)}\nArtifact manifest: ${blankAsUnknown(run!.artifactManifestReference)}',
          ),
          const SizedBox(height: 12),
          _HarnessExecutionStatePanel(
            state: harnessExecutionState,
            unavailable: harnessExecutionStateUnavailable,
            error: harnessExecutionStateError,
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
          InfoPanel(
            title: 'Source context',
            body:
                'Interface: ${blankAsUnknown(run!.source.interface)}\nInstallation: ${blankAsUnknown(run!.source.installationId)}\nWorkspace: ${blankAsUnknown(run!.source.externalWorkspaceId)}\nConversation: ${blankAsUnknown(run!.source.conversationId)}\nChannel: ${blankAsUnknown(run!.source.channelId)}\nThread: ${blankAsUnknown(run!.source.threadId)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Runtime profile',
            body:
                'Profile: ${profile.profileId}\nVersion: ${profile.version}\nModel: ${blankAsUnknown(profile.model)}\nProvider: ${blankAsUnknown(profile.provider)}\nApproval mode: ${blankAsUnknown(profile.approvalPolicy.mode)}\nMax run seconds: ${profile.runtimeLimits.maxRunSeconds}\nMax turns: ${profile.runtimeLimits.maxTurns}',
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Allowed capabilities',
            tags: profile.allowedCapabilities,
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Denied capabilities',
            tags: profile.deniedCapabilities,
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Storage scope',
            body:
                'Namespace: ${blankAsUnknown(profile.storageScope.namespace)}\nArtifact prefix: ${blankAsUnknown(profile.storageScope.artifactPrefix)}\nRetention days: ${profile.storageScope.retentionDays}',
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Secret bindings',
            tags: profile.secretBindings
                .map(
                  (SecretBindingRefSnapshot binding) =>
                      '${binding.name} (${binding.provider})',
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SubsectionTitle('Operator actions'),
          const SizedBox(height: 8),
          if (run!.operatorActions.isEmpty)
            const InfoPanel(
              title: 'Operator actions',
              body: 'No operator actions were recorded for this run.',
            )
          else
            ...run!.operatorActions.map(
              (OperatorActionRecord action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoPanel(
                  title: action.action,
                  body:
                      'Actor: ${blankAsUnknown(action.actorId)}\nReason: ${blankAsUnknown(action.reason)}\nOccurred: ${formatDateTime(action.occurredAt)}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          SubsectionTitle('Artifacts'),
          const SizedBox(height: 8),
          if (artifacts.isEmpty)
            const InfoPanel(
              title: 'Artifacts',
              body: 'No artifacts recorded for this run.',
            )
          else
            ...artifacts.map(
              (ArtifactRecord artifact) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoPanel(
                  title: artifact.kind,
                  body:
                      'Reference: ${artifact.reference}\nCreated: ${formatDateTime(artifact.createdAt)}\nRetention days: ${artifact.retentionDays}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          SubsectionTitle('Audit trail'),
          const SizedBox(height: 8),
          if (audits.isEmpty)
            const InfoPanel(
              title: 'Audit',
              body: 'No audit records found for this run.',
            )
          else
            ...audits.map(
              (AuditRecord audit) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoPanel(
                  title: audit.action,
                  body:
                      'Resource: ${audit.resourceType}/${audit.resourceId}\nUser: ${blankAsUnknown(audit.userId)}\nOccurred: ${formatDateTime(audit.occurredAt)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HarnessExecutionStatePanel extends StatelessWidget {
  const _HarnessExecutionStatePanel({
    required this.state,
    required this.unavailable,
    required this.error,
  });

  final HarnessExecutionStateRecord? state;
  final bool unavailable;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return const InfoPanel(
        title: 'Harness execution state',
        body:
            'This deployment mode cannot inspect local harness session files. Switch to local mode to inspect workflow execution state for this run.',
      );
    }
    if (error != null) {
      return InfoPanel(title: 'Harness execution state', body: error!);
    }
    if (state == null) {
      return const InfoPanel(
        title: 'Harness execution state',
        body: 'No harness session state was recorded for this run.',
      );
    }

    final session = state!.session;
    final workflow = session?.workflowState;
    final blocker = workflow?.blocker ?? session?.blocker;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Harness execution state',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: session?.status.isNotEmpty == true
                    ? session!.status
                    : state!.runStatus,
                color: statusColor(
                  session?.status.isNotEmpty == true
                      ? _normalizedHarnessStatus(session!.status)
                      : state!.runStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricCard(
                label: 'Current node',
                value: blankAsUnknown(workflow?.currentNodeId ?? ''),
                tone: accentColor,
                detail: 'Active workflow node',
              ),
              MetricCard(
                label: 'Transitions',
                value: '${workflow?.transitionCount ?? 0}',
                tone: infoColor,
                detail: 'Recorded workflow hops',
              ),
              MetricCard(
                label: 'Node results',
                value: '${workflow?.nodeResults.length ?? 0}',
                tone: successColor,
                detail: 'Persisted node outcomes',
              ),
              MetricCard(
                label: 'State source',
                value: blankAsUnknown(state!.stateSource),
                tone: warningColor,
                detail: 'Manifest/session origin',
              ),
            ],
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Session',
            body:
                'Run status: ${blankAsUnknown(state!.runStatus)}\nWait reason: ${blankAsUnknown(state!.runWaitReason)}\nWorkflow: ${blankAsUnknown(session?.workflowName ?? '')}\nPending question: ${blankAsUnknown(session?.pendingQuestion ?? '')}\nWaiting reason: ${blankAsUnknown(session?.waitingReason ?? workflow?.waitingReason ?? '')}\nSummary: ${blankAsUnknown(session?.summary ?? state!.resultSummary)}\nError: ${blankAsUnknown(session?.error ?? '')}',
          ),
          const SizedBox(height: 10),
          InfoPanel(
            title: 'Execution files',
            body:
                'Session ID: ${blankAsUnknown(state!.manifest.sessionId)}\nWorking directory: ${blankAsUnknown(state!.manifest.workingDirectory)}\nCommand: ${blankAsUnknown(state!.manifest.command.join(' '))}\nRequest file: ${blankAsUnknown(state!.manifest.requestFile)}\nGoal file: ${blankAsUnknown(state!.manifest.goalFile)}\nStdout file: ${blankAsUnknown(state!.manifest.stdoutFile)}\nStderr file: ${blankAsUnknown(state!.manifest.stderrFile)}\nSession file: ${blankAsUnknown(state!.manifest.sessionFile)}\nHarness state file: ${blankAsUnknown(state!.manifest.harnessStateFile)}',
          ),
          if (blocker != null) ...<Widget>[
            const SizedBox(height: 10),
            InfoPanel(
              title: 'Blocker',
              body:
                  'Code: ${blankAsUnknown(blocker.code)}\nNode: ${blankAsUnknown(blocker.nodeId)}\nRetryable: ${blocker.retryable ? 'yes' : 'no'}\nSummary: ${blankAsUnknown(blocker.summary)}',
            ),
          ],
          if (workflow != null &&
              (workflow.nodeVisitCounts.isNotEmpty ||
                  workflow.nodeFailureCounts.isNotEmpty)) ...<Widget>[
            const SizedBox(height: 10),
            InfoPanel(
              title: 'Workflow counters',
              body: _joinNonEmpty(<String>[
                if (workflow.artifactDir.isNotEmpty)
                  'Artifact dir: ${workflow.artifactDir}',
                if (workflow.nodeVisitCounts.isNotEmpty)
                  'Visits: ${_formatIntMap(workflow.nodeVisitCounts)}',
                if (workflow.nodeFailureCounts.isNotEmpty)
                  'Failures: ${_formatIntMap(workflow.nodeFailureCounts)}',
              ]),
            ),
          ],
          if (session?.finalResult != null) ...<Widget>[
            const SizedBox(height: 10),
            InfoPanel(
              title: 'Final result',
              body: _joinNonEmpty(<String>[
                'Status: ${blankAsUnknown(session!.finalResult!.status)}',
                'Summary: ${blankAsUnknown(session.finalResult!.summary)}',
                if (session.finalResult!.artifacts.isNotEmpty)
                  'Artifacts: ${session.finalResult!.artifacts.join(', ')}',
                if (session.finalResult!.data.isNotEmpty)
                  'Data: ${_formatStringMap(session.finalResult!.data)}',
              ]),
            ),
          ],
          const SizedBox(height: 10),
          SubsectionTitle('Node results'),
          const SizedBox(height: 8),
          if (workflow == null || workflow.nodeResults.isEmpty)
            const InfoPanel(
              title: 'Node results',
              body: 'No workflow node results were captured for this run.',
            )
          else
            ...workflow.nodeResults.map(
              (HarnessExecutionNodeResultRecord result) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoPanel(
                  title: result.nodeId,
                  body: _joinNonEmpty(<String>[
                    'Outcome: ${blankAsUnknown(result.outcome)}',
                    if (result.gateStatus.isNotEmpty)
                      'Gate status: ${result.gateStatus}',
                    'Retryable: ${result.retryable ? 'yes' : 'no'}',
                    if (result.errorCode.isNotEmpty)
                      'Error code: ${result.errorCode}',
                    'Summary: ${blankAsUnknown(result.summary)}',
                    if (result.artifacts.isNotEmpty)
                      'Artifacts: ${result.artifacts.join(', ')}',
                    if (result.metadata.isNotEmpty)
                      'Metadata: ${_formatStringMap(result.metadata)}',
                  ]),
                ),
              ),
            ),
          if (state!.manifest.metadata.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            InfoPanel(
              title: 'Manifest metadata',
              body: _formatStringMap(state!.manifest.metadata),
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
      .join('\n');
}

String _normalizedHarnessStatus(String status) {
  switch (status.trim()) {
    case 'waiting_for_user':
      return 'waiting_user';
    case 'waiting_for_approval':
      return 'waiting_approval';
    default:
      return status.trim();
  }
}

String _formatStringMap(Map<String, String> values) {
  if (values.isEmpty) {
    return 'not set';
  }
  final entries = values.entries.toList()
    ..sort((MapEntry<String, String> a, MapEntry<String, String> b) {
      return a.key.compareTo(b.key);
    });
  return entries
      .map((MapEntry<String, String> entry) => '${entry.key}: ${entry.value}')
      .join('\n');
}

String _formatIntMap(Map<String, int> values) {
  if (values.isEmpty) {
    return 'not set';
  }
  final entries = values.entries.toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
      return a.key.compareTo(b.key);
    });
  return entries
      .map((MapEntry<String, int> entry) => '${entry.key}=${entry.value}')
      .join(', ');
}

class ArtifactsPage extends StatefulWidget {
  const ArtifactsPage({required this.operationsApi});

  final OperationsApi operationsApi;

  @override
  State<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends State<ArtifactsPage> {
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
      return ErrorState(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        PanelCard(
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
        PanelCard(
          title: 'Artifacts',
          child: _artifacts.isEmpty
              ? const EmptyState(
                  title: 'No artifacts found',
                  body: 'No artifact records match the current filters.',
                )
              : Column(
                  children: _artifacts
                      .map(
                        (ArtifactRecord artifact) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InfoPanel(
                            title: artifact.kind,
                            body:
                                'Artifact ${artifact.artifactId}\nTenant: ${artifact.tenantId}\nAgent: ${artifact.agentId}\nRun: ${artifact.runId}\nReference: ${artifact.reference}\nCreated: ${formatDateTime(artifact.createdAt)}\nRetention days: ${artifact.retentionDays}',
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

class AuditsPage extends StatefulWidget {
  const AuditsPage({required this.operationsApi});

  final OperationsApi operationsApi;

  @override
  State<AuditsPage> createState() => _AuditsPageState();
}

class _AuditsPageState extends State<AuditsPage> {
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
      return ErrorState(message: _error!, onRetry: _load);
    }
    return ListView(
      children: [
        PanelCard(
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
        PanelCard(
          title: 'Audit records',
          child: _audits.isEmpty
              ? const EmptyState(
                  title: 'No audits found',
                  body: 'No audit records match the current filters.',
                )
              : Column(
                  children: _audits
                      .map(
                        (AuditRecord audit) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InfoPanel(
                            title: audit.action,
                            body:
                                'Audit ${audit.auditId}\nTenant: ${audit.tenantId}\nAgent: ${audit.agentId}\nRun: ${audit.runId}\nResource: ${audit.resourceType}/${audit.resourceId}\nUser: ${blankAsUnknown(audit.userId)}\nAdministrative: ${audit.administrative}\nOccurred: ${formatDateTime(audit.occurredAt)}',
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
      return const InfoPanel(
        title: 'Approval',
        body: 'No approval record is attached to this run.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
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
                    color: textPrimaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: approval!.decision,
                color: approval!.decision == 'approved'
                    ? successColor
                    : approval!.decision == 'rejected'
                    ? dangerColor
                    : warningColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Request ${approval!.approvalRequestId}\nCreated ${formatDateTime(approval!.createdAt)}\nApprover ${blankAsUnknown(approval!.approverId)}\nReason ${blankAsUnknown(approval!.reason)}',
            style: const TextStyle(color: textMutedColor, height: 1.45),
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
              Text(approvalError!, style: const TextStyle(color: dangerColor)),
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
