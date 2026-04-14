import 'dart:convert';

import 'package:http/http.dart' as http;

class SourceContext {
  SourceContext({
    required this.interface,
    required this.installationId,
    required this.externalWorkspaceId,
    required this.conversationId,
    required this.channelId,
    required this.threadId,
    required this.requestId,
  });

  factory SourceContext.fromJson(Map<String, dynamic> json) {
    return SourceContext(
      interface: (json['interface'] as String? ?? '').trim(),
      installationId: (json['installation_id'] as String? ?? '').trim(),
      externalWorkspaceId: (json['external_workspace_id'] as String? ?? '')
          .trim(),
      conversationId: (json['conversation_id'] as String? ?? '').trim(),
      channelId: (json['channel_id'] as String? ?? '').trim(),
      threadId: (json['thread_id'] as String? ?? '').trim(),
      requestId: (json['request_id'] as String? ?? '').trim(),
    );
  }

  final String interface;
  final String installationId;
  final String externalWorkspaceId;
  final String conversationId;
  final String channelId;
  final String threadId;
  final String requestId;
}

class ApprovalPolicySnapshot {
  ApprovalPolicySnapshot({
    required this.mode,
    required this.requiredRole,
    required this.expiresAfterSec,
  });

  factory ApprovalPolicySnapshot.fromJson(Map<String, dynamic> json) {
    return ApprovalPolicySnapshot(
      mode: (json['mode'] as String? ?? '').trim(),
      requiredRole: (json['required_role'] as String? ?? '').trim(),
      expiresAfterSec: json['expires_after_sec'] as int? ?? 0,
    );
  }

  final String mode;
  final String requiredRole;
  final int expiresAfterSec;
}

class RuntimeLimitsSnapshot {
  RuntimeLimitsSnapshot({required this.maxRunSeconds, required this.maxTurns});

  factory RuntimeLimitsSnapshot.fromJson(Map<String, dynamic> json) {
    return RuntimeLimitsSnapshot(
      maxRunSeconds: json['max_run_seconds'] as int? ?? 0,
      maxTurns: json['max_turns'] as int? ?? 0,
    );
  }

  final int maxRunSeconds;
  final int maxTurns;
}

class StorageScopeSnapshot {
  StorageScopeSnapshot({
    required this.namespace,
    required this.artifactPrefix,
    required this.allowedReadPrefixes,
    required this.allowedWritePrefixes,
    required this.retentionDays,
  });

  factory StorageScopeSnapshot.fromJson(Map<String, dynamic> json) {
    return StorageScopeSnapshot(
      namespace: (json['namespace'] as String? ?? '').trim(),
      artifactPrefix: (json['artifact_prefix'] as String? ?? '').trim(),
      allowedReadPrefixes:
          (json['allowed_read_prefixes'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      allowedWritePrefixes:
          (json['allowed_write_prefixes'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      retentionDays: json['retention_days'] as int? ?? 0,
    );
  }

  final String namespace;
  final String artifactPrefix;
  final List<String> allowedReadPrefixes;
  final List<String> allowedWritePrefixes;
  final int retentionDays;
}

class SecretBindingRefSnapshot {
  SecretBindingRefSnapshot({
    required this.name,
    required this.reference,
    required this.provider,
  });

  factory SecretBindingRefSnapshot.fromJson(Map<String, dynamic> json) {
    return SecretBindingRefSnapshot(
      name: (json['name'] as String? ?? '').trim(),
      reference: (json['reference'] as String? ?? '').trim(),
      provider: (json['provider'] as String? ?? '').trim(),
    );
  }

  final String name;
  final String reference;
  final String provider;
}

class RuntimeProfileSnapshot {
  RuntimeProfileSnapshot({
    required this.profileId,
    required this.version,
    required this.tenantId,
    required this.agentId,
    required this.model,
    required this.provider,
    required this.allowedCapabilities,
    required this.deniedCapabilities,
    required this.approvalPolicy,
    required this.writeScope,
    required this.storageScope,
    required this.secretBindings,
    required this.integrationPermissions,
    required this.runtimeLimits,
    required this.observabilityTags,
    required this.sourceLayers,
    required this.resolvedAt,
  });

  factory RuntimeProfileSnapshot.fromJson(Map<String, dynamic> json) {
    return RuntimeProfileSnapshot(
      profileId: (json['profile_id'] as String? ?? '').trim(),
      version: json['version'] as int? ?? 0,
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      model: (json['model'] as String? ?? '').trim(),
      provider: (json['provider'] as String? ?? '').trim(),
      allowedCapabilities:
          (json['allowed_capabilities'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      deniedCapabilities:
          (json['denied_capabilities'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      approvalPolicy: ApprovalPolicySnapshot.fromJson(
        (json['approval_policy'] as Map<String, dynamic>? ??
            <String, dynamic>{}),
      ),
      writeScope: (json['write_scope'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      storageScope: StorageScopeSnapshot.fromJson(
        (json['storage_scope'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      secretBindings: (json['secret_bindings'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SecretBindingRefSnapshot.fromJson)
          .toList(),
      integrationPermissions:
          (json['integration_permissions'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(),
      runtimeLimits: RuntimeLimitsSnapshot.fromJson(
        (json['runtime_limits'] as Map<String, dynamic>? ??
            <String, dynamic>{}),
      ),
      observabilityTags:
          ((json['observability_tags'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, String>(key, value.toString()),
              ),
      sourceLayers: (json['source_layers'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      resolvedAt: _parseDateTime(json['resolved_at']),
    );
  }

  final String profileId;
  final int version;
  final String tenantId;
  final String agentId;
  final String model;
  final String provider;
  final List<String> allowedCapabilities;
  final List<String> deniedCapabilities;
  final ApprovalPolicySnapshot approvalPolicy;
  final List<String> writeScope;
  final StorageScopeSnapshot storageScope;
  final List<SecretBindingRefSnapshot> secretBindings;
  final List<String> integrationPermissions;
  final RuntimeLimitsSnapshot runtimeLimits;
  final Map<String, String> observabilityTags;
  final List<String> sourceLayers;
  final DateTime? resolvedAt;
}

class OperatorActionRecord {
  OperatorActionRecord({
    required this.actorId,
    required this.action,
    required this.reason,
    required this.occurredAt,
  });

  factory OperatorActionRecord.fromJson(Map<String, dynamic> json) {
    return OperatorActionRecord(
      actorId: (json['actor_id'] as String? ?? '').trim(),
      action: (json['action'] as String? ?? '').trim(),
      reason: (json['reason'] as String? ?? '').trim(),
      occurredAt: _parseDateTime(json['occurred_at']),
    );
  }

  final String actorId;
  final String action;
  final String reason;
  final DateTime? occurredAt;
}

class RunRecord {
  RunRecord({
    required this.runId,
    required this.tenantId,
    required this.agentId,
    required this.actorId,
    required this.source,
    required this.invocationMode,
    required this.requestedAutonomyMode,
    required this.effectiveRuntimeProfileId,
    required this.effectiveRuntimeProfileVersion,
    required this.status,
    required this.waitReason,
    required this.createdAt,
    required this.startedAt,
    required this.completedAt,
    required this.artifactManifestReference,
    required this.resultSummary,
    required this.operatorActions,
    required this.profileSnapshot,
  });

  factory RunRecord.fromJson(Map<String, dynamic> json) {
    return RunRecord(
      runId: (json['run_id'] as String? ?? '').trim(),
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      actorId: (json['actor_id'] as String? ?? '').trim(),
      source: SourceContext.fromJson(
        (json['source'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      invocationMode: (json['invocation_mode'] as String? ?? '').trim(),
      requestedAutonomyMode: (json['requested_autonomy_mode'] as String? ?? '')
          .trim(),
      effectiveRuntimeProfileId:
          (json['effective_runtime_profile_id'] as String? ?? '').trim(),
      effectiveRuntimeProfileVersion:
          json['effective_runtime_profile_version'] as int? ?? 0,
      status: (json['status'] as String? ?? '').trim(),
      waitReason: (json['wait_reason'] as String? ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']),
      startedAt: _parseDateTime(json['started_at']),
      completedAt: _parseDateTime(json['completed_at']),
      artifactManifestReference:
          (json['artifact_manifest_reference'] as String? ?? '').trim(),
      resultSummary: (json['result_summary'] as String? ?? '').trim(),
      operatorActions:
          (json['operator_actions'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(OperatorActionRecord.fromJson)
              .toList(),
      profileSnapshot: RuntimeProfileSnapshot.fromJson(
        (json['profile_snapshot'] as Map<String, dynamic>? ??
            <String, dynamic>{}),
      ),
    );
  }

  final String runId;
  final String tenantId;
  final String agentId;
  final String actorId;
  final SourceContext source;
  final String invocationMode;
  final String requestedAutonomyMode;
  final String effectiveRuntimeProfileId;
  final int effectiveRuntimeProfileVersion;
  final String status;
  final String waitReason;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String artifactManifestReference;
  final String resultSummary;
  final List<OperatorActionRecord> operatorActions;
  final RuntimeProfileSnapshot profileSnapshot;
}

class HarnessExecutionBlockerRecord {
  HarnessExecutionBlockerRecord({
    required this.code,
    required this.nodeId,
    required this.summary,
    required this.retryable,
  });

  factory HarnessExecutionBlockerRecord.fromJson(Map<String, dynamic> json) {
    return HarnessExecutionBlockerRecord(
      code: (json['code'] as String? ?? '').trim(),
      nodeId: (json['node_id'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      retryable: json['retryable'] as bool? ?? false,
    );
  }

  final String code;
  final String nodeId;
  final String summary;
  final bool retryable;
}

class HarnessExecutionNodeResultRecord {
  HarnessExecutionNodeResultRecord({
    required this.nodeId,
    required this.outcome,
    required this.gateStatus,
    required this.summary,
    required this.errorCode,
    required this.retryable,
    required this.artifacts,
    required this.metadata,
  });

  factory HarnessExecutionNodeResultRecord.fromJson(Map<String, dynamic> json) {
    return HarnessExecutionNodeResultRecord(
      nodeId: (json['node_id'] as String? ?? '').trim(),
      outcome: (json['outcome'] as String? ?? '').trim(),
      gateStatus: (json['gate_status'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      errorCode: (json['error_code'] as String? ?? '').trim(),
      retryable: json['retryable'] as bool? ?? false,
      artifacts: (json['artifacts'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      metadata: _parseStringMap(json['metadata']),
    );
  }

  final String nodeId;
  final String outcome;
  final String gateStatus;
  final String summary;
  final String errorCode;
  final bool retryable;
  final List<String> artifacts;
  final Map<String, String> metadata;
}

class HarnessWorkflowExecutionStateRecord {
  HarnessWorkflowExecutionStateRecord({
    required this.currentNodeId,
    required this.artifactDir,
    required this.waitingReason,
    required this.transitionCount,
    required this.nodeVisitCounts,
    required this.nodeFailureCounts,
    required this.blocker,
    required this.nodeResults,
  });

  factory HarnessWorkflowExecutionStateRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return HarnessWorkflowExecutionStateRecord(
      currentNodeId: (json['current_node_id'] as String? ?? '').trim(),
      artifactDir: (json['artifact_dir'] as String? ?? '').trim(),
      waitingReason: (json['waiting_reason'] as String? ?? '').trim(),
      transitionCount: json['transition_count'] as int? ?? 0,
      nodeVisitCounts: _parseIntMap(json['node_visit_counts']),
      nodeFailureCounts: _parseIntMap(json['node_failure_counts']),
      blocker: (json['blocker'] as Map<String, dynamic>?) == null
          ? null
          : HarnessExecutionBlockerRecord.fromJson(
              json['blocker'] as Map<String, dynamic>,
            ),
      nodeResults: (json['node_results'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(HarnessExecutionNodeResultRecord.fromJson)
          .toList(),
    );
  }

  final String currentNodeId;
  final String artifactDir;
  final String waitingReason;
  final int transitionCount;
  final Map<String, int> nodeVisitCounts;
  final Map<String, int> nodeFailureCounts;
  final HarnessExecutionBlockerRecord? blocker;
  final List<HarnessExecutionNodeResultRecord> nodeResults;
}

class HarnessExecutionStructuredResultRecord {
  HarnessExecutionStructuredResultRecord({
    required this.status,
    required this.summary,
    required this.artifacts,
    required this.data,
  });

  factory HarnessExecutionStructuredResultRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return HarnessExecutionStructuredResultRecord(
      status: (json['status'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      artifacts: (json['artifacts'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      data: _parseStringMap(json['data']),
    );
  }

  final String status;
  final String summary;
  final List<String> artifacts;
  final Map<String, String> data;
}

class HarnessSessionExecutionStateRecord {
  HarnessSessionExecutionStateRecord({
    required this.status,
    required this.summary,
    required this.error,
    required this.pendingQuestion,
    required this.waitingReason,
    required this.workflowName,
    required this.finalResult,
    required this.blocker,
    required this.workflowState,
  });

  factory HarnessSessionExecutionStateRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    return HarnessSessionExecutionStateRecord(
      status: (json['status'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      error: (json['error'] as String? ?? '').trim(),
      pendingQuestion: (json['pending_question'] as String? ?? '').trim(),
      waitingReason: (json['waiting_reason'] as String? ?? '').trim(),
      workflowName: (json['workflow_name'] as String? ?? '').trim(),
      finalResult: (json['final_result'] as Map<String, dynamic>?) == null
          ? null
          : HarnessExecutionStructuredResultRecord.fromJson(
              json['final_result'] as Map<String, dynamic>,
            ),
      blocker: (json['blocker'] as Map<String, dynamic>?) == null
          ? null
          : HarnessExecutionBlockerRecord.fromJson(
              json['blocker'] as Map<String, dynamic>,
            ),
      workflowState: (json['workflow_state'] as Map<String, dynamic>?) == null
          ? null
          : HarnessWorkflowExecutionStateRecord.fromJson(
              json['workflow_state'] as Map<String, dynamic>,
            ),
    );
  }

  final String status;
  final String summary;
  final String error;
  final String pendingQuestion;
  final String waitingReason;
  final String workflowName;
  final HarnessExecutionStructuredResultRecord? finalResult;
  final HarnessExecutionBlockerRecord? blocker;
  final HarnessWorkflowExecutionStateRecord? workflowState;
}

class HarnessExecutionManifestRecord {
  HarnessExecutionManifestRecord({
    required this.sessionId,
    required this.command,
    required this.workingDirectory,
    required this.goalFile,
    required this.requestFile,
    required this.stdoutFile,
    required this.stderrFile,
    required this.sessionFile,
    required this.harnessStateFile,
    required this.status,
    required this.summary,
    required this.artifacts,
    required this.metadata,
  });

  factory HarnessExecutionManifestRecord.fromJson(Map<String, dynamic> json) {
    return HarnessExecutionManifestRecord(
      sessionId: (json['session_id'] as String? ?? '').trim(),
      command: (json['command'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      workingDirectory: (json['working_directory'] as String? ?? '').trim(),
      goalFile: (json['goal_file'] as String? ?? '').trim(),
      requestFile: (json['request_file'] as String? ?? '').trim(),
      stdoutFile: (json['stdout_file'] as String? ?? '').trim(),
      stderrFile: (json['stderr_file'] as String? ?? '').trim(),
      sessionFile: (json['session_file'] as String? ?? '').trim(),
      harnessStateFile: (json['harness_state_file'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? '').trim(),
      summary: (json['summary'] as String? ?? '').trim(),
      artifacts: (json['artifacts'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(),
      metadata: _parseStringMap(json['metadata']),
    );
  }

  final String sessionId;
  final List<String> command;
  final String workingDirectory;
  final String goalFile;
  final String requestFile;
  final String stdoutFile;
  final String stderrFile;
  final String sessionFile;
  final String harnessStateFile;
  final String status;
  final String summary;
  final List<String> artifacts;
  final Map<String, String> metadata;
}

class HarnessExecutionStateRecord {
  HarnessExecutionStateRecord({
    required this.runId,
    required this.runStatus,
    required this.runWaitReason,
    required this.resultSummary,
    required this.stateSource,
    required this.manifest,
    required this.session,
  });

  factory HarnessExecutionStateRecord.fromJson(Map<String, dynamic> json) {
    return HarnessExecutionStateRecord(
      runId: (json['run_id'] as String? ?? '').trim(),
      runStatus: (json['run_status'] as String? ?? '').trim(),
      runWaitReason: (json['run_wait_reason'] as String? ?? '').trim(),
      resultSummary: (json['result_summary'] as String? ?? '').trim(),
      stateSource: (json['state_source'] as String? ?? '').trim(),
      manifest: HarnessExecutionManifestRecord.fromJson(
        (json['manifest'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      session: (json['session'] as Map<String, dynamic>?) == null
          ? null
          : HarnessSessionExecutionStateRecord.fromJson(
              json['session'] as Map<String, dynamic>,
            ),
    );
  }

  final String runId;
  final String runStatus;
  final String runWaitReason;
  final String resultSummary;
  final String stateSource;
  final HarnessExecutionManifestRecord manifest;
  final HarnessSessionExecutionStateRecord? session;
}

class ArtifactRecord {
  ArtifactRecord({
    required this.artifactId,
    required this.tenantId,
    required this.agentId,
    required this.runId,
    required this.reference,
    required this.kind,
    required this.createdAt,
    required this.retentionDays,
  });

  factory ArtifactRecord.fromJson(Map<String, dynamic> json) {
    return ArtifactRecord(
      artifactId: (json['artifact_id'] as String? ?? '').trim(),
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      runId: (json['run_id'] as String? ?? '').trim(),
      reference: (json['reference'] as String? ?? '').trim(),
      kind: (json['kind'] as String? ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']),
      retentionDays: json['retention_days'] as int? ?? 0,
    );
  }

  final String artifactId;
  final String tenantId;
  final String agentId;
  final String runId;
  final String reference;
  final String kind;
  final DateTime? createdAt;
  final int retentionDays;
}

class AuditRecord {
  AuditRecord({
    required this.auditId,
    required this.tenantId,
    required this.agentId,
    required this.userId,
    required this.runId,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.metadata,
    required this.occurredAt,
    required this.administrative,
  });

  factory AuditRecord.fromJson(Map<String, dynamic> json) {
    return AuditRecord(
      auditId: (json['audit_id'] as String? ?? '').trim(),
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      userId: (json['user_id'] as String? ?? '').trim(),
      runId: (json['run_id'] as String? ?? '').trim(),
      action: (json['action'] as String? ?? '').trim(),
      resourceType: (json['resource_type'] as String? ?? '').trim(),
      resourceId: (json['resource_id'] as String? ?? '').trim(),
      metadata:
          ((json['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, String>(key, value.toString()),
              ),
      occurredAt: _parseDateTime(json['occurred_at']),
      administrative: json['administrative'] as bool? ?? false,
    );
  }

  final String auditId;
  final String tenantId;
  final String agentId;
  final String userId;
  final String runId;
  final String action;
  final String resourceType;
  final String resourceId;
  final Map<String, String> metadata;
  final DateTime? occurredAt;
  final bool administrative;
}

class ApprovalRecord {
  ApprovalRecord({
    required this.approvalRequestId,
    required this.runId,
    required this.approverId,
    required this.decision,
    required this.reason,
    required this.createdAt,
    required this.resolvedAt,
    required this.expiresAt,
  });

  factory ApprovalRecord.fromJson(Map<String, dynamic> json) {
    return ApprovalRecord(
      approvalRequestId: (json['approval_request_id'] as String? ?? '').trim(),
      runId: (json['run_id'] as String? ?? '').trim(),
      approverId: (json['approver_id'] as String? ?? '').trim(),
      decision: (json['decision'] as String? ?? '').trim(),
      reason: (json['reason'] as String? ?? '').trim(),
      createdAt: _parseDateTime(json['created_at']),
      resolvedAt: _parseDateTime(json['resolved_at']),
      expiresAt: _parseDateTime(json['expires_at']),
    );
  }

  final String approvalRequestId;
  final String runId;
  final String approverId;
  final String decision;
  final String reason;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final DateTime? expiresAt;
}

class MetricsSnapshot {
  MetricsSnapshot({
    required this.tenantId,
    required this.agentId,
    required this.runStatusCounts,
    required this.failedProvisionings,
    required this.secretRotations,
    required this.approvalLatencySecs,
    required this.runLatencySecs,
    required this.integrationErrors,
    required this.installations,
  });

  factory MetricsSnapshot.fromJson(Map<String, dynamic> json) {
    return MetricsSnapshot(
      tenantId: (json['tenant_id'] as String? ?? '').trim(),
      agentId: (json['agent_id'] as String? ?? '').trim(),
      runStatusCounts:
          ((json['run_status_counts'] as Map<String, dynamic>?) ??
                  <String, dynamic>{})
              .map(
                (String key, dynamic value) =>
                    MapEntry<String, int>(key, (value as num?)?.toInt() ?? 0),
              ),
      failedProvisionings: json['failed_provisionings'] as int? ?? 0,
      secretRotations: json['secret_rotations'] as int? ?? 0,
      approvalLatencySecs: (json['approval_latency_secs'] as num? ?? 0)
          .toDouble(),
      runLatencySecs: (json['run_latency_secs'] as num? ?? 0).toDouble(),
      integrationErrors: json['integration_errors'] as int? ?? 0,
      installations: json['installations'] as int? ?? 0,
    );
  }

  final String tenantId;
  final String agentId;
  final Map<String, int> runStatusCounts;
  final int failedProvisionings;
  final int secretRotations;
  final double approvalLatencySecs;
  final double runLatencySecs;
  final int integrationErrors;
  final int installations;
}

class RunQuery {
  const RunQuery({
    this.tenantId,
    this.agentId,
    this.actorId,
    this.status,
    this.invocationMode,
  });

  final String? tenantId;
  final String? agentId;
  final String? actorId;
  final String? status;
  final String? invocationMode;

  Map<String, String> toQueryParameters() {
    final query = <String, String>{};
    if (tenantId != null && tenantId!.trim().isNotEmpty) {
      query['tenant_id'] = tenantId!.trim();
    }
    if (agentId != null && agentId!.trim().isNotEmpty) {
      query['agent_id'] = agentId!.trim();
    }
    if (actorId != null && actorId!.trim().isNotEmpty) {
      query['actor_id'] = actorId!.trim();
    }
    if (status != null && status!.trim().isNotEmpty) {
      query['status'] = status!.trim();
    }
    if (invocationMode != null && invocationMode!.trim().isNotEmpty) {
      query['invocation_mode'] = invocationMode!.trim();
    }
    return query;
  }
}

class ApprovalQuery {
  const ApprovalQuery({this.tenantId, this.agentId, this.runId, this.decision});

  final String? tenantId;
  final String? agentId;
  final String? runId;
  final String? decision;

  Map<String, String> toQueryParameters() {
    final query = <String, String>{};
    if (tenantId != null && tenantId!.trim().isNotEmpty) {
      query['tenant_id'] = tenantId!.trim();
    }
    if (agentId != null && agentId!.trim().isNotEmpty) {
      query['agent_id'] = agentId!.trim();
    }
    if (runId != null && runId!.trim().isNotEmpty) {
      query['run_id'] = runId!.trim();
    }
    if (decision != null && decision!.trim().isNotEmpty) {
      query['decision'] = decision!.trim();
    }
    return query;
  }
}

abstract class OperationsApi {
  Future<List<RunRecord>> listRuns({RunQuery query = const RunQuery()});

  Future<RunRecord> getRun(String runId);

  Future<HarnessExecutionStateRecord> getRunHarnessExecutionState(String runId);

  Future<List<ApprovalRecord>> listApprovals({
    ApprovalQuery query = const ApprovalQuery(),
  });

  Future<ApprovalRecord> getApproval(String approvalRequestId);

  Future<ApprovalRecord> resolveApproval({
    required String approvalRequestId,
    required String approverId,
    required String decision,
    String reason = '',
  });

  Future<List<ArtifactRecord>> listArtifacts({String? tenantId, String? runId});

  Future<List<AuditRecord>> listAudits({String? tenantId, String? runId});

  Future<MetricsSnapshot> getMetrics({String? tenantId, String? agentId});
}

class HttpOperationsApi implements OperationsApi {
  HttpOperationsApi({
    required this.baseUrl,
    required this.adminToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory HttpOperationsApi.fromEnvironment() {
    return HttpOperationsApi(
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
  Future<RunRecord> getRun(String runId) async {
    final response = await _client.get(
      _uri('/v1/admin/runs/${Uri.encodeComponent(runId)}'),
      headers: _headers(),
    );
    final payload = await _decodeJsonMap(response);
    return RunRecord.fromJson(payload);
  }

  @override
  Future<HarnessExecutionStateRecord> getRunHarnessExecutionState(
    String runId,
  ) async {
    final response = await _client.get(
      _uri('/v1/admin/runs/${Uri.encodeComponent(runId)}/harness-state'),
      headers: _headers(),
    );
    final payload = await _decodeJsonMap(response);
    return HarnessExecutionStateRecord.fromJson(payload);
  }

  @override
  Future<ApprovalRecord> getApproval(String approvalRequestId) async {
    final response = await _client.get(
      _uri('/v1/admin/approvals/${Uri.encodeComponent(approvalRequestId)}'),
      headers: _headers(),
    );
    final payload = await _decodeJsonMap(response);
    return ApprovalRecord.fromJson(payload);
  }

  @override
  Future<MetricsSnapshot> getMetrics({
    String? tenantId,
    String? agentId,
  }) async {
    final query = <String, String>{};
    if (tenantId != null && tenantId.trim().isNotEmpty) {
      query['tenant_id'] = tenantId.trim();
    }
    if (agentId != null && agentId.trim().isNotEmpty) {
      query['agent_id'] = agentId.trim();
    }
    final response = await _client.get(
      _uri('/v1/admin/metrics', query),
      headers: _headers(),
    );
    final payload = await _decodeJsonMap(response);
    return MetricsSnapshot.fromJson(payload);
  }

  @override
  Future<List<ArtifactRecord>> listArtifacts({
    String? tenantId,
    String? runId,
  }) async {
    final query = <String, String>{};
    if (tenantId != null && tenantId.trim().isNotEmpty) {
      query['tenant_id'] = tenantId.trim();
    }
    if (runId != null && runId.trim().isNotEmpty) {
      query['run_id'] = runId.trim();
    }
    final response = await _client.get(
      _uri('/v1/admin/artifacts', query),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(ArtifactRecord.fromJson).toList();
  }

  @override
  Future<List<AuditRecord>> listAudits({
    String? tenantId,
    String? runId,
  }) async {
    final query = <String, String>{};
    if (tenantId != null && tenantId.trim().isNotEmpty) {
      query['tenant_id'] = tenantId.trim();
    }
    if (runId != null && runId.trim().isNotEmpty) {
      query['run_id'] = runId.trim();
    }
    final response = await _client.get(
      _uri('/v1/admin/audits', query),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(AuditRecord.fromJson).toList();
  }

  @override
  Future<List<RunRecord>> listRuns({RunQuery query = const RunQuery()}) async {
    final response = await _client.get(
      _uri('/v1/admin/runs', query.toQueryParameters()),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(RunRecord.fromJson).toList();
  }

  @override
  Future<List<ApprovalRecord>> listApprovals({
    ApprovalQuery query = const ApprovalQuery(),
  }) async {
    final response = await _client.get(
      _uri('/v1/admin/approvals', query.toQueryParameters()),
      headers: _headers(),
    );
    final payload = await _decodeJsonList(response);
    return payload.map(ApprovalRecord.fromJson).toList();
  }

  @override
  Future<ApprovalRecord> resolveApproval({
    required String approvalRequestId,
    required String approverId,
    required String decision,
    String reason = '',
  }) async {
    final response = await _client.post(
      _uri('/v1/admin/approvals/${Uri.encodeComponent(approvalRequestId)}'),
      headers: _jsonHeaders(),
      body: jsonEncode(<String, String>{
        'approver_id': approverId.trim(),
        'decision': decision.trim(),
        'reason': reason.trim(),
      }),
    );
    final payload = await _decodeJsonMap(response);
    return ApprovalRecord.fromJson(payload);
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

  Map<String, String> _jsonHeaders() {
    return <String, String>{..._headers(), 'Content-Type': 'application/json'};
  }

  Future<Map<String, dynamic>> _decodeJsonMap(http.Response response) async {
    final bodyText = utf8.decode(response.bodyBytes);
    final payload = bodyText.trim().isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(bodyText) as Map<String, dynamic>);
    if (response.statusCode >= 400) {
      throw OperationsApiException(
        payload['error'] as String? ??
            'Request failed with status ${response.statusCode}.',
      );
    }
    return payload;
  }

  Future<List<Map<String, dynamic>>> _decodeJsonList(
    http.Response response,
  ) async {
    final bodyText = utf8.decode(response.bodyBytes);
    final decoded = bodyText.trim().isEmpty
        ? <dynamic>[]
        : jsonDecode(bodyText);
    if (response.statusCode >= 400) {
      final errorPayload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      throw OperationsApiException(
        errorPayload['error'] as String? ??
            'Request failed with status ${response.statusCode}.',
      );
    }
    final payload = decoded is List<dynamic> ? decoded : <dynamic>[];
    return payload.whereType<Map<String, dynamic>>().toList();
  }
}

class OperationsApiException implements Exception {
  OperationsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

Map<String, String> _parseStringMap(dynamic value) {
  return ((value as Map<String, dynamic>?) ?? <String, dynamic>{}).map(
    (String key, dynamic entry) =>
        MapEntry<String, String>(key, entry?.toString() ?? ''),
  );
}

Map<String, int> _parseIntMap(dynamic value) {
  return ((value as Map<String, dynamic>?) ?? <String, dynamic>{}).map(
    (String key, dynamic entry) =>
        MapEntry<String, int>(key, (entry as num?)?.toInt() ?? 0),
  );
}
