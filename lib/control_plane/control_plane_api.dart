import 'package:http/http.dart' as http;
import 'package:ui/operations/operations_api.dart';
import 'package:ui/shared/admin_http_client.dart';

class UserRecord {
  UserRecord({
    required this.userId,
    required this.displayName,
    required this.kind,
    required this.status,
  });

  factory UserRecord.fromJson(Map<String, dynamic> json) {
    return UserRecord(
      userId: (json['user_id'] as String? ?? '').trim(),
      displayName: (json['display_name'] as String? ?? '').trim(),
      kind: (json['kind'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
    );
  }

  final String userId;
  final String displayName;
  final String kind;
  final String status;
}

class TenantRecord {
  TenantRecord({
    required this.tenantId,
    required this.displayName,
    required this.type,
    required this.ownerUserId,
    required this.status,
    required this.region,
    required this.defaultAgentTemplate,
    required this.enabledIntegrations,
    required this.onboardingState,
    required this.runHistoryDays,
    required this.artifactDays,
    required this.auditLogDays,
    required this.maxRunsPerDay,
    required this.defaultApprovalMode,
    required this.maxRunSeconds,
    required this.maxTurns,
    required this.createdAt,
  });

  factory TenantRecord.fromJson(Map<String, dynamic> json) {
    return TenantRecord(
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      displayName: (json['display_name'] as String? ?? '').trim(),
      type: (json['type'] as String? ?? '').trim(),
      ownerUserId: (json['owner_user_id'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      region: (json['region'] as String? ?? '').trim(),
      defaultAgentTemplate: (json['default_agent_template'] as String? ?? '')
          .trim(),
      enabledIntegrations:
          (json['enabled_integrations'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      onboardingState: (json['onboarding_state'] as String? ?? '').trim(),
      runHistoryDays:
          ((json['retention_policy'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['run_history_days']
              as int? ??
          0,
      artifactDays:
          ((json['retention_policy'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['artifact_days']
              as int? ??
          0,
      auditLogDays:
          ((json['retention_policy'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['audit_log_days']
              as int? ??
          0,
      maxRunsPerDay:
          ((json['budget_policy'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['max_runs_per_day']
              as int? ??
          0,
      defaultApprovalMode:
          ((json['default_approval_policy'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['mode']
              as String? ??
          '',
      maxRunSeconds:
          ((json['runtime_limits'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['max_run_seconds']
              as int? ??
          0,
      maxTurns:
          ((json['runtime_limits'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['max_turns']
              as int? ??
          0,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String tenantId;
  final String displayName;
  final String type;
  final String ownerUserId;
  final String status;
  final String region;
  final String defaultAgentTemplate;
  final List<String> enabledIntegrations;
  final String onboardingState;
  final int runHistoryDays;
  final int artifactDays;
  final int auditLogDays;
  final int maxRunsPerDay;
  final String defaultApprovalMode;
  final int maxRunSeconds;
  final int maxTurns;
  final DateTime? createdAt;
}

class MembershipRecord {
  MembershipRecord({
    required this.tenantId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });

  factory MembershipRecord.fromJson(Map<String, dynamic> json) {
    return MembershipRecord(
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      userId: (json['user_id'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String tenantId;
  final String userId;
  final String role;
  final DateTime? createdAt;
}

class AgentRecord {
  AgentRecord({
    required this.agentId,
    required this.tenantId,
    required this.name,
    required this.status,
    required this.templateId,
    required this.enabledCapabilities,
    required this.deniedCapabilities,
    required this.integrationBindings,
    required this.onboardingState,
    required this.approvalOverrideMode,
    required this.runtimeOverrideMaxRunSeconds,
    required this.runtimeOverrideMaxTurns,
  });

  factory AgentRecord.fromJson(Map<String, dynamic> json) {
    return AgentRecord(
      agentId: (json['agent_id'] as String? ?? '').trim(),
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      templateId: (json['template_id'] as String? ?? '').trim(),
      enabledCapabilities:
          (json['enabled_capabilities'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      deniedCapabilities:
          (json['denied_capabilities'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      integrationBindings:
          (json['integration_bindings'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      onboardingState: (json['onboarding_state'] as String? ?? '').trim(),
      approvalOverrideMode:
          ((json['approval_override'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['mode']
              as String? ??
          '',
      runtimeOverrideMaxRunSeconds:
          ((json['runtime_limits_override'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['max_run_seconds']
              as int? ??
          0,
      runtimeOverrideMaxTurns:
          ((json['runtime_limits_override'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})['max_turns']
              as int? ??
          0,
    );
  }

  final String agentId;
  final String tenantId;
  final String name;
  final String status;
  final String templateId;
  final List<String> enabledCapabilities;
  final List<String> deniedCapabilities;
  final List<String> integrationBindings;
  final String onboardingState;
  final String approvalOverrideMode;
  final int runtimeOverrideMaxRunSeconds;
  final int runtimeOverrideMaxTurns;
}

class InstallationRecord {
  InstallationRecord({
    required this.installationId,
    required this.providerType,
    required this.externalWorkspaceId,
    required this.mappedTenantId,
    required this.mappedDefaultAgentId,
    required this.status,
    required this.installedBy,
    required this.installedAt,
    required this.lastVerifiedAt,
    required this.allowedChannelIds,
    required this.allowedExternalUserIds,
    required this.allowedAgentIds,
    required this.adapterVersion,
  });

  factory InstallationRecord.fromJson(Map<String, dynamic> json) {
    return InstallationRecord(
      installationId: (json['installation_id'] as String? ?? '').trim(),
      providerType: (json['provider_type'] as String? ?? '').trim(),
      externalWorkspaceId: (json['external_workspace_id'] as String? ?? '')
          .trim(),
      mappedTenantId: (json['mapped_tenant_id'] as String? ?? '').trim(),
      mappedDefaultAgentId: (json['mapped_default_agent_id'] as String? ?? '')
          .trim(),
      status: (json['status'] as String? ?? '').trim(),
      installedBy: (json['installed_by'] as String? ?? '').trim(),
      installedAt: _parseDateTime(json['installed_at']),
      lastVerifiedAt: _parseDateTime(json['last_verified_at']),
      allowedChannelIds:
          (json['allowed_channel_ids'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      allowedExternalUserIds:
          (json['allowed_external_user_ids'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      allowedAgentIds:
          (json['allowed_agent_ids'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      adapterVersion: json['adapter_version'] as int? ?? 0,
    );
  }

  final String installationId;
  final String providerType;
  final String externalWorkspaceId;
  final String mappedTenantId;
  final String mappedDefaultAgentId;
  final String status;
  final String installedBy;
  final DateTime? installedAt;
  final DateTime? lastVerifiedAt;
  final List<String> allowedChannelIds;
  final List<String> allowedExternalUserIds;
  final List<String> allowedAgentIds;
  final int adapterVersion;
}

class ConversationRecord {
  ConversationRecord({
    required this.conversationId,
    required this.tenantId,
    required this.agentId,
    required this.name,
    required this.kind,
    required this.status,
    required this.createdBy,
    required this.createdAt,
  });

  factory ConversationRecord.fromJson(Map<String, dynamic> json) {
    return ConversationRecord(
      conversationId: (json['conversation_id'] as String? ?? '').trim(),
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      kind: (json['kind'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      createdBy: (json['created_by'] as String? ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String conversationId;
  final String tenantId;
  final String agentId;
  final String name;
  final String kind;
  final String status;
  final String createdBy;
  final DateTime? createdAt;
}

class ChannelRouteRecord {
  ChannelRouteRecord({
    required this.routeId,
    required this.tenantId,
    required this.conversationId,
    required this.agentId,
    required this.providerType,
    required this.installationId,
    required this.externalWorkspaceId,
    required this.channelId,
    required this.threadId,
    required this.status,
    required this.createdAt,
  });

  factory ChannelRouteRecord.fromJson(Map<String, dynamic> json) {
    return ChannelRouteRecord(
      routeId: (json['route_id'] as String? ?? '').trim(),
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      conversationId: (json['conversation_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      providerType: (json['provider_type'] as String? ?? '').trim(),
      installationId: (json['installation_id'] as String? ?? '').trim(),
      externalWorkspaceId: (json['external_workspace_id'] as String? ?? '')
          .trim(),
      channelId: (json['channel_id'] as String? ?? '').trim(),
      threadId: (json['thread_id'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String routeId;
  final String tenantId;
  final String conversationId;
  final String agentId;
  final String providerType;
  final String installationId;
  final String externalWorkspaceId;
  final String channelId;
  final String threadId;
  final String status;
  final DateTime? createdAt;
}

class ConversationTurnItem {
  ConversationTurnItem({
    required this.turnId,
    required this.role,
    required this.content,
    required this.actorId,
    required this.requestId,
    required this.runId,
    required this.createdAt,
  });

  factory ConversationTurnItem.fromJson(Map<String, dynamic> json) {
    return ConversationTurnItem(
      turnId: (json['turn_id'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? '').trim(),
      content: (json['content'] as String? ?? '').trim(),
      actorId: (json['actor_id'] as String? ?? '').trim(),
      requestId: (json['request_id'] as String? ?? '').trim(),
      runId: (json['run_id'] as String? ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String turnId;
  final String role;
  final String content;
  final String actorId;
  final String requestId;
  final String runId;
  final DateTime? createdAt;
}

class PendingConversationExecutionRecord {
  PendingConversationExecutionRecord({
    required this.runId,
    required this.status,
    required this.waitReason,
    required this.pendingQuestion,
    required this.approvalRequestId,
    required this.resumeSessionId,
    required this.checkpointReference,
    required this.updatedAt,
  });

  factory PendingConversationExecutionRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return PendingConversationExecutionRecord(
      runId: (json['run_id'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      waitReason: (json['wait_reason'] as String? ?? '').trim(),
      pendingQuestion: (json['pending_question'] as String? ?? '').trim(),
      approvalRequestId: (json['approval_request_id'] as String? ?? '').trim(),
      resumeSessionId: (json['resume_session_id'] as String? ?? '').trim(),
      checkpointReference: (json['checkpoint_reference'] as String? ?? '')
          .trim(),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  final String runId;
  final String status;
  final String waitReason;
  final String pendingQuestion;
  final String approvalRequestId;
  final String resumeSessionId;
  final String checkpointReference;
  final DateTime? updatedAt;
}

class ConversationStateRecord {
  ConversationStateRecord({
    required this.conversationKey,
    required this.tenantId,
    required this.conversationId,
    required this.agentId,
    required this.providerType,
    required this.installationId,
    required this.externalWorkspaceId,
    required this.channelId,
    required this.threadId,
    required this.historySummary,
    required this.turns,
    required this.pending,
    required this.latestRunId,
    required this.latestApprovalRequestId,
    required this.updatedAt,
  });

  factory ConversationStateRecord.fromJson(Map<String, dynamic> json) {
    return ConversationStateRecord(
      conversationKey: (json['conversation_key'] as String? ?? '').trim(),
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      conversationId: (json['conversation_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      providerType: (json['provider_type'] as String? ?? '').trim(),
      installationId: (json['installation_id'] as String? ?? '').trim(),
      externalWorkspaceId: (json['external_workspace_id'] as String? ?? '')
          .trim(),
      channelId: (json['channel_id'] as String? ?? '').trim(),
      threadId: (json['thread_id'] as String? ?? '').trim(),
      historySummary: (json['history_summary'] as String? ?? '').trim(),
      turns: (json['turns'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ConversationTurnItem.fromJson)
          .toList(),
      pending: (json['pending'] as Map<String, dynamic>?) == null
          ? null
          : PendingConversationExecutionRecord.fromJson(
              json['pending'] as Map<String, dynamic>,
            ),
      latestRunId: (json['latest_run_id'] as String? ?? '').trim(),
      latestApprovalRequestId:
          (json['latest_approval_request_id'] as String? ?? '').trim(),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  final String conversationKey;
  final String tenantId;
  final String conversationId;
  final String agentId;
  final String providerType;
  final String installationId;
  final String externalWorkspaceId;
  final String channelId;
  final String threadId;
  final String historySummary;
  final List<ConversationTurnItem> turns;
  final PendingConversationExecutionRecord? pending;
  final String latestRunId;
  final String latestApprovalRequestId;
  final DateTime? updatedAt;
}

class ConversationRouteHealthRecord {
  ConversationRouteHealthRecord({
    required this.routeCount,
    required this.unhealthyRouteCount,
    required this.installationCount,
    required this.inactiveInstallationCount,
  });

  factory ConversationRouteHealthRecord.fromJson(Map<String, dynamic> json) {
    return ConversationRouteHealthRecord(
      routeCount: json['route_count'] as int? ?? 0,
      unhealthyRouteCount: json['unhealthy_route_count'] as int? ?? 0,
      installationCount: json['installation_count'] as int? ?? 0,
      inactiveInstallationCount:
          json['inactive_installation_count'] as int? ?? 0,
    );
  }

  final int routeCount;
  final int unhealthyRouteCount;
  final int installationCount;
  final int inactiveInstallationCount;
}

class ConversationDetailRecord {
  ConversationDetailRecord({
    required this.conversation,
    required this.state,
    required this.latestRun,
    required this.latestApproval,
    required this.routeHealth,
  });

  factory ConversationDetailRecord.fromJson(Map<String, dynamic> json) {
    return ConversationDetailRecord(
      conversation: ConversationRecord.fromJson(
        (json['conversation'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      state: ConversationStateRecord.fromJson(
        (json['state'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      latestRun: (json['latest_run'] as Map<String, dynamic>?) == null
          ? null
          : RunRecord.fromJson(json['latest_run'] as Map<String, dynamic>),
      latestApproval: (json['latest_approval'] as Map<String, dynamic>?) == null
          ? null
          : ApprovalRecord.fromJson(
              json['latest_approval'] as Map<String, dynamic>,
            ),
      routeHealth: ConversationRouteHealthRecord.fromJson(
        (json['route_health'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  final ConversationRecord conversation;
  final ConversationStateRecord state;
  final RunRecord? latestRun;
  final ApprovalRecord? latestApproval;
  final ConversationRouteHealthRecord routeHealth;
}

class InstallationRouteHealthRecord {
  InstallationRouteHealthRecord({
    required this.linkedRouteCount,
    required this.unhealthyRouteCount,
    required this.mappedAgentOnboarding,
  });

  factory InstallationRouteHealthRecord.fromJson(Map<String, dynamic> json) {
    return InstallationRouteHealthRecord(
      linkedRouteCount: json['linked_route_count'] as int? ?? 0,
      unhealthyRouteCount: json['unhealthy_route_count'] as int? ?? 0,
      mappedAgentOnboarding: (json['mapped_agent_onboarding'] as String? ?? '')
          .trim(),
    );
  }

  final int linkedRouteCount;
  final int unhealthyRouteCount;
  final String mappedAgentOnboarding;
}

class InstallationDetailRecord {
  InstallationDetailRecord({
    required this.installation,
    required this.mappedAgent,
    required this.routeHealth,
  });

  factory InstallationDetailRecord.fromJson(Map<String, dynamic> json) {
    return InstallationDetailRecord(
      installation: InstallationRecord.fromJson(
        (json['installation'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      mappedAgent: (json['mapped_agent'] as Map<String, dynamic>?) == null
          ? null
          : AgentRecord.fromJson(json['mapped_agent'] as Map<String, dynamic>),
      routeHealth: InstallationRouteHealthRecord.fromJson(
        (json['route_health'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  final InstallationRecord installation;
  final AgentRecord? mappedAgent;
  final InstallationRouteHealthRecord routeHealth;
}

abstract class ControlPlaneApi {
  Future<List<UserRecord>> listUsers();

  Future<List<TenantRecord>> listTenants();

  Future<List<MembershipRecord>> listMemberships({
    String? tenantId,
    String? userId,
  });

  Future<List<AgentRecord>> listAgents({String? tenantId});

  Future<List<InstallationRecord>> listInstallations({String? tenantId});

  Future<List<ConversationRecord>> listConversations({
    String? tenantId,
    String? agentId,
  });

  Future<List<ChannelRouteRecord>> listChannelRoutes({
    String? tenantId,
    String? agentId,
    String? installationId,
  });

  Future<ConversationStateRecord> getConversationState(String conversationId);

  Future<ConversationDetailRecord> getConversationDetail(String conversationId);

  Future<InstallationDetailRecord> getInstallationDetail(String installationId);

  Future<TenantRecord> disableTenant({
    required String tenantId,
    required String actorId,
    String reason = '',
  });

  Future<AgentRecord> disableAgent({
    required String agentId,
    required String actorId,
    String reason = '',
  });

  Future<InstallationRecord> updateInstallationAccess({
    required String installationId,
    required String actorId,
    required List<String> allowedChannelIds,
    required List<String> allowedExternalUserIds,
    required List<String> allowedAgentIds,
  });
}

class HttpControlPlaneApi implements ControlPlaneApi {
  HttpControlPlaneApi({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _http = AdminHttpClient(
         baseUrl: baseUrl,
         adminToken: adminToken,
         client: client,
       );

  factory HttpControlPlaneApi.fromEnvironment() {
    return HttpControlPlaneApi(
      baseUrl: const String.fromEnvironment(
        'CONTROL_PLANE_BASE_URL',
        defaultValue: 'http://127.0.0.1:8080',
      ),
      adminToken: const String.fromEnvironment('CONTROL_PLANE_ADMIN_TOKEN'),
    );
  }

  final String baseUrl;
  final String adminToken;
  final AdminHttpClient _http;

  @override
  Future<ConversationStateRecord> getConversationState(
    String conversationId,
  ) async {
    final response = await _http.get(
      '/v1/admin/conversations/${Uri.encodeComponent(conversationId)}/state',
    );
    final payload = await _http.decodeJsonMap(
      response,
      ControlPlaneApiException.new,
    );
    return ConversationStateRecord.fromJson(payload);
  }

  @override
  Future<ConversationDetailRecord> getConversationDetail(
    String conversationId,
  ) async {
    final response = await _http.get(
      '/v1/admin/conversations/${Uri.encodeComponent(conversationId)}/detail',
    );
    final payload = await _http.decodeJsonMap(
      response,
      ControlPlaneApiException.new,
    );
    return ConversationDetailRecord.fromJson(payload);
  }

  @override
  Future<InstallationDetailRecord> getInstallationDetail(
    String installationId,
  ) async {
    final response = await _http.get(
      '/v1/admin/installations/${Uri.encodeComponent(installationId)}/detail',
    );
    final payload = await _http.decodeJsonMap(
      response,
      ControlPlaneApiException.new,
    );
    return InstallationDetailRecord.fromJson(payload);
  }

  @override
  Future<TenantRecord> disableTenant({
    required String tenantId,
    required String actorId,
    String reason = '',
  }) async {
    final response = await _http.post(
      '/v1/admin/tenants/${Uri.encodeComponent(tenantId)}/disable',
      body: <String, String>{
        'actor_id': actorId.trim(),
        'reason': reason.trim(),
      },
    );
    final payload = await _http.decodeJsonMap(
      response,
      ControlPlaneApiException.new,
    );
    return TenantRecord.fromJson(payload);
  }

  @override
  Future<AgentRecord> disableAgent({
    required String agentId,
    required String actorId,
    String reason = '',
  }) async {
    final response = await _http.post(
      '/v1/admin/agents/${Uri.encodeComponent(agentId)}/disable',
      body: <String, String>{
        'actor_id': actorId.trim(),
        'reason': reason.trim(),
      },
    );
    final payload = await _http.decodeJsonMap(
      response,
      ControlPlaneApiException.new,
    );
    return AgentRecord.fromJson(payload);
  }

  @override
  Future<InstallationRecord> updateInstallationAccess({
    required String installationId,
    required String actorId,
    required List<String> allowedChannelIds,
    required List<String> allowedExternalUserIds,
    required List<String> allowedAgentIds,
  }) async {
    final response = await _http.post(
      '/v1/admin/installations/${Uri.encodeComponent(installationId)}/access',
      body: <String, dynamic>{
        'actor_id': actorId.trim(),
        'allowed_channel_ids': allowedChannelIds,
        'allowed_external_user_ids': allowedExternalUserIds,
        'allowed_agent_ids': allowedAgentIds,
      },
    );
    final payload = await _http.decodeJsonMap(
      response,
      ControlPlaneApiException.new,
    );
    return InstallationRecord.fromJson(payload);
  }

  @override
  Future<List<AgentRecord>> listAgents({String? tenantId}) async {
    final response = await _http.get(
      '/v1/admin/agents',
      query: _query(<String, String?>{'tenant_id': tenantId}),
    );
    final payload = await _http.decodeJsonList(
      response,
      ControlPlaneApiException.new,
    );
    return payload.map(AgentRecord.fromJson).toList();
  }

  @override
  Future<List<ChannelRouteRecord>> listChannelRoutes({
    String? tenantId,
    String? agentId,
    String? installationId,
  }) async {
    final response = await _http.get(
      '/v1/admin/channel-routes',
      query: _query(<String, String?>{
        'tenant_id': tenantId,
        'agent_id': agentId,
        'installation_id': installationId,
      }),
    );
    final payload = await _http.decodeJsonList(
      response,
      ControlPlaneApiException.new,
    );
    return payload.map(ChannelRouteRecord.fromJson).toList();
  }

  @override
  Future<List<ConversationRecord>> listConversations({
    String? tenantId,
    String? agentId,
  }) async {
    final response = await _http.get(
      '/v1/admin/conversations',
      query: _query(<String, String?>{
        'tenant_id': tenantId,
        'agent_id': agentId,
      }),
    );
    final payload = await _http.decodeJsonList(
      response,
      ControlPlaneApiException.new,
    );
    return payload.map(ConversationRecord.fromJson).toList();
  }

  @override
  Future<List<InstallationRecord>> listInstallations({String? tenantId}) async {
    final response = await _http.get(
      '/v1/admin/installations',
      query: _query(<String, String?>{'tenant_id': tenantId}),
    );
    final payload = await _http.decodeJsonList(
      response,
      ControlPlaneApiException.new,
    );
    return payload.map(InstallationRecord.fromJson).toList();
  }

  @override
  Future<List<MembershipRecord>> listMemberships({
    String? tenantId,
    String? userId,
  }) async {
    final response = await _http.get(
      '/v1/admin/memberships',
      query: _query(<String, String?>{
        'tenant_id': tenantId,
        'user_id': userId,
      }),
    );
    final payload = await _http.decodeJsonList(
      response,
      ControlPlaneApiException.new,
    );
    return payload.map(MembershipRecord.fromJson).toList();
  }

  @override
  Future<List<TenantRecord>> listTenants() async {
    final response = await _http.get('/v1/admin/tenants');
    final payload = await _http.decodeJsonList(
      response,
      ControlPlaneApiException.new,
    );
    return payload.map(TenantRecord.fromJson).toList();
  }

  @override
  Future<List<UserRecord>> listUsers() async {
    final response = await _http.get('/v1/admin/users');
    final payload = await _http.decodeJsonList(
      response,
      ControlPlaneApiException.new,
    );
    return payload.map(UserRecord.fromJson).toList();
  }

  Map<String, String> _query(Map<String, String?> input) {
    final query = <String, String>{};
    input.forEach((String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        query[key] = value.trim();
      }
    });
    return query;
  }
}

class ControlPlaneApiException implements Exception {
  ControlPlaneApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.trim())?.toLocal();
}
