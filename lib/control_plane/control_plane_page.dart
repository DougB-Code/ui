import 'package:flutter/material.dart';
import 'package:ui/control_plane/control_plane_api.dart';
import 'package:ui/control_plane/control_plane_components.dart';
import 'package:ui/shared/ui.dart';

class ControlPlanePage extends StatefulWidget {
  const ControlPlanePage({super.key, required this.controlPlaneApi});

  final ControlPlaneApi controlPlaneApi;

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
        ControlPlaneOverviewMetrics(
          tenants: _tenants,
          users: _users,
          agents: _agents,
          installations: _installations,
          conversations: _conversations,
          routes: _routes,
        ),
        const SizedBox(height: 18),
        ControlPlaneTwoPanelRow(
          left: ControlPlaneEntityPanel(
            title: 'Tenants',
            selectedId: _selectedTenantId,
            onSelect: (String id) => setState(() => _selectedTenantId = id),
            items: _tenants
                .map(
                  (TenantRecord tenant) => ControlPlaneEntityItem(
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
          right: ControlPlaneTenantDetailCard(
            tenant: _selectedTenant,
            actorController: _tenantActorController,
            reasonController: _tenantReasonController,
            actionError: _tenantActionError,
            actionLoading: _tenantActionLoading,
            onDisable: _disableTenant,
          ),
        ),
        const SizedBox(height: 14),
        ControlPlaneTwoPanelRow(
          left: ControlPlaneEntityPanel(
            title: 'Control-plane agents',
            selectedId: _selectedAgentId,
            onSelect: (String id) => setState(() => _selectedAgentId = id),
            items: _agents
                .map(
                  (AgentRecord agent) => ControlPlaneEntityItem(
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
          right: ControlPlaneAgentDetailCard(
            agent: _selectedAgent,
            actorController: _agentActorController,
            reasonController: _agentReasonController,
            actionError: _agentActionError,
            actionLoading: _agentActionLoading,
            onDisable: _disableAgent,
          ),
        ),
        const SizedBox(height: 14),
        ControlPlaneTwoPanelRow(
          left: ControlPlaneEntityPanel(
            title: 'Installations',
            selectedId: _selectedInstallationId,
            onSelect: _selectInstallation,
            items: _installations
                .map(
                  (InstallationRecord installation) => ControlPlaneEntityItem(
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
          right: ControlPlaneInstallationDetailCard(
            loading: _installationDetailLoading,
            error: _installationDetailError,
            detail: _installationDetail,
            selectedInstallation: _selectedInstallation,
            actorController: _installationActorController,
            channelsController: _installationChannelsController,
            usersController: _installationUsersController,
            agentsController: _installationAgentsController,
            actionError: _installationActionError,
            actionLoading: _installationActionLoading,
            onSave: _saveInstallationAccess,
          ),
        ),
        const SizedBox(height: 14),
        ControlPlaneTwoPanelRow(
          left: ControlPlaneEntityPanel(
            title: 'Users',
            items: _users
                .map(
                  (UserRecord user) => ControlPlaneEntityItem(
                    id: user.userId,
                    title: user.displayName,
                    subtitle: '${user.userId} • ${user.status}',
                    meta: user.kind,
                  ),
                )
                .toList(),
          ),
          right: ControlPlaneEntityPanel(
            title: 'Memberships',
            items: _memberships
                .map(
                  (MembershipRecord membership) => ControlPlaneEntityItem(
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
        ControlPlaneTwoPanelRow(
          left: ControlPlaneEntityPanel(
            title: 'Conversations',
            selectedId: _selectedConversationId,
            onSelect: _selectConversation,
            items: _conversations
                .map(
                  (ConversationRecord conversation) => ControlPlaneEntityItem(
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
          right: ControlPlaneConversationDetailCard(
            loading: _conversationDetailLoading,
            detailError: _conversationDetailError,
            detail: _conversationDetail,
            selectedConversation: _selectedConversation,
          ),
        ),
        const SizedBox(height: 14),
        ControlPlaneRoutesPanel(routes: _routes, onRefresh: _load),
      ],
    );
  }
}
