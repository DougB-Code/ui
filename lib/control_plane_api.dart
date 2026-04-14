import 'dart:convert';

import 'package:http/http.dart' as http;

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
    required this.allowedChannelIds,
    required this.allowedExternalUserIds,
    required this.allowedAgentIds,
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
  final List<String> allowedChannelIds;
  final List<String> allowedExternalUserIds;
  final List<String> allowedAgentIds;
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
}

class HttpControlPlaneApi implements ControlPlaneApi {
  HttpControlPlaneApi({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

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
  final http.Client _client;

  @override
  Future<List<AgentRecord>> listAgents({String? tenantId}) async {
    final response = await _client.get(
      _uri(
        '/v1/admin/agents',
        _query(<String, String?>{'tenant_id': tenantId}),
      ),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(AgentRecord.fromJson).toList();
  }

  @override
  Future<List<ChannelRouteRecord>> listChannelRoutes({
    String? tenantId,
    String? agentId,
    String? installationId,
  }) async {
    final response = await _client.get(
      _uri(
        '/v1/admin/channel-routes',
        _query(<String, String?>{
          'tenant_id': tenantId,
          'agent_id': agentId,
          'installation_id': installationId,
        }),
      ),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(ChannelRouteRecord.fromJson).toList();
  }

  @override
  Future<List<ConversationRecord>> listConversations({
    String? tenantId,
    String? agentId,
  }) async {
    final response = await _client.get(
      _uri(
        '/v1/admin/conversations',
        _query(<String, String?>{'tenant_id': tenantId, 'agent_id': agentId}),
      ),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(ConversationRecord.fromJson).toList();
  }

  @override
  Future<List<InstallationRecord>> listInstallations({String? tenantId}) async {
    final response = await _client.get(
      _uri(
        '/v1/admin/installations',
        _query(<String, String?>{'tenant_id': tenantId}),
      ),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(InstallationRecord.fromJson).toList();
  }

  @override
  Future<List<MembershipRecord>> listMemberships({
    String? tenantId,
    String? userId,
  }) async {
    final response = await _client.get(
      _uri(
        '/v1/admin/memberships',
        _query(<String, String?>{'tenant_id': tenantId, 'user_id': userId}),
      ),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(MembershipRecord.fromJson).toList();
  }

  @override
  Future<List<TenantRecord>> listTenants() async {
    final response = await _client.get(
      _uri('/v1/admin/tenants'),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(TenantRecord.fromJson).toList();
  }

  @override
  Future<List<UserRecord>> listUsers() async {
    final response = await _client.get(
      _uri('/v1/admin/users'),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(UserRecord.fromJson).toList();
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Accept': 'application/json'};
    if (adminToken.trim().isNotEmpty) {
      headers['X-Admin-Token'] = adminToken.trim();
    }
    return headers;
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

  Future<List<Map<String, dynamic>>> _decodeJsonList(
    http.Response response,
  ) async {
    final bodyText = utf8.decode(response.bodyBytes);
    final payload = bodyText.trim().isEmpty
        ? <dynamic>[]
        : (jsonDecode(bodyText) as List<dynamic>);
    if (response.statusCode >= 400) {
      throw ControlPlaneApiException(
        payload.isNotEmpty && payload.first is Map<String, dynamic>
            ? ((payload.first as Map<String, dynamic>)['error'] as String? ??
                  'Request failed with status ${response.statusCode}.')
            : 'Request failed with status ${response.statusCode}.',
      );
    }
    return payload.whereType<Map<String, dynamic>>().toList();
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
