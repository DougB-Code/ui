import 'dart:convert';

import 'package:http/http.dart' as http;

class ProviderModelConfig {
  ProviderModelConfig({
    required this.name,
    required this.enabled,
    required this.accessVerified,
  });

  ProviderModelConfig copy() {
    return ProviderModelConfig(
      name: name,
      enabled: enabled,
      accessVerified: accessVerified,
    );
  }

  factory ProviderModelConfig.fromJson(Map<String, dynamic> json) {
    return ProviderModelConfig(
      name: (json['name'] as String? ?? '').trim(),
      enabled: json['enabled'] as bool? ?? false,
      accessVerified: json['access_verified'] as bool? ?? false,
    );
  }

  String name;
  bool enabled;
  bool accessVerified;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'enabled': enabled,
    'access_verified': accessVerified,
  };
}

class ProviderConfig {
  ProviderConfig({
    required this.alias,
    String? persistedAlias,
    required this.adapter,
    required this.enabled,
    required this.isDefault,
    required this.endpoint,
    required this.apiKeyEnv,
    required this.accountId,
    required this.gatewayId,
    required this.apiVersion,
    required this.timeoutSecs,
    required this.accessVerified,
    required this.allowedHosts,
    required this.local,
    required this.models,
    required this.verificationSummary,
  }) : persistedAlias = persistedAlias ?? alias;

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    final modelsJson = (json['models'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ProviderModelConfig.fromJson)
        .toList();
    return ProviderConfig(
      alias: (json['alias'] as String? ?? '').trim(),
      adapter: (json['adapter'] as String? ?? '').trim(),
      enabled: json['enabled'] as bool? ?? false,
      isDefault: json['is_default'] as bool? ?? false,
      endpoint: (json['base_url'] as String? ?? '').trim(),
      apiKeyEnv: (json['api_key_env'] as String? ?? '').trim(),
      accountId: (json['account_id'] as String? ?? '').trim(),
      gatewayId: (json['gateway_id'] as String? ?? '').trim(),
      apiVersion: (json['api_version'] as String? ?? '').trim(),
      timeoutSecs: json['timeout_secs'] as int? ?? 0,
      accessVerified: json['access_verified'] as bool? ?? false,
      allowedHosts:
          (json['allowed_hosts'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      local: json['local'] as bool? ?? false,
      models: modelsJson,
      verificationSummary: 'Not yet verified.',
    );
  }

  factory ProviderConfig.empty() {
    return ProviderConfig(
      alias: '',
      persistedAlias: '',
      adapter: '',
      enabled: false,
      isDefault: false,
      endpoint: '',
      apiKeyEnv: '',
      accountId: '',
      gatewayId: '',
      apiVersion: '',
      timeoutSecs: 0,
      accessVerified: false,
      allowedHosts: <String>[],
      local: false,
      models: <ProviderModelConfig>[],
      verificationSummary: 'Not yet verified.',
    );
  }

  String alias;
  String persistedAlias;
  String adapter;
  bool enabled;
  bool isDefault;
  String endpoint;
  String apiKeyEnv;
  String accountId;
  String gatewayId;
  String apiVersion;
  int timeoutSecs;
  bool accessVerified;
  List<String> allowedHosts;
  bool local;
  List<ProviderModelConfig> models;
  String verificationSummary;

  ProviderConfig copy() {
    return ProviderConfig(
      alias: alias,
      persistedAlias: persistedAlias,
      adapter: adapter,
      enabled: enabled,
      isDefault: isDefault,
      endpoint: endpoint,
      apiKeyEnv: apiKeyEnv,
      accountId: accountId,
      gatewayId: gatewayId,
      apiVersion: apiVersion,
      timeoutSecs: timeoutSecs,
      accessVerified: accessVerified,
      allowedHosts: List<String>.from(allowedHosts),
      local: local,
      models: models.map((ProviderModelConfig model) => model.copy()).toList(),
      verificationSummary: verificationSummary,
    );
  }

  Map<String, dynamic> toUpsertJson() => <String, dynamic>{
    'alias': alias.trim(),
    'adapter': adapter.trim(),
    'enabled': enabled,
    'is_default': isDefault,
    'base_url': endpoint.trim(),
    'api_key_env': apiKeyEnv.trim(),
    'account_id': accountId.trim(),
    'gateway_id': gatewayId.trim(),
    'api_version': apiVersion.trim(),
    'timeout_secs': timeoutSecs,
    'access_verified': accessVerified,
    'allowed_hosts': allowedHosts
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(),
    'local': local,
    'models': models
        .map((ProviderModelConfig model) => model.toJson())
        .toList(),
  };

  String toYamlSnippet() {
    final buffer = StringBuffer()..writeln('provider:');
    if (isDefault) {
      buffer.writeln("  default: '${alias.trim()}'");
    }
    buffer
      ..writeln('  providers:')
      ..writeln('    $alias:')
      ..writeln("      adapter: '${adapter.trim()}'")
      ..writeln('      enabled: $enabled');
    if (endpoint.trim().isNotEmpty) {
      buffer.writeln("      base_url: '${endpoint.trim()}'");
    }
    if (apiKeyEnv.trim().isNotEmpty) {
      buffer.writeln("      api-key: '${apiKeyEnv.trim()}'");
    }
    buffer.writeln('      access_verified: $accessVerified');
    if (accountId.trim().isNotEmpty) {
      buffer.writeln("      account_id: '${accountId.trim()}'");
    }
    if (gatewayId.trim().isNotEmpty) {
      buffer.writeln("      gateway_id: '${gatewayId.trim()}'");
    }
    if (apiVersion.trim().isNotEmpty) {
      buffer.writeln("      api_version: '${apiVersion.trim()}'");
    }
    if (timeoutSecs > 0) {
      buffer.writeln('      timeout_secs: $timeoutSecs');
    }
    if (local) {
      buffer.writeln('      local: true');
    }
    if (allowedHosts.isNotEmpty) {
      buffer.writeln('      allowed_hosts:');
      for (final host in allowedHosts) {
        buffer.writeln("        - '${host.trim()}'");
      }
    }
    buffer.writeln('      models:');
    for (final model in models) {
      buffer.writeln("        - name: '${model.name.trim()}'");
      buffer.writeln('          enabled: ${model.enabled}');
      buffer.writeln('          access_verified: ${model.accessVerified}');
    }
    return buffer.toString().trimRight();
  }
}

class ProviderCatalog {
  ProviderCatalog({
    required this.defaultProvider,
    required this.configPath,
    required this.providers,
  });

  factory ProviderCatalog.fromJson(Map<String, dynamic> json) {
    final providersJson =
        (json['providers'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(ProviderConfig.fromJson)
            .toList();
    return ProviderCatalog(
      defaultProvider: (json['default_provider'] as String? ?? '').trim(),
      configPath: (json['config_path'] as String? ?? '').trim(),
      providers: providersJson,
    );
  }

  String defaultProvider;
  String configPath;
  List<ProviderConfig> providers;
}

class ProviderMutationResult {
  ProviderMutationResult({required this.catalog, required this.provider});

  factory ProviderMutationResult.fromJson(Map<String, dynamic> json) {
    return ProviderMutationResult(
      catalog: ProviderCatalog.fromJson(
        (json['catalog'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      provider: ProviderConfig.fromJson(
        (json['provider'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  ProviderCatalog catalog;
  ProviderConfig provider;
}

class ProviderVerificationReport {
  ProviderVerificationReport({
    required this.alias,
    required this.status,
    required this.summary,
    required this.probedProviderCount,
    required this.probedModelCount,
    required this.validatedModels,
    required this.failedModels,
    required this.probeErrors,
  });

  factory ProviderVerificationReport.fromJson(Map<String, dynamic> json) {
    return ProviderVerificationReport(
      alias: (json['alias'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'error').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      probedProviderCount: json['probed_provider_count'] as int? ?? 0,
      probedModelCount: json['probed_model_count'] as int? ?? 0,
      validatedModels:
          (json['validated_models'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      failedModels:
          (json['failed_models'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      probeErrors:
          ((json['probe_errors'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, String>(key, value.toString()),
              ),
    );
  }

  String alias;
  String status;
  String summary;
  int probedProviderCount;
  int probedModelCount;
  List<String> validatedModels;
  List<String> failedModels;
  Map<String, String> probeErrors;
}

abstract class ProviderCatalogApi {
  Future<ProviderCatalog> listProviders();

  Future<ProviderMutationResult> createProvider(ProviderConfig provider);

  Future<ProviderMutationResult> updateProvider(
    String currentAlias,
    ProviderConfig provider,
  );

  Future<ProviderCatalog> deleteProvider(String alias);

  Future<ProviderVerificationReport> verifyProvider(String alias);
}

class HttpProviderCatalogApi implements ProviderCatalogApi {
  HttpProviderCatalogApi({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory HttpProviderCatalogApi.fromEnvironment() {
    return HttpProviderCatalogApi(
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
  Future<ProviderMutationResult> createProvider(ProviderConfig provider) async {
    final response = await _client.post(
      _uri('/v1/admin/harness/providers'),
      headers: _headers(),
      body: jsonEncode(provider.toUpsertJson()),
    );
    final payload = await _decodeJson(response);
    return ProviderMutationResult.fromJson(payload);
  }

  @override
  Future<ProviderCatalog> deleteProvider(String alias) async {
    final response = await _client.delete(
      _uri('/v1/admin/harness/providers/${Uri.encodeComponent(alias)}'),
      headers: _headers(),
    );
    final payload = await _decodeJson(response);
    return ProviderCatalog.fromJson(payload);
  }

  @override
  Future<ProviderCatalog> listProviders() async {
    final response = await _client.get(
      _uri('/v1/admin/harness/providers'),
      headers: _headers(),
    );
    final payload = await _decodeJson(response);
    return ProviderCatalog.fromJson(payload);
  }

  @override
  Future<ProviderMutationResult> updateProvider(
    String currentAlias,
    ProviderConfig provider,
  ) async {
    final response = await _client.put(
      _uri('/v1/admin/harness/providers/${Uri.encodeComponent(currentAlias)}'),
      headers: _headers(),
      body: jsonEncode(provider.toUpsertJson()),
    );
    final payload = await _decodeJson(response);
    return ProviderMutationResult.fromJson(payload);
  }

  @override
  Future<ProviderVerificationReport> verifyProvider(String alias) async {
    final response = await _client.post(
      _uri('/v1/admin/harness/providers/${Uri.encodeComponent(alias)}/verify'),
      headers: _headers(),
    );
    final payload = await _decodeJson(response);
    return ProviderVerificationReport.fromJson(payload);
  }

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path');
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (adminToken.trim().isNotEmpty) {
      headers['X-Admin-Token'] = adminToken.trim();
    }
    return headers;
  }

  Future<Map<String, dynamic>> _decodeJson(http.Response response) async {
    final bodyText = utf8.decode(response.bodyBytes);
    final payload = bodyText.trim().isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(bodyText) as Map<String, dynamic>);
    if (response.statusCode >= 400) {
      throw ProviderCatalogException(
        payload['error'] as String? ??
            'Request failed with status ${response.statusCode}.',
      );
    }
    return payload;
  }
}

class ProviderCatalogException implements Exception {
  ProviderCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
