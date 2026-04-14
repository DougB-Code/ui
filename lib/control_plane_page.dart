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
  bool _tenantActionLoading = false;
  bool _agentActionLoading = false;
  bool _installationActionLoading = false;
  bool _conversationStateLoading = false;
  String? _error;
  String? _tenantActionError;
  String? _agentActionError;
  String? _installationActionError;
  String? _conversationStateError;
  List<UserRecord> _users = <UserRecord>[];
  List<TenantRecord> _tenants = <TenantRecord>[];
  List<MembershipRecord> _memberships = <MembershipRecord>[];
  List<AgentRecord> _agents = <AgentRecord>[];
  List<InstallationRecord> _installations = <InstallationRecord>[];
  List<ConversationRecord> _conversations = <ConversationRecord>[];
  List<ChannelRouteRecord> _routes = <ChannelRouteRecord>[];
  List<RunRecord> _runs = <RunRecord>[];
  List<ApprovalRecord> _approvals = <ApprovalRecord>[];
  ConversationStateRecord? _conversationState;
  String? _selectedTenantId;
  String? _selectedAgentId;
  String? _selectedInstallationId;
  String? _selectedConversationId;
  final TextEditingController _tenantActorController = TextEditingController();
  final TextEditingController _tenantReasonController = TextEditingController();
  final TextEditingController _agentActorController = TextEditingController();
  final TextEditingController _agentReasonController = TextEditingController();
  final TextEditingController _installationActorController =
      TextEditingController();
  final TextEditingController _installationChannelsController =
      TextEditingController();
  final TextEditingController _installationUsersController =
      TextEditingController();
  final TextEditingController _installationAgentsController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tenantActorController.dispose();
    _tenantReasonController.dispose();
    _agentActorController.dispose();
    _agentReasonController.dispose();
    _installationActorController.dispose();
    _installationChannelsController.dispose();
    _installationUsersController.dispose();
    _installationAgentsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _conversationStateError = null;
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
      final users = results[0] as List<UserRecord>;
      final tenants = results[1] as List<TenantRecord>;
      final memberships = results[2] as List<MembershipRecord>;
      final agents = results[3] as List<AgentRecord>;
      final installations = results[4] as List<InstallationRecord>;
      final conversations = results[5] as List<ConversationRecord>;
      final routes = results[6] as List<ChannelRouteRecord>;
      final runs = results[7] as List<RunRecord>;
      final approvals = results[8] as List<ApprovalRecord>;

      final selectedTenantId = _preserveSelection(
        _selectedTenantId,
        tenants.map((TenantRecord record) => record.tenantId).toList(),
      );
      final selectedAgentId = _preserveSelection(
        _selectedAgentId,
        agents.map((AgentRecord record) => record.agentId).toList(),
      );
      final selectedInstallationId = _preserveSelection(
        _selectedInstallationId,
        installations
            .map((InstallationRecord record) => record.installationId)
            .toList(),
      );
      final selectedConversationId = _preserveSelection(
        _selectedConversationId,
        conversations
            .map((ConversationRecord record) => record.conversationId)
            .toList(),
      );

      ConversationStateRecord? conversationState;
      String? conversationStateError;
      if (selectedConversationId != null) {
        try {
          conversationState = await widget.controlPlaneApi.getConversationState(
            selectedConversationId,
          );
        } catch (error) {
          conversationStateError = error.toString();
        }
      }

      setState(() {
        _users = users;
        _tenants = tenants;
        _memberships = memberships;
        _agents = agents;
        _installations = installations;
        _conversations = conversations;
        _routes = routes;
        _runs = runs;
        _approvals = approvals;
        _selectedTenantId = selectedTenantId;
        _selectedAgentId = selectedAgentId;
        _selectedInstallationId = selectedInstallationId;
        _selectedConversationId = selectedConversationId;
        _conversationState = conversationState;
        _conversationStateError = conversationStateError;
        _loading = false;
      });
      _syncInstallationEditors();
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String? _preserveSelection(String? current, List<String> ids) {
    if (current != null && ids.contains(current)) {
      return current;
    }
    return ids.isEmpty ? null : ids.first;
  }

  void _syncInstallationEditors() {
    final installation = _selectedInstallation;
    if (installation == null) {
      _installationChannelsController.text = '';
      _installationUsersController.text = '';
      _installationAgentsController.text = '';
      return;
    }
    _installationChannelsController.text = installation.allowedChannelIds.join(
      ', ',
    );
    _installationUsersController.text = installation.allowedExternalUserIds.join(
      ', ',
    );
    _installationAgentsController.text = installation.allowedAgentIds.join(
      ', ',
    );
  }

  TenantRecord? get _selectedTenant {
    for (final tenant in _tenants) {
      if (tenant.tenantId == _selectedTenantId) {
        return tenant;
      }
    }
    return null;
  }

  AgentRecord? get _selectedAgent {
    for (final agent in _agents) {
      if (agent.agentId == _selectedAgentId) {
        return agent;
      }
    }
    return null;
  }

  InstallationRecord? get _selectedInstallation {
    for (final installation in _installations) {
      if (installation.installationId == _selectedInstallationId) {
        return installation;
      }
    }
    return null;
  }

  ConversationRecord? get _selectedConversation {
    for (final conversation in _conversations) {
      if (conversation.conversationId == _selectedConversationId) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> _selectConversation(String conversationId) async {
    setState(() {
      _selectedConversationId = conversationId;
      _conversationState = null;
      _conversationStateError = null;
      _conversationStateLoading = true;
    });
    try {
      final state = await widget.controlPlaneApi.getConversationState(
        conversationId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _conversationState = state;
        _conversationStateLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _conversationStateError = error.toString();
        _conversationStateLoading = false;
      });
    }
  }

  Future<void> _disableTenant() async {
    final tenant = _selectedTenant;
    if (tenant == null) {
      return;
    }
    if (_tenantActorController.text.trim().isEmpty) {
      setState(() {
        _tenantActionError = 'Actor ID is required to disable a tenant.';
      });
      return;
    }
    setState(() {
      _tenantActionLoading = true;
      _tenantActionError = null;
    });
    try {
      final updated = await widget.controlPlaneApi.disableTenant(
        tenantId: tenant.tenantId,
        actorId: _tenantActorController.text.trim(),
        reason: _tenantReasonController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _tenants = _tenants
            .map(
              (TenantRecord record) =>
                  record.tenantId == updated.tenantId ? updated : record,
            )
            .toList();
      });
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tenantActionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _tenantActionLoading = false);
      }
    }
  }

  Future<void> _disableAgent() async {
    final agent = _selectedAgent;
    if (agent == null) {
      return;
    }
    if (_agentActorController.text.trim().isEmpty) {
      setState(() {
        _agentActionError = 'Actor ID is required to disable an agent.';
      });
      return;
    }
    setState(() {
      _agentActionLoading = true;
      _agentActionError = null;
    });
    try {
      final updated = await widget.controlPlaneApi.disableAgent(
        agentId: agent.agentId,
        actorId: _agentActorController.text.trim(),
        reason: _agentReasonController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _agents = _agents
            .map(
              (AgentRecord record) =>
                  record.agentId == updated.agentId ? updated : record,
            )
            .toList();
      });
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _agentActionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _agentActionLoading = false);
      }
    }
  }

  Future<void> _saveInstallationAccess() async {
    final installation = _selectedInstallation;
    if (installation == null) {
      return;
    }
    if (_installationActorController.text.trim().isEmpty) {
      setState(() {
        _installationActionError =
            'Actor ID is required to update installation access.';
      });
      return;
    }
    setState(() {
      _installationActionLoading = true;
      _installationActionError = null;
    });
    try {
      final updated = await widget.controlPlaneApi.updateInstallationAccess(
        installationId: installation.installationId,
        actorId: _installationActorController.text.trim(),
        allowedChannelIds: _parseCsv(_installationChannelsController.text),
        allowedExternalUserIds: _parseCsv(_installationUsersController.text),
        allowedAgentIds: _parseCsv(_installationAgentsController.text),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _installations = _installations
            .map(
              (InstallationRecord record) =>
                  record.installationId == updated.installationId
                  ? updated
                  : record,
            )
            .toList();
      });
      _syncInstallationEditors();
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _installationActionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _installationActionLoading = false);
      }
    }
  }

  List<String> _parseCsv(String input) {
    return input
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
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
        Wrap(
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
              detail: 'Mapped integrations',
            ),
            _MetricCard(
              label: 'Conversations',
              value: '${_conversations.length}',
              tone: _info,
              detail: 'Conversation records',
            ),
            _MetricCard(
              label: 'Unhealthy routes',
              value:
                  '${_routes.where((ChannelRouteRecord route) => route.status != 'active').length}',
              tone:
                  _routes.any((ChannelRouteRecord route) => route.status != 'active')
                  ? _danger
                  : _success,
              detail: 'Non-active channel mappings',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Tenants',
            selectedId: _selectedTenantId,
            onSelect: (String id) => setState(() => _selectedTenantId = id),
            items: _tenants
                .map(
                  (TenantRecord tenant) => _EntityItem(
                    id: tenant.tenantId,
                    title: tenant.displayName,
                    subtitle:
                        '${tenant.tenantId} • ${tenant.status} • ${tenant.type}',
                    meta:
                        '${_blankAsUnknown(tenant.region)} • template ${tenant.defaultAgentTemplate}',
                    tags: tenant.enabledIntegrations,
                  ),
                )
                .toList(),
          ),
          right: _buildTenantDetail(),
        ),
        const SizedBox(height: 14),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Control-plane agents',
            selectedId: _selectedAgentId,
            onSelect: (String id) => setState(() => _selectedAgentId = id),
            items: _agents
                .map(
                  (AgentRecord agent) => _EntityItem(
                    id: agent.agentId,
                    title: agent.name,
                    subtitle:
                        '${agent.agentId} • ${agent.status} • ${agent.tenantId}',
                    meta:
                        'Template ${agent.templateId} • onboarding ${_blankAsUnknown(agent.onboardingState)}',
                    tags: <String>[
                      ...agent.integrationBindings,
                      ...agent.enabledCapabilities.take(3),
                    ],
                  ),
                )
                .toList(),
          ),
          right: _buildAgentDetail(),
        ),
        const SizedBox(height: 14),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Installations',
            selectedId: _selectedInstallationId,
            onSelect: (String id) {
              setState(() => _selectedInstallationId = id);
              _syncInstallationEditors();
            },
            items: _installations
                .map(
                  (InstallationRecord installation) => _EntityItem(
                    id: installation.installationId,
                    title:
                        '${installation.providerType}:${installation.externalWorkspaceId}',
                    subtitle:
                        '${installation.installationId} • ${installation.status}',
                    meta:
                        '${installation.mappedTenantId} -> ${installation.mappedDefaultAgentId}',
                    tags: installation.allowedChannelIds.take(3).toList(),
                  ),
                )
                .toList(),
          ),
          right: _buildInstallationDetail(),
        ),
        const SizedBox(height: 14),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Users',
            items: _users
                .map(
                  (UserRecord user) => _EntityItem(
                    id: user.userId,
                    title: user.displayName,
                    subtitle: '${user.userId} • ${user.status}',
                    meta: user.kind,
                  ),
                )
                .toList(),
          ),
          right: _EntityPanel(
            title: 'Memberships',
            items: _memberships
                .map(
                  (MembershipRecord membership) => _EntityItem(
                    id: '${membership.tenantId}:${membership.userId}',
                    title: membership.userId,
                    subtitle: membership.tenantId,
                    meta: '${membership.role} • ${_formatDateTime(membership.createdAt)}',
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        _TwoPanelRow(
          left: _EntityPanel(
            title: 'Conversations',
            selectedId: _selectedConversationId,
            onSelect: _selectConversation,
            items: _conversations
                .map(
                  (ConversationRecord conversation) => _EntityItem(
                    id: conversation.conversationId,
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
          right: _buildConversationDetail(),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Channel routes',
          trailing: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          child: _routes.isEmpty
              ? const _EmptyState(
                  title: 'No routes',
                  body: 'No channel routes have been provisioned yet.',
                )
              : Column(
                  children: _routes
                      .map(
                        (ChannelRouteRecord route) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InfoPanel(
                            title:
                                '${route.providerType}:${_blankAsUnknown(route.channelId)}',
                            body:
                                'Route: ${route.routeId}\nConversation: ${route.conversationId}\nInstallation: ${_blankAsUnknown(route.installationId)}\nThread: ${_blankAsUnknown(route.threadId)}\nStatus: ${route.status}\nCreated: ${_formatDateTime(route.createdAt)}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTenantDetail() {
    final tenant = _selectedTenant;
    if (tenant == null) {
      return const _Panel(
        title: 'Tenant detail',
        child: _EmptyState(
          title: 'No tenant selected',
          body: 'Choose a tenant to inspect retention, onboarding, and live management actions.',
        ),
      );
    }
    return _Panel(
      title: 'Tenant detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoPanel(
            title: tenant.displayName,
            body:
                'Tenant: ${tenant.tenantId}\nStatus: ${tenant.status}\nType: ${tenant.type}\nRegion: ${_blankAsUnknown(tenant.region)}\nOwner: ${tenant.ownerUserId}\nOnboarding: ${_blankAsUnknown(tenant.onboardingState)}\nCreated: ${_formatDateTime(tenant.createdAt)}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Policies',
            body:
                'Default template: ${tenant.defaultAgentTemplate}\nApproval mode: ${_blankAsUnknown(tenant.defaultApprovalMode)}\nMax run seconds: ${tenant.maxRunSeconds}\nMax turns: ${tenant.maxTurns}\nBudget max runs/day: ${tenant.maxRunsPerDay}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Retention',
            body:
                'Run history days: ${tenant.runHistoryDays}\nArtifact days: ${tenant.artifactDays}\nAudit log days: ${tenant.auditLogDays}',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tenantActorController,
            decoration: const InputDecoration(labelText: 'Disable actor ID'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _tenantReasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Disable reason'),
          ),
          if (_tenantActionError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(_tenantActionError!, style: const TextStyle(color: _danger)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _tenantActionLoading ? null : _disableTenant,
            child: _tenantActionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Disable tenant'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentDetail() {
    final agent = _selectedAgent;
    if (agent == null) {
      return const _Panel(
        title: 'Agent detail',
        child: _EmptyState(
          title: 'No agent selected',
          body: 'Choose a control-plane agent to inspect bindings and management actions.',
        ),
      );
    }
    return _Panel(
      title: 'Agent detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoPanel(
            title: agent.name,
            body:
                'Agent: ${agent.agentId}\nTenant: ${agent.tenantId}\nStatus: ${agent.status}\nTemplate: ${agent.templateId}\nOnboarding: ${_blankAsUnknown(agent.onboardingState)}\nApproval override: ${_blankAsUnknown(agent.approvalOverrideMode)}\nRuntime override: ${agent.runtimeOverrideMaxRunSeconds}/${agent.runtimeOverrideMaxTurns}',
          ),
          const SizedBox(height: 12),
          _TagSection(
            title: 'Enabled capabilities',
            tags: agent.enabledCapabilities,
          ),
          const SizedBox(height: 12),
          _TagSection(
            title: 'Denied capabilities',
            tags: agent.deniedCapabilities,
          ),
          const SizedBox(height: 12),
          _TagSection(
            title: 'Integration bindings',
            tags: agent.integrationBindings,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _agentActorController,
            decoration: const InputDecoration(labelText: 'Disable actor ID'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _agentReasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Disable reason'),
          ),
          if (_agentActionError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(_agentActionError!, style: const TextStyle(color: _danger)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _agentActionLoading ? null : _disableAgent,
            child: _agentActionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Disable agent'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallationDetail() {
    final installation = _selectedInstallation;
    if (installation == null) {
      return const _Panel(
        title: 'Installation access',
        child: _EmptyState(
          title: 'No installation selected',
          body: 'Choose an installation to inspect route health and update live access controls.',
        ),
      );
    }
    final relatedRoutes = _routes
        .where(
          (ChannelRouteRecord route) =>
              route.installationId == installation.installationId,
        )
        .toList();
    final mappedAgent = _agents.where(
      (AgentRecord agent) =>
          agent.agentId == installation.mappedDefaultAgentId,
    );

    return _Panel(
      title: 'Installation access',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoPanel(
            title:
                '${installation.providerType}:${installation.externalWorkspaceId}',
            body:
                'Installation: ${installation.installationId}\nStatus: ${installation.status}\nTenant: ${installation.mappedTenantId}\nDefault agent: ${installation.mappedDefaultAgentId}\nInstalled by: ${installation.installedBy}\nInstalled at: ${_formatDateTime(installation.installedAt)}\nLast verified: ${_formatDateTime(installation.lastVerifiedAt)}\nAdapter version: ${installation.adapterVersion}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Route-aware health',
            body:
                'Linked routes: ${relatedRoutes.length}\nUnhealthy routes: ${relatedRoutes.where((ChannelRouteRecord route) => route.status != 'active').length}\nMapped agent onboarding: ${mappedAgent.isEmpty ? 'not set' : _blankAsUnknown(mappedAgent.first.onboardingState)}',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _installationActorController,
            decoration: const InputDecoration(labelText: 'Actor ID'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _installationChannelsController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Allowed channel IDs (comma separated)',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _installationUsersController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Allowed external user IDs (comma separated)',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _installationAgentsController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Allowed agent IDs (comma separated)',
            ),
          ),
          if (_installationActionError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _installationActionError!,
              style: const TextStyle(color: _danger),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _installationActionLoading ? null : _saveInstallationAccess,
            child: _installationActionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save installation access'),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationDetail() {
    final conversation = _selectedConversation;
    if (conversation == null) {
      return const _Panel(
        title: 'Conversation detail',
        child: _EmptyState(
          title: 'No conversation selected',
          body: 'Choose a conversation to inspect recent turns and pending execution state.',
        ),
      );
    }

    final latestRun = _runs
        .where(
          (RunRecord run) =>
              run.source.conversationId == conversation.conversationId ||
              run.runId == _conversationState?.latestRunId,
        )
        .fold<RunRecord?>(null, (RunRecord? best, RunRecord current) {
          if (best == null) {
            return current;
          }
          final bestTime =
              best.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final currentTime =
              current.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return currentTime.isAfter(bestTime) ? current : best;
        });
    final latestApprovalId = _conversationState?.latestApprovalRequestId ?? '';
    final latestApproval = _approvals
        .where(
          (ApprovalRecord record) =>
              record.approvalRequestId == latestApprovalId ||
              (latestRun != null && record.runId == latestRun.runId),
        )
        .fold<ApprovalRecord?>(null, (ApprovalRecord? best, ApprovalRecord current) {
          if (best == null) {
            return current;
          }
          final bestTime =
              best.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final currentTime =
              current.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return currentTime.isAfter(bestTime) ? current : best;
        });
    final scopedRoutes = _routes
        .where(
          (ChannelRouteRecord route) =>
              route.conversationId == conversation.conversationId,
        )
        .toList();
    final scopedInstallations = _installations.where((InstallationRecord install) {
      return scopedRoutes.any(
        (ChannelRouteRecord route) =>
            route.installationId == install.installationId,
      );
    }).toList();

    if (_conversationStateLoading) {
      return const _Panel(
        title: 'Conversation detail',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _Panel(
      title: 'Conversation detail',
      child: ListView(
        shrinkWrap: true,
        children: [
          _InfoPanel(
            title: conversation.name.isEmpty
                ? conversation.conversationId
                : conversation.name,
            body:
                'Conversation: ${conversation.conversationId}\nTenant: ${conversation.tenantId}\nAgent: ${conversation.agentId}\nKind: ${_blankAsUnknown(conversation.kind)}\nStatus: ${conversation.status}\nCreated: ${_formatDateTime(conversation.createdAt)}',
          ),
          const SizedBox(height: 12),
          if (_conversationStateError != null)
            _InfoPanel(
              title: 'Conversation state',
              body: _conversationStateError!,
            )
          else if (_conversationState == null)
            const _InfoPanel(
              title: 'Conversation state',
              body: 'No persisted conversation state was found.',
            )
          else
            _InfoPanel(
              title: 'Pending execution',
              body:
                  'Latest run: ${_blankAsUnknown(_conversationState!.latestRunId)}\nLatest approval: ${_blankAsUnknown(_conversationState!.latestApprovalRequestId)}\nPending status: ${_conversationState!.pending == null ? 'not pending' : _conversationState!.pending!.status}\nWait reason: ${_conversationState!.pending == null ? 'not waiting' : _blankAsUnknown(_conversationState!.pending!.waitReason)}\nPending question: ${_conversationState!.pending == null ? 'not set' : _blankAsUnknown(_conversationState!.pending!.pendingQuestion)}',
            ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Latest approval',
            body: latestApproval == null
                ? 'No approval record is linked to this conversation.'
                : 'Approval: ${latestApproval.approvalRequestId}\nRun: ${latestApproval.runId}\nDecision: ${latestApproval.decision}\nApprover: ${_blankAsUnknown(latestApproval.approverId)}\nCreated: ${_formatDateTime(latestApproval.createdAt)}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Latest run',
            body: latestRun == null
                ? 'No run is linked to this conversation yet.'
                : 'Run: ${latestRun.runId}\nStatus: ${latestRun.status}\nInvocation: ${_blankAsUnknown(latestRun.invocationMode)}\nCreated: ${_formatDateTime(latestRun.createdAt)}\nSummary: ${_blankAsUnknown(latestRun.resultSummary)}',
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Route and install health',
            body:
                'Routes: ${scopedRoutes.length}\nInstallations: ${scopedInstallations.length}\nUnhealthy routes: ${scopedRoutes.where((ChannelRouteRecord route) => route.status != 'active').length}\nInactive installations: ${scopedInstallations.where((InstallationRecord install) => install.status != 'active').length}',
          ),
          const SizedBox(height: 12),
          _SubsectionTitle('Recent turns'),
          const SizedBox(height: 8),
          if (_conversationState == null || _conversationState!.turns.isEmpty)
            const _InfoPanel(
              title: 'Recent turns',
              body: 'No recent turns were recorded for this conversation.',
            )
          else
            ..._conversationState!.turns.reversed.take(6).map(
              (ConversationTurnItem turn) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InfoPanel(
                  title: '${turn.role} • ${_formatDateTime(turn.createdAt)}',
                  body:
                      '${turn.content}\nActor: ${_blankAsUnknown(turn.actorId)}\nRun: ${_blankAsUnknown(turn.runId)}',
                ),
              ),
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
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final List<String> tags;
}

class _EntityPanel extends StatelessWidget {
  const _EntityPanel({
    required this.title,
    required this.items,
    this.selectedId,
    this.onSelect,
  });

  final String title;
  final List<_EntityItem> items;
  final String? selectedId;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      child: items.isEmpty
          ? const _EmptyState(
              title: 'No records',
              body: 'No live records were returned for this control-plane view.',
            )
          : Column(
              children: items
                  .take(8)
                  .map(
                    (_EntityItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: onSelect == null ? null : () => onSelect!(item.id),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selectedId == item.id ? _panelRaised : _panelAlt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedId == item.id ? _accent : _border,
                            ),
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
