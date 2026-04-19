import 'package:http/http.dart' as http;
import 'package:ui/shared/admin_http_client.dart';

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((dynamic item) => item.toString().trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}

Map<String, String> _stringMap(dynamic value) {
  return (value as Map<String, dynamic>? ?? const <String, dynamic>{}).map(
    (String key, dynamic entry) =>
        MapEntry<String, String>(key.trim(), entry.toString().trim()),
  )..removeWhere((String key, String entry) => key.isEmpty || entry.isEmpty);
}

class HarnessAgentTemplateSummary {
  HarnessAgentTemplateSummary({
    required this.name,
    required this.role,
    required this.policyPreset,
    required this.maxSteps,
    required this.allowedToolGroups,
  });

  factory HarnessAgentTemplateSummary.fromJson(Map<String, dynamic> json) {
    return HarnessAgentTemplateSummary(
      name: (json['name'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? '').trim(),
      policyPreset: (json['policy_preset'] as String? ?? '').trim(),
      maxSteps: json['max_steps'] as int? ?? 0,
      allowedToolGroups:
          (json['allowed_tool_groups'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
    );
  }

  final String name;
  final String role;
  final String policyPreset;
  final int maxSteps;
  final List<String> allowedToolGroups;
}

class HarnessAgentSummary {
  HarnessAgentSummary({
    required this.name,
    required this.template,
    required this.role,
    required this.model,
    required this.maxSteps,
    required this.toolGroups,
    required this.allowedTools,
    required this.policyPreset,
  });

  factory HarnessAgentSummary.fromJson(Map<String, dynamic> json) {
    return HarnessAgentSummary(
      name: (json['name'] as String? ?? '').trim(),
      template: (json['template'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? '').trim(),
      model: (json['model'] as String? ?? '').trim(),
      maxSteps: json['max_steps'] as int? ?? 0,
      toolGroups: (json['tool_groups'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .toList(),
      allowedTools:
          (json['allowed_tools'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      policyPreset: (json['policy_preset'] as String? ?? '').trim(),
    );
  }

  final String name;
  final String template;
  final String role;
  final String model;
  final int maxSteps;
  final List<String> toolGroups;
  final List<String> allowedTools;
  final String policyPreset;
}

class HarnessAgentCatalog {
  HarnessAgentCatalog({
    required this.configPath,
    required this.yaml,
    required this.leadAgent,
    required this.approvalMode,
    required this.defaultMaxSteps,
    required this.recentLedgerLimit,
    required this.memoryRetentionDays,
    required this.subagentsEnabled,
    required this.subagentDefaultMaxSteps,
    required this.policyPresets,
    required this.roleTemplates,
    required this.agents,
  });

  factory HarnessAgentCatalog.fromJson(Map<String, dynamic> json) {
    return HarnessAgentCatalog(
      configPath: (json['config_path'] as String? ?? '').trim(),
      yaml: json['yaml'] as String? ?? '',
      leadAgent: (json['lead_agent'] as String? ?? '').trim(),
      approvalMode: (json['approval_mode'] as String? ?? '').trim(),
      defaultMaxSteps: json['default_max_steps'] as int? ?? 0,
      recentLedgerLimit: json['recent_ledger_limit'] as int? ?? 0,
      memoryRetentionDays: json['memory_retention_days'] as int? ?? 0,
      subagentsEnabled: json['subagents_enabled'] as bool? ?? false,
      subagentDefaultMaxSteps: json['subagent_default_max_steps'] as int? ?? 0,
      policyPresets:
          (json['policy_presets'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      roleTemplates:
          (json['role_templates'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(HarnessAgentTemplateSummary.fromJson)
              .toList(),
      agents: (json['agents'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessAgentSummary.fromJson)
          .toList(),
    );
  }

  final String configPath;
  final String yaml;
  final String leadAgent;
  final String approvalMode;
  final int defaultMaxSteps;
  final int recentLedgerLimit;
  final int memoryRetentionDays;
  final bool subagentsEnabled;
  final int subagentDefaultMaxSteps;
  final List<String> policyPresets;
  final List<HarnessAgentTemplateSummary> roleTemplates;
  final List<HarnessAgentSummary> agents;
}

class HarnessToolGroupSummary {
  HarnessToolGroupSummary({required this.name, required this.tools});

  factory HarnessToolGroupSummary.fromJson(Map<String, dynamic> json) {
    return HarnessToolGroupSummary(
      name: (json['name'] as String? ?? '').trim(),
      tools: (json['tools'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .toList(),
    );
  }

  final String name;
  final List<String> tools;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'tools': tools};
  }
}

class HarnessExternalToolTempFile {
  HarnessExternalToolTempFile({
    required this.name,
    required this.inputKey,
    required this.format,
    required this.suffix,
    required this.required,
  });

  factory HarnessExternalToolTempFile.fromJson(Map<String, dynamic> json) {
    return HarnessExternalToolTempFile(
      name: (json['name'] as String? ?? '').trim(),
      inputKey: (json['input_key'] as String? ?? '').trim(),
      format: (json['format'] as String? ?? '').trim(),
      suffix: (json['suffix'] as String? ?? '').trim(),
      required: json['required'] as bool? ?? false,
    );
  }

  final String name;
  final String inputKey;
  final String format;
  final String suffix;
  final bool required;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'input_key': inputKey,
      'format': format,
      'suffix': suffix,
      'required': required,
    };
  }
}

class HarnessExternalToolPlatformSummary {
  HarnessExternalToolPlatformSummary({
    required this.timeoutSeconds,
    required this.command,
    required this.args,
    required this.workingDir,
    required this.env,
    required this.stdinMode,
    required this.tempFiles,
    required this.outputFormat,
  });

  factory HarnessExternalToolPlatformSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return HarnessExternalToolPlatformSummary(
      timeoutSeconds: json['timeout_seconds'] as int? ?? 0,
      command: _stringList(json['command']),
      args: _stringList(json['args']),
      workingDir: (json['working_dir'] as String? ?? '').trim(),
      env: _stringMap(json['env']),
      stdinMode: (json['stdin_mode'] as String? ?? '').trim(),
      tempFiles: (json['temp_files'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessExternalToolTempFile.fromJson)
          .toList(),
      outputFormat: (json['output_format'] as String? ?? '').trim(),
    );
  }

  final int timeoutSeconds;
  final List<String> command;
  final List<String> args;
  final String workingDir;
  final Map<String, String> env;
  final String stdinMode;
  final List<HarnessExternalToolTempFile> tempFiles;
  final String outputFormat;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (timeoutSeconds != 0) 'timeout_seconds': timeoutSeconds,
      if (command.isNotEmpty) 'command': command,
      if (args.isNotEmpty) 'args': args,
      if (workingDir.isNotEmpty) 'working_dir': workingDir,
      if (env.isNotEmpty) 'env': env,
      if (stdinMode.isNotEmpty) 'stdin_mode': stdinMode,
      if (tempFiles.isNotEmpty)
        'temp_files': tempFiles
            .map((HarnessExternalToolTempFile value) => value.toJson())
            .toList(),
      if (outputFormat.isNotEmpty) 'output_format': outputFormat,
    };
  }
}

class HarnessExternalToolSummary {
  HarnessExternalToolSummary({
    required this.name,
    required this.inputSchema,
    required this.filesystem,
    required this.network,
    required this.idempotent,
    required this.timeoutSeconds,
    required this.command,
    required this.args,
    required this.workingDir,
    required this.env,
    required this.inheritEnv,
    required this.stdinMode,
    required this.tempFiles,
    required this.outputFormat,
    required this.platforms,
  });

  factory HarnessExternalToolSummary.fromJson(Map<String, dynamic> json) {
    return HarnessExternalToolSummary(
      name: (json['name'] as String? ?? '').trim(),
      inputSchema:
          (json['input_schema'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, dynamic>(key.trim(), value),
              ),
      filesystem: (json['filesystem'] as String? ?? '').trim(),
      network: json['network'] as bool? ?? false,
      idempotent: json['idempotent'] as bool? ?? false,
      timeoutSeconds: json['timeout_seconds'] as int? ?? 0,
      command: _stringList(json['command']),
      args: _stringList(json['args']),
      workingDir: (json['working_dir'] as String? ?? '').trim(),
      env: _stringMap(json['env']),
      inheritEnv: json['inherit_env'] as bool? ?? false,
      stdinMode: (json['stdin_mode'] as String? ?? '').trim(),
      tempFiles: (json['temp_files'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessExternalToolTempFile.fromJson)
          .toList(),
      outputFormat: (json['output_format'] as String? ?? '').trim(),
      platforms:
          (json['platforms'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .map(
                (String key, dynamic value) => MapEntry(
                  key.trim(),
                  HarnessExternalToolPlatformSummary.fromJson(
                    value as Map<String, dynamic>? ?? <String, dynamic>{},
                  ),
                ),
              ),
    );
  }

  final String name;
  final Map<String, dynamic> inputSchema;
  final String filesystem;
  final bool network;
  final bool idempotent;
  final int timeoutSeconds;
  final List<String> command;
  final List<String> args;
  final String workingDir;
  final Map<String, String> env;
  final bool inheritEnv;
  final String stdinMode;
  final List<HarnessExternalToolTempFile> tempFiles;
  final String outputFormat;
  final Map<String, HarnessExternalToolPlatformSummary> platforms;

  int get platformOverrideCount => platforms.length;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      if (inputSchema.isNotEmpty) 'input_schema': inputSchema,
      if (filesystem.isNotEmpty) 'filesystem': filesystem,
      if (network) 'network': network,
      if (idempotent) 'idempotent': idempotent,
      if (timeoutSeconds != 0) 'timeout_seconds': timeoutSeconds,
      if (command.isNotEmpty) 'command': command,
      if (args.isNotEmpty) 'args': args,
      if (workingDir.isNotEmpty) 'working_dir': workingDir,
      if (env.isNotEmpty) 'env': env,
      if (inheritEnv) 'inherit_env': inheritEnv,
      if (stdinMode.isNotEmpty) 'stdin_mode': stdinMode,
      if (tempFiles.isNotEmpty)
        'temp_files': tempFiles
            .map((HarnessExternalToolTempFile value) => value.toJson())
            .toList(),
      if (outputFormat.isNotEmpty) 'output_format': outputFormat,
      if (platforms.isNotEmpty)
        'platforms': platforms.map(
          (String key, HarnessExternalToolPlatformSummary value) =>
              MapEntry<String, dynamic>(key, value.toJson()),
        ),
    };
  }
}

class HarnessMcpServerPlatformSummary {
  HarnessMcpServerPlatformSummary({
    required this.lifecycle,
    required this.transport,
    required this.url,
    required this.healthcheckUrl,
    required this.command,
    required this.args,
    required this.workingDir,
    required this.env,
    required this.timeoutSeconds,
    required this.startupTimeoutSeconds,
    required this.shutdownTimeoutSeconds,
  });

  factory HarnessMcpServerPlatformSummary.fromJson(Map<String, dynamic> json) {
    return HarnessMcpServerPlatformSummary(
      lifecycle: (json['lifecycle'] as String? ?? '').trim(),
      transport: (json['transport'] as String? ?? '').trim(),
      url: (json['url'] as String? ?? '').trim(),
      healthcheckUrl: (json['healthcheck_url'] as String? ?? '').trim(),
      command: _stringList(json['command']),
      args: _stringList(json['args']),
      workingDir: (json['working_dir'] as String? ?? '').trim(),
      env: _stringMap(json['env']),
      timeoutSeconds: json['timeout_seconds'] as int? ?? 0,
      startupTimeoutSeconds: json['startup_timeout_seconds'] as int? ?? 0,
      shutdownTimeoutSeconds: json['shutdown_timeout_seconds'] as int? ?? 0,
    );
  }

  final String lifecycle;
  final String transport;
  final String url;
  final String healthcheckUrl;
  final List<String> command;
  final List<String> args;
  final String workingDir;
  final Map<String, String> env;
  final int timeoutSeconds;
  final int startupTimeoutSeconds;
  final int shutdownTimeoutSeconds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (lifecycle.isNotEmpty) 'lifecycle': lifecycle,
      if (transport.isNotEmpty) 'transport': transport,
      if (url.isNotEmpty) 'url': url,
      if (healthcheckUrl.isNotEmpty) 'healthcheck_url': healthcheckUrl,
      if (command.isNotEmpty) 'command': command,
      if (args.isNotEmpty) 'args': args,
      if (workingDir.isNotEmpty) 'working_dir': workingDir,
      if (env.isNotEmpty) 'env': env,
      if (timeoutSeconds != 0) 'timeout_seconds': timeoutSeconds,
      if (startupTimeoutSeconds != 0)
        'startup_timeout_seconds': startupTimeoutSeconds,
      if (shutdownTimeoutSeconds != 0)
        'shutdown_timeout_seconds': shutdownTimeoutSeconds,
    };
  }
}

class HarnessMcpServerSummary {
  HarnessMcpServerSummary({
    required this.name,
    required this.lifecycle,
    required this.transport,
    required this.url,
    required this.healthcheckUrl,
    required this.command,
    required this.args,
    required this.workingDir,
    required this.env,
    required this.inheritEnv,
    required this.timeoutSeconds,
    required this.startupTimeoutSeconds,
    required this.shutdownTimeoutSeconds,
    required this.toolNamePrefix,
    required this.includeTools,
    required this.excludeTools,
    required this.filesystem,
    required this.network,
    required this.idempotent,
    required this.platforms,
  });

  factory HarnessMcpServerSummary.fromJson(Map<String, dynamic> json) {
    return HarnessMcpServerSummary(
      name: (json['name'] as String? ?? '').trim(),
      lifecycle: (json['lifecycle'] as String? ?? '').trim(),
      transport: (json['transport'] as String? ?? '').trim(),
      url: (json['url'] as String? ?? '').trim(),
      healthcheckUrl: (json['healthcheck_url'] as String? ?? '').trim(),
      command: _stringList(json['command']),
      args: _stringList(json['args']),
      workingDir: (json['working_dir'] as String? ?? '').trim(),
      env: _stringMap(json['env']),
      inheritEnv: json['inherit_env'] as bool? ?? false,
      timeoutSeconds: json['timeout_seconds'] as int? ?? 0,
      startupTimeoutSeconds: json['startup_timeout_seconds'] as int? ?? 0,
      shutdownTimeoutSeconds: json['shutdown_timeout_seconds'] as int? ?? 0,
      toolNamePrefix: (json['tool_name_prefix'] as String? ?? '').trim(),
      includeTools: _stringList(json['include_tools']),
      excludeTools: _stringList(json['exclude_tools']),
      filesystem: (json['filesystem'] as String? ?? '').trim(),
      network: json['network'] as bool? ?? false,
      idempotent: json['idempotent'] as bool? ?? false,
      platforms:
          (json['platforms'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .map(
                (String key, dynamic value) => MapEntry(
                  key.trim(),
                  HarnessMcpServerPlatformSummary.fromJson(
                    value as Map<String, dynamic>? ?? <String, dynamic>{},
                  ),
                ),
              ),
    );
  }

  final String name;
  final String lifecycle;
  final String transport;
  final String url;
  final String healthcheckUrl;
  final List<String> command;
  final List<String> args;
  final String workingDir;
  final Map<String, String> env;
  final bool inheritEnv;
  final int timeoutSeconds;
  final int startupTimeoutSeconds;
  final int shutdownTimeoutSeconds;
  final String toolNamePrefix;
  final List<String> includeTools;
  final List<String> excludeTools;
  final String filesystem;
  final bool network;
  final bool idempotent;
  final Map<String, HarnessMcpServerPlatformSummary> platforms;

  int get platformOverrideCount => platforms.length;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      if (lifecycle.isNotEmpty) 'lifecycle': lifecycle,
      if (transport.isNotEmpty) 'transport': transport,
      if (url.isNotEmpty) 'url': url,
      if (healthcheckUrl.isNotEmpty) 'healthcheck_url': healthcheckUrl,
      if (command.isNotEmpty) 'command': command,
      if (args.isNotEmpty) 'args': args,
      if (workingDir.isNotEmpty) 'working_dir': workingDir,
      if (env.isNotEmpty) 'env': env,
      if (inheritEnv) 'inherit_env': inheritEnv,
      if (timeoutSeconds != 0) 'timeout_seconds': timeoutSeconds,
      if (startupTimeoutSeconds != 0)
        'startup_timeout_seconds': startupTimeoutSeconds,
      if (shutdownTimeoutSeconds != 0)
        'shutdown_timeout_seconds': shutdownTimeoutSeconds,
      if (toolNamePrefix.isNotEmpty) 'tool_name_prefix': toolNamePrefix,
      if (includeTools.isNotEmpty) 'include_tools': includeTools,
      if (excludeTools.isNotEmpty) 'exclude_tools': excludeTools,
      if (filesystem.isNotEmpty) 'filesystem': filesystem,
      if (network) 'network': network,
      if (idempotent) 'idempotent': idempotent,
      if (platforms.isNotEmpty)
        'platforms': platforms.map(
          (String key, HarnessMcpServerPlatformSummary value) =>
              MapEntry<String, dynamic>(key, value.toJson()),
        ),
    };
  }
}

class HarnessToolCatalog {
  HarnessToolCatalog({
    required this.configPath,
    required this.yaml,
    required this.toolGroups,
    required this.externalTools,
    required this.mcpServers,
  });

  factory HarnessToolCatalog.fromJson(Map<String, dynamic> json) {
    return HarnessToolCatalog(
      configPath: (json['config_path'] as String? ?? '').trim(),
      yaml: json['yaml'] as String? ?? '',
      toolGroups: (json['tool_groups'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessToolGroupSummary.fromJson)
          .toList(),
      externalTools:
          (json['external_tools'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(HarnessExternalToolSummary.fromJson)
              .toList(),
      mcpServers: (json['mcp_servers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessMcpServerSummary.fromJson)
          .toList(),
    );
  }

  final String configPath;
  final String yaml;
  final List<HarnessToolGroupSummary> toolGroups;
  final List<HarnessExternalToolSummary> externalTools;
  final List<HarnessMcpServerSummary> mcpServers;

  Map<String, dynamic> toJson({bool includeYaml = false}) {
    return <String, dynamic>{
      if (includeYaml && yaml.isNotEmpty) 'yaml': yaml,
      'tool_groups': toolGroups
          .map((HarnessToolGroupSummary value) => value.toJson())
          .toList(),
      'external_tools': externalTools
          .map((HarnessExternalToolSummary value) => value.toJson())
          .toList(),
      'mcp_servers': mcpServers
          .map((HarnessMcpServerSummary value) => value.toJson())
          .toList(),
    };
  }
}

class HarnessWorkflowRuleSetSummary {
  HarnessWorkflowRuleSetSummary({
    required this.name,
    required this.sourceKind,
    required this.basePath,
    required this.patternCount,
    required this.embeddedRuleCount,
    required this.knowledgeBaseName,
    required this.knowledgeBaseVersion,
  });

  factory HarnessWorkflowRuleSetSummary.fromJson(Map<String, dynamic> json) {
    return HarnessWorkflowRuleSetSummary(
      name: (json['name'] as String? ?? '').trim(),
      sourceKind: (json['source_kind'] as String? ?? '').trim(),
      basePath: (json['base_path'] as String? ?? '').trim(),
      patternCount: json['pattern_count'] as int? ?? 0,
      embeddedRuleCount: json['embedded_rule_count'] as int? ?? 0,
      knowledgeBaseName: (json['knowledge_base_name'] as String? ?? '').trim(),
      knowledgeBaseVersion: (json['knowledge_base_version'] as String? ?? '')
          .trim(),
    );
  }

  final String name;
  final String sourceKind;
  final String basePath;
  final int patternCount;
  final int embeddedRuleCount;
  final String knowledgeBaseName;
  final String knowledgeBaseVersion;
}

class HarnessWorkflowInputMapSummary {
  HarnessWorkflowInputMapSummary({
    required this.fromNode,
    required this.outputKey,
    required this.inputKey,
    required this.required,
    required this.overwrite,
  });

  factory HarnessWorkflowInputMapSummary.fromJson(Map<String, dynamic> json) {
    return HarnessWorkflowInputMapSummary(
      fromNode: (json['from_node'] as String? ?? '').trim(),
      outputKey: (json['output_key'] as String? ?? '').trim(),
      inputKey: (json['input_key'] as String? ?? '').trim(),
      required: json['required'] as bool? ?? false,
      overwrite: json['overwrite'] as bool? ?? false,
    );
  }

  final String fromNode;
  final String outputKey;
  final String inputKey;
  final bool required;
  final bool overwrite;
}

class HarnessWorkflowTransitionsSummary {
  HarnessWorkflowTransitionsSummary({
    required this.success,
    required this.failure,
    required this.blocked,
  });

  factory HarnessWorkflowTransitionsSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return HarnessWorkflowTransitionsSummary(
      success: (json['success'] as String? ?? '').trim(),
      failure: (json['failure'] as String? ?? '').trim(),
      blocked: (json['blocked'] as String? ?? '').trim(),
    );
  }

  final String success;
  final String failure;
  final String blocked;

  List<MapEntry<String, String>> targets() {
    return <MapEntry<String, String>>[
      if (success.isNotEmpty) MapEntry<String, String>('success', success),
      if (failure.isNotEmpty) MapEntry<String, String>('failure', failure),
      if (blocked.isNotEmpty) MapEntry<String, String>('blocked', blocked),
    ];
  }
}

class HarnessWorkflowNodeSummary {
  HarnessWorkflowNodeSummary({
    required this.id,
    required this.kind,
    required this.uses,
    required this.withKeys,
    required this.requiredInputKeys,
    required this.optionalInputKeys,
    required this.requiredDataKeys,
    required this.producesGateDecision,
    required this.transitions,
    required this.maxVisits,
    required this.maxFailures,
    required this.implementation,
    required this.requiresGates,
    required this.includeNodeResults,
    required this.inputMappings,
    required this.promptInstructionCount,
    required this.gatePassStatuses,
    required this.gateFailStatuses,
    required this.gatePassExitCodes,
    required this.gateFailExitCodes,
    required this.treatRetryableAsFail,
    required this.policyGateEnabled,
    required this.policyGateRuleSet,
    required this.policyGateFactBindings,
    required this.policyGateRouteHints,
    required this.policyGateOnEvalError,
    required this.policyGateMergeFindings,
    required this.policyGateOverrideStatus,
    required this.requiredChangedFiles,
    required this.requiredToolCalls,
  });

  factory HarnessWorkflowNodeSummary.fromJson(Map<String, dynamic> json) {
    final kind = (json['kind'] as String? ?? '').trim();
    return HarnessWorkflowNodeSummary(
      id: (json['id'] as String? ?? '').trim(),
      kind: kind == 'gate' ? 'check' : kind,
      uses: ((json['runs'] ?? json['uses']) as String? ?? '').trim(),
      withKeys: (json['with_keys'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .toList(),
      requiredInputKeys:
          (json['required_input_keys'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      optionalInputKeys:
          (json['optional_input_keys'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      requiredDataKeys:
          (json['required_data_keys'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      producesGateDecision:
          (json['produces_check_decision'] as bool?) ??
          (json['produces_gate_decision'] as bool?) ??
          false,
      transitions: HarnessWorkflowTransitionsSummary.fromJson(
        (json['transitions'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      maxVisits: json['max_visits'] as int? ?? 0,
      maxFailures: json['max_failures'] as int? ?? 0,
      implementation: json['implementation'] as bool? ?? false,
      requiresGates:
          ((json['requires_checks'] ?? json['requires_gates'])
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      includeNodeResults:
          (json['include_node_results'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      inputMappings:
          (json['input_mappings'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(HarnessWorkflowInputMapSummary.fromJson)
              .toList(),
      promptInstructionCount: json['prompt_instruction_count'] as int? ?? 0,
      gatePassStatuses:
          ((json['check_pass_statuses'] ?? json['gate_pass_statuses'])
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      gateFailStatuses:
          ((json['check_fail_statuses'] ?? json['gate_fail_statuses'])
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      gatePassExitCodes:
          ((json['check_pass_exit_codes'] ?? json['gate_pass_exit_codes'])
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => (value as num).toInt())
              .toList(),
      gateFailExitCodes:
          ((json['check_fail_exit_codes'] ?? json['gate_fail_exit_codes'])
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => (value as num).toInt())
              .toList(),
      treatRetryableAsFail: json['treat_retryable_as_fail'] as bool? ?? false,
      policyGateEnabled:
          (json['rules_enabled'] as bool?) ??
          (json['policy_gate_enabled'] as bool?) ??
          false,
      policyGateRuleSet:
          ((json['rules_rule_set'] ?? json['policy_gate_rule_set'])
                      as String? ??
                  '')
              .trim(),
      policyGateFactBindings:
          ((json['rules_fact_bindings'] ?? json['policy_gate_fact_bindings'])
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      policyGateRouteHints:
          ((json['rules_route_hints'] ?? json['policy_gate_route_hints'])
                      as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      policyGateOnEvalError:
          ((json['rules_on_evaluation_error'] ??
                          json['policy_gate_on_evaluation_error'])
                      as String? ??
                  '')
              .trim(),
      policyGateMergeFindings:
          ((json['rules_merge_findings'] ?? json['policy_gate_merge_findings'])
                      as String? ??
                  '')
              .trim(),
      policyGateOverrideStatus:
          (json['rules_override_check_status'] as bool?) ??
          (json['policy_gate_override_gate_status'] as bool?) ??
          false,
      requiredChangedFiles:
          (json['required_changed_files'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      requiredToolCalls:
          (json['required_tool_calls'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
    );
  }

  final String id;
  final String kind;
  final String uses;
  final List<String> withKeys;
  final List<String> requiredInputKeys;
  final List<String> optionalInputKeys;
  final List<String> requiredDataKeys;
  final bool producesGateDecision;
  final HarnessWorkflowTransitionsSummary transitions;
  final int maxVisits;
  final int maxFailures;
  final bool implementation;
  final List<String> requiresGates;
  final List<String> includeNodeResults;
  final List<HarnessWorkflowInputMapSummary> inputMappings;
  final int promptInstructionCount;
  final List<String> gatePassStatuses;
  final List<String> gateFailStatuses;
  final List<int> gatePassExitCodes;
  final List<int> gateFailExitCodes;
  final bool treatRetryableAsFail;
  final bool policyGateEnabled;
  final String policyGateRuleSet;
  final List<String> policyGateFactBindings;
  final List<String> policyGateRouteHints;
  final String policyGateOnEvalError;
  final String policyGateMergeFindings;
  final bool policyGateOverrideStatus;
  final List<String> requiredChangedFiles;
  final List<String> requiredToolCalls;
}

class HarnessWorkflowSummary {
  HarnessWorkflowSummary({
    required this.name,
    required this.startNode,
    required this.maxVisitsPerNode,
    required this.maxTotalTransitions,
    required this.duplicateResultCap,
    required this.ruleSets,
    required this.nodes,
  });

  factory HarnessWorkflowSummary.fromJson(Map<String, dynamic> json) {
    return HarnessWorkflowSummary(
      name: (json['name'] as String? ?? '').trim(),
      startNode: (json['start_node'] as String? ?? '').trim(),
      maxVisitsPerNode: json['max_visits_per_node'] as int? ?? 0,
      maxTotalTransitions: json['max_total_transitions'] as int? ?? 0,
      duplicateResultCap: json['duplicate_result_cap'] as int? ?? 0,
      ruleSets: (json['rule_sets'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessWorkflowRuleSetSummary.fromJson)
          .toList(),
      nodes: (json['nodes'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessWorkflowNodeSummary.fromJson)
          .toList(),
    );
  }

  final String name;
  final String startNode;
  final int maxVisitsPerNode;
  final int maxTotalTransitions;
  final int duplicateResultCap;
  final List<HarnessWorkflowRuleSetSummary> ruleSets;
  final List<HarnessWorkflowNodeSummary> nodes;
}

class HarnessWorkflowCatalog {
  HarnessWorkflowCatalog({
    required this.configPath,
    required this.yaml,
    required this.workflows,
  });

  factory HarnessWorkflowCatalog.fromJson(Map<String, dynamic> json) {
    return HarnessWorkflowCatalog(
      configPath: (json['config_path'] as String? ?? '').trim(),
      yaml: json['yaml'] as String? ?? '',
      workflows: (json['workflows'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessWorkflowSummary.fromJson)
          .toList(),
    );
  }

  final String configPath;
  final String yaml;
  final List<HarnessWorkflowSummary> workflows;
}

class HarnessConfigValidationReport {
  HarnessConfigValidationReport({
    required this.target,
    required this.status,
    required this.summary,
    required this.providerCount,
    required this.enabledProviderCount,
    required this.enabledModelCount,
    required this.probedProviderCount,
    required this.probedModelCount,
    required this.validatedModels,
    required this.failedModels,
    required this.probeErrors,
    required this.agentCount,
    required this.leadAgent,
    required this.workflowCount,
    required this.externalToolCount,
    required this.mcpServerCount,
    required this.toolPlatform,
    required this.availableExternalTools,
    required this.unavailableExternalTools,
    required this.externalToolErrors,
    required this.availableMcpServers,
    required this.unavailableMcpServers,
    required this.mcpServerErrors,
  });

  factory HarnessConfigValidationReport.fromJson(Map<String, dynamic> json) {
    return HarnessConfigValidationReport(
      target: (json['target'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      providerCount: json['provider_count'] as int? ?? 0,
      enabledProviderCount: json['enabled_provider_count'] as int? ?? 0,
      enabledModelCount: json['enabled_model_count'] as int? ?? 0,
      probedProviderCount: json['probed_provider_count'] as int? ?? 0,
      probedModelCount: json['probed_model_count'] as int? ?? 0,
      validatedModels:
          (json['validated_models'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      failedModels:
          (json['failed_models'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      probeErrors:
          ((json['probe_errors'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, String>(key, value.toString()),
              ),
      agentCount: json['agent_count'] as int? ?? 0,
      leadAgent: (json['lead_agent'] as String? ?? '').trim(),
      workflowCount: json['workflow_count'] as int? ?? 0,
      externalToolCount: json['external_tool_count'] as int? ?? 0,
      mcpServerCount: json['mcp_server_count'] as int? ?? 0,
      toolPlatform: (json['tool_platform'] as String? ?? '').trim(),
      availableExternalTools:
          (json['available_external_tools'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      unavailableExternalTools:
          (json['unavailable_external_tools'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      externalToolErrors:
          ((json['external_tool_errors'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, String>(key, value.toString()),
              ),
      availableMcpServers:
          (json['available_mcp_servers'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      unavailableMcpServers:
          (json['unavailable_mcp_servers'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      mcpServerErrors:
          ((json['mcp_server_errors'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, String>(key, value.toString()),
              ),
    );
  }

  final String target;
  final String status;
  final String summary;
  final int providerCount;
  final int enabledProviderCount;
  final int enabledModelCount;
  final int probedProviderCount;
  final int probedModelCount;
  final List<String> validatedModels;
  final List<String> failedModels;
  final Map<String, String> probeErrors;
  final int agentCount;
  final String leadAgent;
  final int workflowCount;
  final int externalToolCount;
  final int mcpServerCount;
  final String toolPlatform;
  final List<String> availableExternalTools;
  final List<String> unavailableExternalTools;
  final Map<String, String> externalToolErrors;
  final List<String> availableMcpServers;
  final List<String> unavailableMcpServers;
  final Map<String, String> mcpServerErrors;
}

abstract class HarnessConfigApi {
  Future<HarnessAgentCatalog> getAgents();

  Future<HarnessConfigValidationReport> validateAgents(String yaml);

  Future<HarnessAgentCatalog> saveAgents(String yaml);

  Future<HarnessToolCatalog> getTools();

  Future<HarnessConfigValidationReport> validateTools(String yaml);

  Future<HarnessToolCatalog> saveTools(String yaml);

  Future<HarnessConfigValidationReport> validateToolsCatalog(
    HarnessToolCatalog catalog,
  );

  Future<HarnessToolCatalog> saveToolsCatalog(HarnessToolCatalog catalog);

  Future<HarnessWorkflowCatalog> getWorkflows();

  Future<HarnessConfigValidationReport> validateWorkflows(String yaml);

  Future<HarnessWorkflowCatalog> saveWorkflows(String yaml);
}

class HttpHarnessConfigApi implements HarnessConfigApi {
  HttpHarnessConfigApi({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _http = AdminHttpClient(
         baseUrl: baseUrl,
         adminToken: adminToken,
         client: client,
       );

  factory HttpHarnessConfigApi.fromEnvironment() {
    return HttpHarnessConfigApi(
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
  Future<HarnessAgentCatalog> getAgents() async {
    final response = await _http.get('/v1/admin/harness/agents');
    return HarnessAgentCatalog.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessToolCatalog> getTools() async {
    final response = await _http.get('/v1/admin/harness/tools');
    return HarnessToolCatalog.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessAgentCatalog> saveAgents(String yaml) async {
    final response = await _http.put(
      '/v1/admin/harness/agents',
      body: <String, dynamic>{'yaml': yaml},
    );
    return HarnessAgentCatalog.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessToolCatalog> saveTools(String yaml) async {
    final response = await _http.put(
      '/v1/admin/harness/tools',
      body: <String, dynamic>{'yaml': yaml},
    );
    return HarnessToolCatalog.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessToolCatalog> saveToolsCatalog(
    HarnessToolCatalog catalog,
  ) async {
    final response = await _http.put(
      '/v1/admin/harness/tools',
      body: catalog.toJson(),
    );
    return HarnessToolCatalog.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessWorkflowCatalog> getWorkflows() async {
    final response = await _http.get('/v1/admin/harness/workflows');
    return HarnessWorkflowCatalog.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessWorkflowCatalog> saveWorkflows(String yaml) async {
    final response = await _http.put(
      '/v1/admin/harness/workflows',
      body: <String, dynamic>{'yaml': yaml},
    );
    return HarnessWorkflowCatalog.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessConfigValidationReport> validateAgents(String yaml) async {
    final response = await _http.post(
      '/v1/admin/harness/agents/validate',
      body: <String, dynamic>{'yaml': yaml},
    );
    return HarnessConfigValidationReport.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessConfigValidationReport> validateTools(String yaml) async {
    final response = await _http.post(
      '/v1/admin/harness/tools/validate',
      body: <String, dynamic>{'yaml': yaml},
    );
    return HarnessConfigValidationReport.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessConfigValidationReport> validateToolsCatalog(
    HarnessToolCatalog catalog,
  ) async {
    final response = await _http.post(
      '/v1/admin/harness/tools/validate',
      body: catalog.toJson(),
    );
    return HarnessConfigValidationReport.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }

  @override
  Future<HarnessConfigValidationReport> validateWorkflows(String yaml) async {
    final response = await _http.post(
      '/v1/admin/harness/workflows/validate',
      body: <String, dynamic>{'yaml': yaml},
    );
    return HarnessConfigValidationReport.fromJson(
      await _http.decodeJsonMap(response, HarnessConfigApiException.new),
    );
  }
}

class HarnessConfigApiException implements Exception {
  HarnessConfigApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
