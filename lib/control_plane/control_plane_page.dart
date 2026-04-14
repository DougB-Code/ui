import 'package:flutter/material.dart';
import 'package:ui/control_plane/control_plane_api.dart';
import 'package:ui/operations/operations_api.dart';
import 'package:ui/shared/ui.dart';

class ControlPlanePage extends StatefulWidget {
  const ControlPlanePage({
    required this.controlPlaneApi,
    required this.operationsApi,
  });

  final ControlPlaneApi controlPlaneApi;
  final OperationsApi operationsApi;

  @override
  State<ControlPlanePage> createState() => _ControlPlanePageState();
}

class _ControlPlanePageState extends State<ControlPlanePage> {
  bool _loading = true;
  bool _tenantActionLoading = false;
  bool _agentActionLoading = false;
  bool _installationActionLoading = false;
  bool _installationDetailLoading = false;
  bool _conversationDetailLoading = false;
  String? _error;
  String? _tenantActionError;
  String? _agentActionError;
  String? _installationActionError;
  String? _installationDetailError;
  String? _conversationDetailError;
  List<UserRecord> _users = <UserRecord>[];
  List<TenantRecord> _tenants = <TenantRecord>[];
  List<MembershipRecord> _memberships = <MembershipRecord>[];
  List<AgentRecord> _agents = <AgentRecord>[];
  List<InstallationRecord> _installations = <InstallationRecord>[];
  List<ConversationRecord> _conversations = <ConversationRecord>[];
  List<ChannelRouteRecord> _routes = <ChannelRouteRecord>[];
  InstallationDetailRecord? _installationDetail;
  ConversationDetailRecord? _conversationDetail;
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
      _installationDetailError = null;
      _conversationDetailError = null;
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
      ]);
      final users = results[0] as List<UserRecord>;
      final tenants = results[1] as List<TenantRecord>;
      final memberships = results[2] as List<MembershipRecord>;
      final agents = results[3] as List<AgentRecord>;
      final installations = results[4] as List<InstallationRecord>;
      final conversations = results[5] as List<ConversationRecord>;
      final routes = results[6] as List<ChannelRouteRecord>;

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

      InstallationDetailRecord? installationDetail;
      String? installationDetailError;
      if (selectedInstallationId != null) {
        try {
          installationDetail = await widget.controlPlaneApi
              .getInstallationDetail(selectedInstallationId);
        } catch (error) {
          installationDetailError = error.toString();
        }
      }

      ConversationDetailRecord? conversationDetail;
      String? conversationDetailError;
      if (selectedConversationId != null) {
        try {
          conversationDetail = await widget.controlPlaneApi
              .getConversationDetail(selectedConversationId);
        } catch (error) {
          conversationDetailError = error.toString();
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
        _selectedTenantId = selectedTenantId;
        _selectedAgentId = selectedAgentId;
        _selectedInstallationId = selectedInstallationId;
        _selectedConversationId = selectedConversationId;
        _installationDetail = installationDetail;
        _installationDetailError = installationDetailError;
        _conversationDetail = conversationDetail;
        _conversationDetailError = conversationDetailError;
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
    final installation =
        _installationDetail?.installation ?? _selectedInstallation;
    if (installation == null) {
      _installationChannelsController.text = '';
      _installationUsersController.text = '';
      _installationAgentsController.text = '';
      return;
    }
    _installationChannelsController.text = installation.allowedChannelIds.join(
      ', ',
    );
    _installationUsersController.text = installation.allowedExternalUserIds
        .join(', ');
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
      _conversationDetail = null;
      _conversationDetailError = null;
      _conversationDetailLoading = true;
    });
    try {
      final detail = await widget.controlPlaneApi.getConversationDetail(
        conversationId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _conversationDetail = detail;
        _conversationDetailLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _conversationDetailError = error.toString();
        _conversationDetailLoading = false;
      });
    }
  }

  Future<void> _selectInstallation(String installationId) async {
    setState(() {
      _selectedInstallationId = installationId;
      _installationDetail = null;
      _installationDetailError = null;
      _installationDetailLoading = true;
    });
    _syncInstallationEditors();
    try {
      final detail = await widget.controlPlaneApi.getInstallationDetail(
        installationId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _installationDetail = detail;
        _installationDetailLoading = false;
      });
      _syncInstallationEditors();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _installationDetailError = error.toString();
        _installationDetailLoading = false;
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
      return ErrorState(message: _error!, onRetry: _load);
    }

    return ListView(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            MetricCard(
              label: 'Tenants',
              value: '${_tenants.length}',
              tone: accentColor,
              detail: 'Provisioned workspaces',
            ),
            MetricCard(
              label: 'Users',
              value: '${_users.length}',
              tone: infoColor,
              detail: 'Known identities',
            ),
            MetricCard(
              label: 'Agents',
              value: '${_agents.length}',
              tone: successColor,
              detail: 'Control-plane agents',
            ),
            MetricCard(
              label: 'Installations',
              value: '${_installations.length}',
              tone: warningColor,
              detail: 'Mapped integrations',
            ),
            MetricCard(
              label: 'Conversations',
              value: '${_conversations.length}',
              tone: infoColor,
              detail: 'Conversation records',
            ),
            MetricCard(
              label: 'Unhealthy routes',
              value:
                  '${_routes.where((ChannelRouteRecord route) => route.status != 'active').length}',
              tone:
                  _routes.any(
                    (ChannelRouteRecord route) => route.status != 'active',
                  )
                  ? dangerColor
                  : successColor,
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
                        '${blankAsUnknown(tenant.region)} • template ${tenant.defaultAgentTemplate}',
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
                        'Template ${agent.templateId} • onboarding ${blankAsUnknown(agent.onboardingState)}',
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
            onSelect: _selectInstallation,
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
                    meta:
                        '${membership.role} • ${formatDateTime(membership.createdAt)}',
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
                        '${conversation.tenantId} • ${conversation.agentId} • ${blankAsUnknown(conversation.kind)}',
                  ),
                )
                .toList(),
          ),
          right: _buildConversationDetail(),
        ),
        const SizedBox(height: 14),
        PanelCard(
          title: 'Channel routes',
          trailing: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          child: _routes.isEmpty
              ? const EmptyState(
                  title: 'No routes',
                  body: 'No channel routes have been provisioned yet.',
                )
              : Column(
                  children: _routes
                      .map(
                        (ChannelRouteRecord route) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InfoPanel(
                            title:
                                '${route.providerType}:${blankAsUnknown(route.channelId)}',
                            body:
                                'Route: ${route.routeId}\nConversation: ${route.conversationId}\nInstallation: ${blankAsUnknown(route.installationId)}\nThread: ${blankAsUnknown(route.threadId)}\nStatus: ${route.status}\nCreated: ${formatDateTime(route.createdAt)}',
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
      return const PanelCard(
        title: 'Tenant detail',
        child: EmptyState(
          title: 'No tenant selected',
          body:
              'Choose a tenant to inspect retention, onboarding, and live management actions.',
        ),
      );
    }
    return PanelCard(
      title: 'Tenant detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPanel(
            title: tenant.displayName,
            body:
                'Tenant: ${tenant.tenantId}\nStatus: ${tenant.status}\nType: ${tenant.type}\nRegion: ${blankAsUnknown(tenant.region)}\nOwner: ${tenant.ownerUserId}\nOnboarding: ${blankAsUnknown(tenant.onboardingState)}\nCreated: ${formatDateTime(tenant.createdAt)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Policies',
            body:
                'Default template: ${tenant.defaultAgentTemplate}\nApproval mode: ${blankAsUnknown(tenant.defaultApprovalMode)}\nMax run seconds: ${tenant.maxRunSeconds}\nMax turns: ${tenant.maxTurns}\nBudget max runs/day: ${tenant.maxRunsPerDay}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
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
            Text(
              _tenantActionError!,
              style: const TextStyle(color: dangerColor),
            ),
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
      return const PanelCard(
        title: 'Agent detail',
        child: EmptyState(
          title: 'No agent selected',
          body:
              'Choose a control-plane agent to inspect bindings and management actions.',
        ),
      );
    }
    return PanelCard(
      title: 'Agent detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPanel(
            title: agent.name,
            body:
                'Agent: ${agent.agentId}\nTenant: ${agent.tenantId}\nStatus: ${agent.status}\nTemplate: ${agent.templateId}\nOnboarding: ${blankAsUnknown(agent.onboardingState)}\nApproval override: ${blankAsUnknown(agent.approvalOverrideMode)}\nRuntime override: ${agent.runtimeOverrideMaxRunSeconds}/${agent.runtimeOverrideMaxTurns}',
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Enabled capabilities',
            tags: agent.enabledCapabilities,
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Denied capabilities',
            tags: agent.deniedCapabilities,
          ),
          const SizedBox(height: 12),
          TagSection(
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
            Text(
              _agentActionError!,
              style: const TextStyle(color: dangerColor),
            ),
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
    if (_installationDetailLoading) {
      return const PanelCard(
        title: 'Installation detail',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_installationDetailError != null) {
      return PanelCard(
        title: 'Installation detail',
        child: InfoPanel(
          title: 'Installation detail',
          body: _installationDetailError!,
          tone: dangerColor,
        ),
      );
    }

    final detail = _installationDetail;
    final installation = detail?.installation ?? _selectedInstallation;
    if (installation == null) {
      return const PanelCard(
        title: 'Installation detail',
        child: EmptyState(
          title: 'No installation selected',
          body:
              'Choose an installation to inspect route health and update live access controls.',
        ),
      );
    }

    return PanelCard(
      title: 'Installation detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPanel(
            title:
                '${installation.providerType}:${installation.externalWorkspaceId}',
            body:
                'Installation: ${installation.installationId}\nStatus: ${installation.status}\nTenant: ${installation.mappedTenantId}\nDefault agent: ${installation.mappedDefaultAgentId}\nInstalled by: ${installation.installedBy}\nInstalled at: ${formatDateTime(installation.installedAt)}\nLast verified: ${formatDateTime(installation.lastVerifiedAt)}\nAdapter version: ${installation.adapterVersion}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Route-aware health',
            body:
                'Linked routes: ${detail?.routeHealth.linkedRouteCount ?? 0}\nUnhealthy routes: ${detail?.routeHealth.unhealthyRouteCount ?? 0}\nMapped agent: ${blankAsUnknown(detail?.mappedAgent?.agentId ?? installation.mappedDefaultAgentId)}\nMapped agent onboarding: ${blankAsUnknown(detail?.routeHealth.mappedAgentOnboarding ?? '')}',
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
              style: const TextStyle(color: dangerColor),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _installationActionLoading
                ? null
                : _saveInstallationAccess,
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
    if (_conversationDetailLoading) {
      return const PanelCard(
        title: 'Conversation detail',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final detail = _conversationDetail;
    final conversation = detail?.conversation ?? _selectedConversation;
    if (conversation == null) {
      return const PanelCard(
        title: 'Conversation detail',
        child: EmptyState(
          title: 'No conversation selected',
          body:
              'Choose a conversation to inspect recent turns and pending execution state.',
        ),
      );
    }

    return PanelCard(
      title: 'Conversation detail',
      child: ListView(
        shrinkWrap: true,
        children: [
          InfoPanel(
            title: conversation.name.isEmpty
                ? conversation.conversationId
                : conversation.name,
            body:
                'Conversation: ${conversation.conversationId}\nTenant: ${conversation.tenantId}\nAgent: ${conversation.agentId}\nKind: ${blankAsUnknown(conversation.kind)}\nStatus: ${conversation.status}\nCreated: ${formatDateTime(conversation.createdAt)}',
          ),
          const SizedBox(height: 12),
          if (_conversationDetailError != null)
            InfoPanel(
              title: 'Conversation state',
              body: _conversationDetailError!,
              tone: dangerColor,
            )
          else if (detail == null)
            const InfoPanel(
              title: 'Conversation state',
              body: 'No persisted conversation state was found.',
            )
          else
            InfoPanel(
              title: 'Pending execution',
              body:
                  'Latest run: ${blankAsUnknown(detail.state.latestRunId)}\nLatest approval: ${blankAsUnknown(detail.state.latestApprovalRequestId)}\nPending status: ${detail.state.pending == null ? 'not pending' : detail.state.pending!.status}\nWait reason: ${detail.state.pending == null ? 'not waiting' : blankAsUnknown(detail.state.pending!.waitReason)}\nPending question: ${detail.state.pending == null ? 'not set' : blankAsUnknown(detail.state.pending!.pendingQuestion)}',
            ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Latest approval',
            body: detail?.latestApproval == null
                ? 'No approval record is linked to this conversation.'
                : 'Approval: ${detail!.latestApproval!.approvalRequestId}\nRun: ${detail.latestApproval!.runId}\nDecision: ${detail.latestApproval!.decision}\nApprover: ${blankAsUnknown(detail.latestApproval!.approverId)}\nCreated: ${formatDateTime(detail.latestApproval!.createdAt)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Latest run',
            body: detail?.latestRun == null
                ? 'No run is linked to this conversation yet.'
                : 'Run: ${detail!.latestRun!.runId}\nStatus: ${detail.latestRun!.status}\nInvocation: ${blankAsUnknown(detail.latestRun!.invocationMode)}\nCreated: ${formatDateTime(detail.latestRun!.createdAt)}\nSummary: ${blankAsUnknown(detail.latestRun!.resultSummary)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Route and install health',
            body:
                'Routes: ${detail?.routeHealth.routeCount ?? 0}\nInstallations: ${detail?.routeHealth.installationCount ?? 0}\nUnhealthy routes: ${detail?.routeHealth.unhealthyRouteCount ?? 0}\nInactive installations: ${detail?.routeHealth.inactiveInstallationCount ?? 0}',
          ),
          const SizedBox(height: 12),
          SubsectionTitle('Recent turns'),
          const SizedBox(height: 8),
          if (detail == null || detail.state.turns.isEmpty)
            const InfoPanel(
              title: 'Recent turns',
              body: 'No recent turns were recorded for this conversation.',
            )
          else
            ...detail.state.turns.reversed
                .take(6)
                .map(
                  (ConversationTurnItem turn) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InfoPanel(
                      title: '${turn.role} • ${formatDateTime(turn.createdAt)}',
                      body:
                          '${turn.content}\nActor: ${blankAsUnknown(turn.actorId)}\nRun: ${blankAsUnknown(turn.runId)}',
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
    return PanelCard(
      title: title,
      child: items.isEmpty
          ? const EmptyState(
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
                      child: InkWell(
                        onTap: onSelect == null
                            ? null
                            : () => onSelect!(item.id),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selectedId == item.id
                                ? panelRaisedColor
                                : panelAltColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedId == item.id
                                  ? accentColor
                                  : borderColor,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  color: textPrimaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.subtitle,
                                style: const TextStyle(color: textMutedColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.meta,
                                style: const TextStyle(color: textSubtleColor),
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
                                      .map(
                                        (String tag) => _InlineTag(label: tag),
                                      )
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
        color: panelRaisedColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: textMutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
