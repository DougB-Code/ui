part of 'main.dart';

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
