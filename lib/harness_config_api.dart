import 'dart:convert';

import 'package:http/http.dart' as http;

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
}

class HarnessExternalToolSummary {
  HarnessExternalToolSummary({
    required this.name,
    required this.enabled,
    required this.trusted,
    required this.toolClass,
    required this.location,
    required this.command,
    required this.platformOverrideCount,
  });

  factory HarnessExternalToolSummary.fromJson(Map<String, dynamic> json) {
    return HarnessExternalToolSummary(
      name: (json['name'] as String? ?? '').trim(),
      enabled: json['enabled'] as bool? ?? false,
      trusted: json['trusted'] as bool? ?? false,
      toolClass: (json['class'] as String? ?? '').trim(),
      location: (json['location'] as String? ?? '').trim(),
      command: (json['command'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .toList(),
      platformOverrideCount: json['platform_override_count'] as int? ?? 0,
    );
  }

  final String name;
  final bool enabled;
  final bool trusted;
  final String toolClass;
  final String location;
  final List<String> command;
  final int platformOverrideCount;
}

class HarnessMcpServerSummary {
  HarnessMcpServerSummary({
    required this.name,
    required this.enabled,
    required this.trusted,
    required this.lifecycle,
    required this.transport,
    required this.url,
    required this.command,
    required this.toolNamePrefix,
    required this.platformOverrideCount,
  });

  factory HarnessMcpServerSummary.fromJson(Map<String, dynamic> json) {
    return HarnessMcpServerSummary(
      name: (json['name'] as String? ?? '').trim(),
      enabled: json['enabled'] as bool? ?? false,
      trusted: json['trusted'] as bool? ?? false,
      lifecycle: (json['lifecycle'] as String? ?? '').trim(),
      transport: (json['transport'] as String? ?? '').trim(),
      url: (json['url'] as String? ?? '').trim(),
      command: (json['command'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .toList(),
      toolNamePrefix: (json['tool_name_prefix'] as String? ?? '').trim(),
      platformOverrideCount: json['platform_override_count'] as int? ?? 0,
    );
  }

  final String name;
  final bool enabled;
  final bool trusted;
  final String lifecycle;
  final String transport;
  final String url;
  final List<String> command;
  final String toolNamePrefix;
  final int platformOverrideCount;
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
    return HarnessWorkflowNodeSummary(
      id: (json['id'] as String? ?? '').trim(),
      kind: (json['kind'] as String? ?? '').trim(),
      uses: (json['uses'] as String? ?? '').trim(),
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
      producesGateDecision: json['produces_gate_decision'] as bool? ?? false,
      transitions: HarnessWorkflowTransitionsSummary.fromJson(
        (json['transitions'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      maxVisits: json['max_visits'] as int? ?? 0,
      maxFailures: json['max_failures'] as int? ?? 0,
      implementation: json['implementation'] as bool? ?? false,
      requiresGates:
          (json['requires_gates'] as List<dynamic>? ?? const <dynamic>[])
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
          (json['gate_pass_statuses'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      gateFailStatuses:
          (json['gate_fail_statuses'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      gatePassExitCodes:
          (json['gate_pass_exit_codes'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => (value as num).toInt())
              .toList(),
      gateFailExitCodes:
          (json['gate_fail_exit_codes'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => (value as num).toInt())
              .toList(),
      treatRetryableAsFail: json['treat_retryable_as_fail'] as bool? ?? false,
      policyGateEnabled: json['policy_gate_enabled'] as bool? ?? false,
      policyGateRuleSet: (json['policy_gate_rule_set'] as String? ?? '').trim(),
      policyGateFactBindings:
          (json['policy_gate_fact_bindings'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      policyGateRouteHints:
          (json['policy_gate_route_hints'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic value) => value.toString().trim())
              .where((String value) => value.isNotEmpty)
              .toList(),
      policyGateOnEvalError:
          (json['policy_gate_on_evaluation_error'] as String? ?? '').trim(),
      policyGateMergeFindings:
          (json['policy_gate_merge_findings'] as String? ?? '').trim(),
      policyGateOverrideStatus:
          json['policy_gate_override_gate_status'] as bool? ?? false,
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
    required this.enabledExternalToolCount,
    required this.mcpServerCount,
    required this.enabledMcpServerCount,
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
      enabledExternalToolCount:
          json['enabled_external_tool_count'] as int? ?? 0,
      mcpServerCount: json['mcp_server_count'] as int? ?? 0,
      enabledMcpServerCount: json['enabled_mcp_server_count'] as int? ?? 0,
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
  final int enabledExternalToolCount;
  final int mcpServerCount;
  final int enabledMcpServerCount;
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

  Future<HarnessWorkflowCatalog> getWorkflows();

  Future<HarnessConfigValidationReport> validateWorkflows(String yaml);

  Future<HarnessWorkflowCatalog> saveWorkflows(String yaml);
}

class HttpHarnessConfigApi implements HarnessConfigApi {
  HttpHarnessConfigApi({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

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
  final http.Client _client;

  @override
  Future<HarnessAgentCatalog> getAgents() async {
    final response = await _client.get(
      _uri('/v1/admin/harness/agents'),
      headers: _headers(),
    );
    return HarnessAgentCatalog.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessToolCatalog> getTools() async {
    final response = await _client.get(
      _uri('/v1/admin/harness/tools'),
      headers: _headers(),
    );
    return HarnessToolCatalog.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessAgentCatalog> saveAgents(String yaml) async {
    final response = await _client.put(
      _uri('/v1/admin/harness/agents'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'yaml': yaml}),
    );
    return HarnessAgentCatalog.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessToolCatalog> saveTools(String yaml) async {
    final response = await _client.put(
      _uri('/v1/admin/harness/tools'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'yaml': yaml}),
    );
    return HarnessToolCatalog.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessWorkflowCatalog> getWorkflows() async {
    final response = await _client.get(
      _uri('/v1/admin/harness/workflows'),
      headers: _headers(),
    );
    return HarnessWorkflowCatalog.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessWorkflowCatalog> saveWorkflows(String yaml) async {
    final response = await _client.put(
      _uri('/v1/admin/harness/workflows'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'yaml': yaml}),
    );
    return HarnessWorkflowCatalog.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessConfigValidationReport> validateAgents(String yaml) async {
    final response = await _client.post(
      _uri('/v1/admin/harness/agents/validate'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'yaml': yaml}),
    );
    return HarnessConfigValidationReport.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessConfigValidationReport> validateTools(String yaml) async {
    final response = await _client.post(
      _uri('/v1/admin/harness/tools/validate'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'yaml': yaml}),
    );
    return HarnessConfigValidationReport.fromJson(await _decodeJson(response));
  }

  @override
  Future<HarnessConfigValidationReport> validateWorkflows(String yaml) async {
    final response = await _client.post(
      _uri('/v1/admin/harness/workflows/validate'),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{'yaml': yaml}),
    );
    return HarnessConfigValidationReport.fromJson(await _decodeJson(response));
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
      throw HarnessConfigApiException(
        payload['error'] as String? ??
            'Request failed with status ${response.statusCode}.',
      );
    }
    return payload;
  }
}

class HarnessConfigApiException implements Exception {
  HarnessConfigApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
