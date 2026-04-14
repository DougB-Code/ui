import 'package:http/http.dart' as http;
import 'package:ui/shared/admin_http_client.dart';

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

class ProviderPreviewResult {
  ProviderPreviewResult({
    required this.provider,
    required this.yamlPreview,
    required this.validationStatus,
    required this.validationSummary,
  });

  factory ProviderPreviewResult.fromJson(Map<String, dynamic> json) {
    return ProviderPreviewResult(
      provider: ProviderConfig.fromJson(
        (json['provider'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      yamlPreview: (json['yaml_preview'] as String? ?? '').trimRight(),
      validationStatus: (json['validation_status'] as String? ?? '').trim(),
      validationSummary: (json['validation_summary'] as String? ?? '').trim(),
    );
  }

  final ProviderConfig provider;
  final String yamlPreview;
  final String validationStatus;
  final String validationSummary;
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

  Future<ProviderPreviewResult> previewProvider(ProviderConfig provider);
}

class HttpProviderCatalogApi implements ProviderCatalogApi {
  HttpProviderCatalogApi({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _http = AdminHttpClient(
         baseUrl: baseUrl,
         adminToken: adminToken,
         client: client,
       );

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
  final AdminHttpClient _http;

  @override
  Future<ProviderMutationResult> createProvider(ProviderConfig provider) async {
    final response = await _http.post(
      '/v1/admin/harness/providers',
      body: provider.toUpsertJson(),
    );
    final payload = await _http.decodeJsonMap(
      response,
      ProviderCatalogException.new,
    );
    return ProviderMutationResult.fromJson(payload);
  }

  @override
  Future<ProviderCatalog> deleteProvider(String alias) async {
    final response = await _http.delete(
      '/v1/admin/harness/providers/${Uri.encodeComponent(alias)}',
    );
    final payload = await _http.decodeJsonMap(
      response,
      ProviderCatalogException.new,
    );
    return ProviderCatalog.fromJson(payload);
  }

  @override
  Future<ProviderCatalog> listProviders() async {
    final response = await _http.get('/v1/admin/harness/providers');
    final payload = await _http.decodeJsonMap(
      response,
      ProviderCatalogException.new,
    );
    return ProviderCatalog.fromJson(payload);
  }

  @override
  Future<ProviderMutationResult> updateProvider(
    String currentAlias,
    ProviderConfig provider,
  ) async {
    final response = await _http.put(
      '/v1/admin/harness/providers/${Uri.encodeComponent(currentAlias)}',
      body: provider.toUpsertJson(),
    );
    final payload = await _http.decodeJsonMap(
      response,
      ProviderCatalogException.new,
    );
    return ProviderMutationResult.fromJson(payload);
  }

  @override
  Future<ProviderVerificationReport> verifyProvider(String alias) async {
    final response = await _http.post(
      '/v1/admin/harness/providers/${Uri.encodeComponent(alias)}/verify',
    );
    final payload = await _http.decodeJsonMap(
      response,
      ProviderCatalogException.new,
    );
    return ProviderVerificationReport.fromJson(payload);
  }

  @override
  Future<ProviderPreviewResult> previewProvider(ProviderConfig provider) async {
    final response = await _http.post(
      '/v1/admin/harness/providers/preview',
      body: provider.toUpsertJson(),
    );
    final payload = await _http.decodeJsonMap(
      response,
      ProviderCatalogException.new,
    );
    return ProviderPreviewResult.fromJson(payload);
  }
}

class ProviderCatalogException implements Exception {
  ProviderCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
