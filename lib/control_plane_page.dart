part of 'main.dart';

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
      (ConversationRecord record) =>
          record.conversationId == _selectedConversationId,
      orElse: () => _conversations.first,
    );
    final scopedRuns =
        _runs
            .where(
              (RunRecord run) =>
                  run.source.conversationId == selected.conversationId,
            )
            .toList()
          ..sort(
            (RunRecord a, RunRecord b) =>
                (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                    ),
          );
    final latestRun = scopedRuns.isEmpty ? null : scopedRuns.first;
    final latestApprovals =
        latestRun == null
              ? <ApprovalRecord>[]
              : _approvals
                    .where(
                      (ApprovalRecord record) =>
                          record.runId == latestRun.runId,
                    )
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
            initialValue: selected.conversationId,
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
