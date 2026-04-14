import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/control_plane/control_plane_api.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/main.dart';
import 'package:ui/operations/operations_api.dart';
import 'package:ui/providers/provider_catalog_api.dart';

void main() {
  testWidgets('renders live-shell navigation and provider data', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));

    await tester.pumpWidget(
      AgentAwesomeBetaApp(
        controlPlaneBaseUrl: 'http://127.0.0.1:8080',
        controlPlaneApi: _FakeControlPlaneApi(),
        harnessConfigApi: _FakeHarnessConfigApi(),
        operationsApi: _FakeOperationsApi(),
        providerApi: _FakeProviderCatalogApi(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Summary'), findsWidgets);
    expect(find.text('Runs'), findsWidgets);
    expect(find.text('Approvals'), findsWidgets);
    expect(find.text('Artifacts'), findsWidgets);
    expect(find.text('Audits'), findsWidgets);
    expect(find.text('Control Plane'), findsWidgets);
    expect(find.text('Harness Agents'), findsWidgets);
    expect(find.text('Harness Tools'), findsWidgets);
    expect(find.text('Harness Workflows'), findsWidgets);
    expect(find.text('Providers'), findsWidgets);
    expect(find.text('Live API'), findsOneWidget);

    await tester.tap(find.text('Summary').first);
    await tester.pumpAndSettle();

    expect(find.text('Run status counts'), findsOneWidget);

    await tester.tap(find.text('Providers').first);
    await tester.pumpAndSettle();

    expect(find.text('openai-prod'), findsWidgets);
    expect(find.text('Provider editor'), findsOneWidget);

    await tester.tap(find.text('Harness Agents').first);
    await tester.pumpAndSettle();

    expect(find.text('Agent YAML'), findsOneWidget);
    expect(find.text('lead'), findsWidgets);

    await tester.tap(find.text('Harness Tools').first);
    await tester.pumpAndSettle();

    expect(find.text('Tool YAML'), findsOneWidget);
    expect(find.text('workspace_read_tools'), findsWidgets);

    await tester.tap(find.text('Harness Workflows').first);
    await tester.pumpAndSettle();

    expect(find.text('Workflow YAML'), findsOneWidget);
    expect(find.text('chat_turn'), findsWidgets);

    await tester.tap(find.text('Runs').first);
    await tester.pumpAndSettle();

    expect(find.text('run-001'), findsWidgets);

    await tester.tap(find.text('Control Plane').first);
    await tester.pumpAndSettle();

    expect(find.text('Tenants'), findsWidgets);
    expect(find.text('Acme'), findsWidgets);
    expect(find.text('Tenant detail'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'provider preview is backend-owned and verify uses persisted alias',
    (WidgetTester tester) async {
      final providerApi = _FakeProviderCatalogApi();

      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      await tester.pumpWidget(
        AgentAwesomeBetaApp(
          controlPlaneBaseUrl: 'http://127.0.0.1:8080',
          controlPlaneApi: _FakeControlPlaneApi(),
          harnessConfigApi: _FakeHarnessConfigApi(),
          operationsApi: _FakeOperationsApi(),
          providerApi: providerApi,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Providers').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('api_key_env: OPENAI_API_KEY'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('provider-alias-openai-prod-false')),
        'renamed-prod',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(providerApi.lastPreviewAlias, 'renamed-prod');
      expect(find.textContaining('alias: renamed-prod'), findsOneWidget);
      expect(
        find.textContaining('api_key_env: OPENAI_API_KEY'),
        findsOneWidget,
      );

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(providerApi.lastVerifiedAlias, 'openai-prod');

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('control-plane detail panes load backend-owned detail DTOs', (
    WidgetTester tester,
  ) async {
    final controlPlaneApi = _FakeControlPlaneApi();

    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    await tester.pumpWidget(
      AgentAwesomeBetaApp(
        controlPlaneBaseUrl: 'http://127.0.0.1:8080',
        controlPlaneApi: controlPlaneApi,
        harnessConfigApi: _FakeHarnessConfigApi(),
        operationsApi: _FakeOperationsApi(),
        providerApi: _FakeProviderCatalogApi(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Control Plane').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('slack:T-001').first);
    await tester.pumpAndSettle();
    expect(controlPlaneApi.installationDetailRequests, contains('inst-001'));
    expect(find.textContaining('Linked routes: 3'), findsOneWidget);
    expect(
      find.textContaining('Mapped agent onboarding: waiting_for_credentials'),
      findsOneWidget,
    );

    await tester.tap(find.text('Inbox triage').first);
    await tester.pumpAndSettle();
    expect(controlPlaneApi.conversationDetailRequests, contains('conv-001'));
    expect(find.textContaining('Latest approval: apr-001'), findsOneWidget);
    expect(find.textContaining('Inactive installations: 1'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}

class _FakeHarnessConfigApi implements HarnessConfigApi {
  @override
  Future<HarnessAgentCatalog> getAgents() async {
    return HarnessAgentCatalog(
      configPath: '/tmp/agent.yaml',
      yaml: 'agent:\n  lead_agent: lead\n',
      leadAgent: 'lead',
      approvalMode: 'auto',
      defaultMaxSteps: 10,
      recentLedgerLimit: 20,
      memoryRetentionDays: 30,
      subagentsEnabled: true,
      subagentDefaultMaxSteps: 8,
      policyPresets: <String>['workspace_safe_write'],
      roleTemplates: <HarnessAgentTemplateSummary>[
        HarnessAgentTemplateSummary(
          name: 'general_autonomous',
          role: 'lead',
          policyPreset: 'workspace_safe_write',
          maxSteps: 10,
          allowedToolGroups: <String>['workspace_read_tools'],
        ),
      ],
      agents: <HarnessAgentSummary>[
        HarnessAgentSummary(
          name: 'lead',
          template: 'general_autonomous',
          role: 'lead',
          model: 'openai-prod/gpt-5.4',
          maxSteps: 10,
          toolGroups: <String>['workspace_read_tools'],
          allowedTools: <String>[],
          policyPreset: '',
        ),
      ],
    );
  }

  @override
  Future<HarnessToolCatalog> getTools() async {
    return HarnessToolCatalog(
      configPath: '/tmp/tool.yaml',
      yaml: 'tools:\n  tool_groups: []\n',
      toolGroups: <HarnessToolGroupSummary>[
        HarnessToolGroupSummary(
          name: 'workspace_read_tools',
          tools: <String>['ls', 'cat'],
        ),
      ],
      externalTools: <HarnessExternalToolSummary>[
        HarnessExternalToolSummary(
          name: 'patch',
          enabled: true,
          trusted: true,
          toolClass: 'write',
          location: 'filesystem',
          command: <String>['patch'],
          platformOverrideCount: 0,
        ),
      ],
      mcpServers: <HarnessMcpServerSummary>[
        HarnessMcpServerSummary(
          name: 'github',
          enabled: true,
          trusted: true,
          lifecycle: 'persistent',
          transport: 'stdio',
          url: '',
          command: <String>['github-mcp'],
          toolNamePrefix: 'github',
          platformOverrideCount: 0,
        ),
      ],
    );
  }

  @override
  Future<HarnessAgentCatalog> saveAgents(String yaml) async {
    final catalog = await getAgents();
    return HarnessAgentCatalog(
      configPath: catalog.configPath,
      yaml: yaml,
      leadAgent: catalog.leadAgent,
      approvalMode: catalog.approvalMode,
      defaultMaxSteps: catalog.defaultMaxSteps,
      recentLedgerLimit: catalog.recentLedgerLimit,
      memoryRetentionDays: catalog.memoryRetentionDays,
      subagentsEnabled: catalog.subagentsEnabled,
      subagentDefaultMaxSteps: catalog.subagentDefaultMaxSteps,
      policyPresets: catalog.policyPresets,
      roleTemplates: catalog.roleTemplates,
      agents: catalog.agents,
    );
  }

  @override
  Future<HarnessToolCatalog> saveTools(String yaml) async {
    final catalog = await getTools();
    return HarnessToolCatalog(
      configPath: catalog.configPath,
      yaml: yaml,
      toolGroups: catalog.toolGroups,
      externalTools: catalog.externalTools,
      mcpServers: catalog.mcpServers,
    );
  }

  @override
  Future<HarnessWorkflowCatalog> getWorkflows() async {
    return HarnessWorkflowCatalog(
      configPath: '/tmp/workflow.yaml',
      yaml: 'workflows:\n  - name: chat_turn\n',
      workflows: <HarnessWorkflowSummary>[
        HarnessWorkflowSummary(
          name: 'chat_turn',
          startNode: 'reply',
          maxVisitsPerNode: 2,
          maxTotalTransitions: 6,
          duplicateResultCap: 1,
          ruleSets: <HarnessWorkflowRuleSetSummary>[],
          nodes: <HarnessWorkflowNodeSummary>[
            HarnessWorkflowNodeSummary(
              id: 'reply',
              kind: 'task',
              uses: 'chat_responder',
              withKeys: <String>['expected_output'],
              requiredInputKeys: <String>[],
              optionalInputKeys: <String>[],
              requiredDataKeys: <String>[],
              producesGateDecision: false,
              transitions: HarnessWorkflowTransitionsSummary(
                success: 'finish',
                failure: 'finish',
                blocked: '',
              ),
              maxVisits: 0,
              maxFailures: 0,
              implementation: false,
              requiresGates: <String>[],
              includeNodeResults: <String>[],
              inputMappings: <HarnessWorkflowInputMapSummary>[],
              promptInstructionCount: 2,
              gatePassStatuses: <String>[],
              gateFailStatuses: <String>[],
              gatePassExitCodes: <int>[],
              gateFailExitCodes: <int>[],
              treatRetryableAsFail: false,
              policyGateEnabled: false,
              policyGateRuleSet: '',
              policyGateFactBindings: <String>[],
              policyGateRouteHints: <String>[],
              policyGateOnEvalError: '',
              policyGateMergeFindings: '',
              policyGateOverrideStatus: false,
              requiredChangedFiles: <String>[],
              requiredToolCalls: <String>[],
            ),
            HarnessWorkflowNodeSummary(
              id: 'finish',
              kind: 'finish',
              uses: '',
              withKeys: <String>['summary'],
              requiredInputKeys: <String>[],
              optionalInputKeys: <String>[],
              requiredDataKeys: <String>[],
              producesGateDecision: false,
              transitions: HarnessWorkflowTransitionsSummary(
                success: '',
                failure: '',
                blocked: '',
              ),
              maxVisits: 0,
              maxFailures: 0,
              implementation: false,
              requiresGates: <String>[],
              includeNodeResults: <String>[],
              inputMappings: <HarnessWorkflowInputMapSummary>[],
              promptInstructionCount: 0,
              gatePassStatuses: <String>[],
              gateFailStatuses: <String>[],
              gatePassExitCodes: <int>[],
              gateFailExitCodes: <int>[],
              treatRetryableAsFail: false,
              policyGateEnabled: false,
              policyGateRuleSet: '',
              policyGateFactBindings: <String>[],
              policyGateRouteHints: <String>[],
              policyGateOnEvalError: '',
              policyGateMergeFindings: '',
              policyGateOverrideStatus: false,
              requiredChangedFiles: <String>[],
              requiredToolCalls: <String>[],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<HarnessWorkflowCatalog> saveWorkflows(String yaml) async {
    final catalog = await getWorkflows();
    return HarnessWorkflowCatalog(
      configPath: catalog.configPath,
      yaml: yaml,
      workflows: catalog.workflows,
    );
  }

  @override
  Future<HarnessConfigValidationReport> validateAgents(String yaml) async {
    return HarnessConfigValidationReport(
      target: 'agents',
      status: 'ok',
      summary: 'provider and agent configuration is valid',
      providerCount: 1,
      enabledProviderCount: 1,
      enabledModelCount: 1,
      probedProviderCount: 0,
      probedModelCount: 0,
      validatedModels: <String>[],
      failedModels: <String>[],
      probeErrors: <String, String>{},
      agentCount: 1,
      leadAgent: 'lead',
      workflowCount: 0,
      externalToolCount: 0,
      enabledExternalToolCount: 0,
      mcpServerCount: 0,
      enabledMcpServerCount: 0,
      toolPlatform: '',
      availableExternalTools: <String>[],
      unavailableExternalTools: <String>[],
      externalToolErrors: <String, String>{},
      availableMcpServers: <String>[],
      unavailableMcpServers: <String>[],
      mcpServerErrors: <String, String>{},
    );
  }

  @override
  Future<HarnessConfigValidationReport> validateTools(String yaml) async {
    return HarnessConfigValidationReport(
      target: 'tools',
      status: 'ok',
      summary: 'tool configuration is valid',
      providerCount: 0,
      enabledProviderCount: 0,
      enabledModelCount: 0,
      probedProviderCount: 0,
      probedModelCount: 0,
      validatedModels: <String>[],
      failedModels: <String>[],
      probeErrors: <String, String>{},
      agentCount: 0,
      leadAgent: '',
      workflowCount: 0,
      externalToolCount: 1,
      enabledExternalToolCount: 1,
      mcpServerCount: 1,
      enabledMcpServerCount: 1,
      toolPlatform: 'linux',
      availableExternalTools: <String>['patch'],
      unavailableExternalTools: <String>[],
      externalToolErrors: <String, String>{},
      availableMcpServers: <String>['github'],
      unavailableMcpServers: <String>[],
      mcpServerErrors: <String, String>{},
    );
  }

  @override
  Future<HarnessConfigValidationReport> validateWorkflows(String yaml) async {
    return HarnessConfigValidationReport(
      target: 'workflows',
      status: 'ok',
      summary: 'provider, agent, and workflow configuration is valid',
      providerCount: 1,
      enabledProviderCount: 1,
      enabledModelCount: 1,
      probedProviderCount: 0,
      probedModelCount: 0,
      validatedModels: <String>[],
      failedModels: <String>[],
      probeErrors: <String, String>{},
      agentCount: 1,
      leadAgent: 'lead',
      workflowCount: 1,
      externalToolCount: 0,
      enabledExternalToolCount: 0,
      mcpServerCount: 0,
      enabledMcpServerCount: 0,
      toolPlatform: '',
      availableExternalTools: <String>[],
      unavailableExternalTools: <String>[],
      externalToolErrors: <String, String>{},
      availableMcpServers: <String>[],
      unavailableMcpServers: <String>[],
      mcpServerErrors: <String, String>{},
    );
  }
}

class _FakeOperationsApi implements OperationsApi {
  @override
  Future<RunRecord> getRun(String runId) async {
    return _run;
  }

  @override
  Future<HarnessExecutionStateRecord> getRunHarnessExecutionState(
    String runId,
  ) async {
    return HarnessExecutionStateRecord(
      runId: runId,
      runStatus: 'blocked',
      runWaitReason: 'waiting_for_user',
      resultSummary: 'Need one more answer',
      stateSource: 'session_file',
      manifest: HarnessExecutionManifestRecord(
        sessionId: runId,
        command: <String>['agent-awesome', '--task', 'triage inbox'],
        workingDirectory: '/tmp/workspace',
        goalFile: '/tmp/run/goal.txt',
        requestFile: '/tmp/run/request.json',
        stdoutFile: '/tmp/run/stdout.json',
        stderrFile: '/tmp/run/stderr.log',
        sessionFile: '/tmp/run/session.json',
        harnessStateFile: '/tmp/state/sessions/$runId.json',
        status: 'blocked',
        summary: 'waiting on a failing node',
        artifacts: <String>['reply-2.json'],
        metadata: <String, String>{
          'requested_workflow': 'chat_turn',
          'workspace_root': '/tmp/workspace',
        },
      ),
      session: HarnessSessionExecutionStateRecord(
        status: 'blocked',
        summary: 'waiting on a failing node',
        error: '',
        pendingQuestion: 'Which inbox should I process?',
        waitingReason: 'waiting_for_user',
        workflowName: 'chat_turn',
        finalResult: null,
        blocker: HarnessExecutionBlockerRecord(
          code: 'unresolved_node_failure',
          nodeId: 'reply',
          summary: 'workflow cannot complete because reply is still failing',
          retryable: true,
        ),
        workflowState: HarnessWorkflowExecutionStateRecord(
          currentNodeId: 'reply',
          artifactDir: '/tmp/artifacts',
          waitingReason: 'waiting_for_user',
          transitionCount: 3,
          nodeVisitCounts: <String, int>{'reply': 2},
          nodeFailureCounts: <String, int>{'reply': 1},
          blocker: HarnessExecutionBlockerRecord(
            code: 'unresolved_node_failure',
            nodeId: 'reply',
            summary: 'workflow cannot complete because reply is still failing',
            retryable: true,
          ),
          nodeResults: <HarnessExecutionNodeResultRecord>[
            HarnessExecutionNodeResultRecord(
              nodeId: 'reply',
              outcome: 'failure',
              gateStatus: 'fail',
              summary: 'provider request failed',
              errorCode: 'embedded_run_failed',
              retryable: true,
              artifacts: <String>['reply-2.json'],
              metadata: <String, String>{'provider': 'openai-prod'},
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<MetricsSnapshot> getMetrics({
    String? tenantId,
    String? agentId,
  }) async {
    return MetricsSnapshot(
      tenantId: '',
      agentId: '',
      runStatusCounts: <String, int>{'completed': 1, 'running': 1},
      failedProvisionings: 0,
      secretRotations: 0,
      approvalLatencySecs: 4,
      runLatencySecs: 9,
      integrationErrors: 0,
      installations: 1,
    );
  }

  @override
  Future<ApprovalRecord> getApproval(String approvalRequestId) async {
    return _approval;
  }

  @override
  Future<List<ArtifactRecord>> listArtifacts({
    String? tenantId,
    String? runId,
  }) async {
    return <ArtifactRecord>[
      ArtifactRecord(
        artifactId: 'art-001',
        tenantId: 'tenant-001',
        agentId: 'agent-001',
        runId: 'run-001',
        reference: 'artifact://run-001',
        kind: 'manifest',
        createdAt: DateTime(2026, 4, 14, 10, 5),
        retentionDays: 30,
      ),
    ];
  }

  @override
  Future<List<AuditRecord>> listAudits({
    String? tenantId,
    String? runId,
  }) async {
    return <AuditRecord>[
      AuditRecord(
        auditId: 'aud-001',
        tenantId: 'tenant-001',
        agentId: 'agent-001',
        userId: 'user-001',
        runId: 'run-001',
        action: 'run.completed',
        resourceType: 'run',
        resourceId: 'run-001',
        metadata: <String, String>{},
        occurredAt: DateTime(2026, 4, 14, 10, 7),
        administrative: true,
      ),
    ];
  }

  @override
  Future<List<ApprovalRecord>> listApprovals({
    ApprovalQuery query = const ApprovalQuery(),
  }) async {
    return <ApprovalRecord>[_approval];
  }

  @override
  Future<List<RunRecord>> listRuns({RunQuery query = const RunQuery()}) async {
    return <RunRecord>[_run];
  }

  @override
  Future<ApprovalRecord> resolveApproval({
    required String approvalRequestId,
    required String approverId,
    required String decision,
    String reason = '',
  }) async {
    return ApprovalRecord(
      approvalRequestId: approvalRequestId,
      runId: _run.runId,
      approverId: approverId,
      decision: decision,
      reason: reason,
      createdAt: _approval.createdAt,
      resolvedAt: DateTime(2026, 4, 14, 10, 8),
      expiresAt: _approval.expiresAt,
    );
  }
}

class _FakeControlPlaneApi implements ControlPlaneApi {
  final List<String> conversationDetailRequests = <String>[];
  final List<String> installationDetailRequests = <String>[];

  @override
  Future<List<AgentRecord>> listAgents({String? tenantId}) async {
    return <AgentRecord>[
      AgentRecord(
        agentId: 'agent-001',
        tenantId: 'tenant-001',
        name: 'Default Agent',
        status: 'active',
        templateId: 'tpl-default',
        enabledCapabilities: <String>['filesystem_read'],
        deniedCapabilities: <String>[],
        integrationBindings: <String>['slack'],
        onboardingState: '',
        approvalOverrideMode: '',
        runtimeOverrideMaxRunSeconds: 0,
        runtimeOverrideMaxTurns: 0,
      ),
    ];
  }

  @override
  Future<AgentRecord> disableAgent({
    required String agentId,
    required String actorId,
    String reason = '',
  }) async {
    return (await listAgents()).first;
  }

  @override
  Future<List<ChannelRouteRecord>> listChannelRoutes({
    String? tenantId,
    String? agentId,
    String? installationId,
  }) async {
    return <ChannelRouteRecord>[
      ChannelRouteRecord(
        routeId: 'route-001',
        tenantId: 'tenant-001',
        conversationId: 'conv-001',
        agentId: 'agent-001',
        providerType: 'slack',
        installationId: 'inst-001',
        externalWorkspaceId: 'T-001',
        channelId: 'C-001',
        threadId: 'thread-001',
        status: 'active',
        createdAt: DateTime(2026, 4, 14, 10, 0),
      ),
    ];
  }

  @override
  Future<List<ConversationRecord>> listConversations({
    String? tenantId,
    String? agentId,
  }) async {
    return <ConversationRecord>[
      ConversationRecord(
        conversationId: 'conv-001',
        tenantId: 'tenant-001',
        agentId: 'agent-001',
        name: 'Inbox triage',
        kind: 'channel_route',
        status: 'active',
        createdBy: 'user-001',
        createdAt: DateTime(2026, 4, 14, 10, 0),
      ),
    ];
  }

  @override
  Future<ConversationDetailRecord> getConversationDetail(
    String conversationId,
  ) async {
    conversationDetailRequests.add(conversationId);
    return ConversationDetailRecord(
      conversation: ConversationRecord(
        conversationId: conversationId,
        tenantId: 'tenant-001',
        agentId: 'agent-001',
        name: 'Inbox triage',
        kind: 'channel_route',
        status: 'active',
        createdBy: 'user-001',
        createdAt: DateTime(2026, 4, 14, 10, 0),
      ),
      state: ConversationStateRecord(
        conversationKey: 'tenant:tenant-001:conversation:$conversationId',
        tenantId: 'tenant-001',
        conversationId: conversationId,
        agentId: 'agent-001',
        providerType: 'slack',
        installationId: 'inst-001',
        externalWorkspaceId: 'T-001',
        channelId: 'C-001',
        threadId: 'thread-001',
        historySummary: '',
        turns: <ConversationTurnItem>[
          ConversationTurnItem(
            turnId: 'turn-001',
            role: 'user',
            content: 'Can you triage my inbox?',
            actorId: 'user-001',
            requestId: 'req-001',
            runId: 'run-001',
            createdAt: DateTime(2026, 4, 14, 10, 0),
          ),
        ],
        pending: PendingConversationExecutionRecord(
          runId: 'run-001',
          status: 'waiting_approval',
          waitReason: 'approval required',
          pendingQuestion: '',
          approvalRequestId: 'apr-001',
          resumeSessionId: '',
          checkpointReference: '',
          updatedAt: DateTime(2026, 4, 14, 10, 2),
        ),
        latestRunId: 'run-001',
        latestApprovalRequestId: 'apr-001',
        updatedAt: DateTime(2026, 4, 14, 10, 2),
      ),
      latestRun: _run,
      latestApproval: _approval,
      routeHealth: ConversationRouteHealthRecord(
        routeCount: 2,
        unhealthyRouteCount: 1,
        installationCount: 2,
        inactiveInstallationCount: 1,
      ),
    );
  }

  @override
  Future<ConversationStateRecord> getConversationState(String conversationId) {
    throw UnimplementedError('Conversation detail endpoint is used instead.');
  }

  @override
  Future<List<InstallationRecord>> listInstallations({String? tenantId}) async {
    return <InstallationRecord>[
      InstallationRecord(
        installationId: 'inst-001',
        providerType: 'slack',
        externalWorkspaceId: 'T-001',
        mappedTenantId: 'tenant-001',
        mappedDefaultAgentId: 'agent-001',
        status: 'active',
        installedBy: 'user-001',
        installedAt: DateTime(2026, 4, 14, 9, 0),
        lastVerifiedAt: DateTime(2026, 4, 14, 9, 30),
        allowedChannelIds: <String>['C-001'],
        allowedExternalUserIds: <String>['U-001'],
        allowedAgentIds: <String>['agent-001'],
        adapterVersion: 1,
      ),
    ];
  }

  @override
  Future<InstallationDetailRecord> getInstallationDetail(
    String installationId,
  ) async {
    installationDetailRequests.add(installationId);
    return InstallationDetailRecord(
      installation: InstallationRecord(
        installationId: installationId,
        providerType: 'slack',
        externalWorkspaceId: 'T-001',
        mappedTenantId: 'tenant-001',
        mappedDefaultAgentId: 'agent-001',
        status: 'inactive',
        installedBy: 'user-001',
        installedAt: DateTime(2026, 4, 14, 9, 0),
        lastVerifiedAt: DateTime(2026, 4, 14, 9, 30),
        allowedChannelIds: <String>['C-001'],
        allowedExternalUserIds: <String>['U-001'],
        allowedAgentIds: <String>['agent-001'],
        adapterVersion: 1,
      ),
      mappedAgent: AgentRecord(
        agentId: 'agent-001',
        tenantId: 'tenant-001',
        name: 'Default Agent',
        status: 'active',
        templateId: 'tpl-default',
        enabledCapabilities: <String>['filesystem_read'],
        deniedCapabilities: <String>[],
        integrationBindings: <String>['slack'],
        onboardingState: 'waiting_for_credentials',
        approvalOverrideMode: '',
        runtimeOverrideMaxRunSeconds: 0,
        runtimeOverrideMaxTurns: 0,
      ),
      routeHealth: InstallationRouteHealthRecord(
        linkedRouteCount: 3,
        unhealthyRouteCount: 1,
        mappedAgentOnboarding: 'waiting_for_credentials',
      ),
    );
  }

  @override
  Future<InstallationRecord> updateInstallationAccess({
    required String installationId,
    required String actorId,
    required List<String> allowedChannelIds,
    required List<String> allowedExternalUserIds,
    required List<String> allowedAgentIds,
  }) async {
    return InstallationRecord(
      installationId: installationId,
      providerType: 'slack',
      externalWorkspaceId: 'T-001',
      mappedTenantId: 'tenant-001',
      mappedDefaultAgentId: 'agent-001',
      status: 'active',
      installedBy: actorId,
      installedAt: DateTime(2026, 4, 14, 9, 0),
      lastVerifiedAt: DateTime(2026, 4, 14, 9, 30),
      allowedChannelIds: allowedChannelIds,
      allowedExternalUserIds: allowedExternalUserIds,
      allowedAgentIds: allowedAgentIds,
      adapterVersion: 1,
    );
  }

  @override
  Future<List<MembershipRecord>> listMemberships({
    String? tenantId,
    String? userId,
  }) async {
    return <MembershipRecord>[
      MembershipRecord(
        tenantId: 'tenant-001',
        userId: 'user-001',
        role: 'owner',
        createdAt: DateTime(2026, 4, 14, 9, 0),
      ),
    ];
  }

  @override
  Future<List<TenantRecord>> listTenants() async {
    return <TenantRecord>[
      TenantRecord(
        tenantId: 'tenant-001',
        displayName: 'Acme',
        type: 'small_team',
        ownerUserId: 'user-001',
        status: 'active',
        region: 'ca-central-1',
        defaultAgentTemplate: 'tpl-default',
        enabledIntegrations: <String>['slack'],
        onboardingState: 'active',
        runHistoryDays: 14,
        artifactDays: 30,
        auditLogDays: 90,
        maxRunsPerDay: 50,
        defaultApprovalMode: 'auto_approve',
        maxRunSeconds: 300,
        maxTurns: 20,
        createdAt: DateTime(2026, 4, 14, 9, 0),
      ),
    ];
  }

  @override
  Future<TenantRecord> disableTenant({
    required String tenantId,
    required String actorId,
    String reason = '',
  }) async {
    return TenantRecord(
      tenantId: tenantId,
      displayName: 'Acme',
      type: 'small_team',
      ownerUserId: actorId,
      status: 'disabled',
      region: 'ca-central-1',
      defaultAgentTemplate: 'tpl-default',
      enabledIntegrations: <String>['slack'],
      onboardingState: 'disabled',
      runHistoryDays: 14,
      artifactDays: 30,
      auditLogDays: 90,
      maxRunsPerDay: 50,
      defaultApprovalMode: 'auto_approve',
      maxRunSeconds: 300,
      maxTurns: 20,
      createdAt: DateTime(2026, 4, 14, 9, 0),
    );
  }

  @override
  Future<List<UserRecord>> listUsers() async {
    return <UserRecord>[
      UserRecord(
        userId: 'user-001',
        displayName: 'Owner',
        kind: 'human',
        status: 'active',
      ),
    ];
  }
}

class _FakeProviderCatalogApi implements ProviderCatalogApi {
  String? lastPreviewAlias;
  String? lastVerifiedAlias;

  @override
  Future<ProviderMutationResult> createProvider(ProviderConfig provider) async {
    return ProviderMutationResult(
      catalog: ProviderCatalog(
        defaultProvider: provider.alias,
        configPath: '/tmp/provider.yaml',
        providers: <ProviderConfig>[provider],
      ),
      provider: provider,
    );
  }

  @override
  Future<ProviderCatalog> deleteProvider(String alias) async {
    return ProviderCatalog(
      defaultProvider: '',
      configPath: '/tmp/provider.yaml',
      providers: <ProviderConfig>[],
    );
  }

  @override
  Future<ProviderCatalog> listProviders() async {
    return ProviderCatalog(
      defaultProvider: 'openai-prod',
      configPath: '/tmp/provider.yaml',
      providers: <ProviderConfig>[
        ProviderConfig(
          alias: 'openai-prod',
          persistedAlias: 'openai-prod',
          adapter: 'openai',
          enabled: true,
          isDefault: true,
          endpoint: 'https://api.openai.com/v1',
          apiKeyEnv: 'OPENAI_API_KEY',
          accountId: '',
          gatewayId: '',
          apiVersion: '',
          timeoutSecs: 30,
          accessVerified: true,
          allowedHosts: <String>[],
          local: false,
          models: <ProviderModelConfig>[
            ProviderModelConfig(
              name: 'gpt-5.4',
              enabled: true,
              accessVerified: true,
            ),
          ],
          verificationSummary: 'Verified.',
        ),
      ],
    );
  }

  @override
  Future<ProviderMutationResult> updateProvider(
    String currentAlias,
    ProviderConfig provider,
  ) async {
    return ProviderMutationResult(
      catalog: ProviderCatalog(
        defaultProvider: provider.isDefault ? provider.alias : '',
        configPath: '/tmp/provider.yaml',
        providers: <ProviderConfig>[provider],
      ),
      provider: provider,
    );
  }

  @override
  Future<ProviderVerificationReport> verifyProvider(String alias) async {
    lastVerifiedAlias = alias;
    return ProviderVerificationReport(
      alias: alias,
      status: 'ok',
      summary: 'Verified.',
      probedProviderCount: 1,
      probedModelCount: 1,
      validatedModels: <String>['$alias/gpt-5.4'],
      failedModels: <String>[],
      probeErrors: <String, String>{},
    );
  }

  @override
  Future<ProviderPreviewResult> previewProvider(ProviderConfig provider) async {
    lastPreviewAlias = provider.alias;
    return ProviderPreviewResult(
      provider: provider,
      yamlPreview:
          'provider:\n  alias: ${provider.alias}\n  adapter: ${provider.adapter}\n  api_key_env: ${provider.apiKeyEnv}',
      validationStatus: 'ok',
      validationSummary: 'Preview generated from backend response.',
    );
  }
}

final RunRecord _run = RunRecord(
  runId: 'run-001',
  tenantId: 'tenant-001',
  agentId: 'agent-001',
  actorId: 'user-001',
  source: SourceContext(
    interface: 'admin',
    installationId: '',
    externalWorkspaceId: '',
    conversationId: '',
    channelId: '',
    threadId: '',
    requestId: '',
  ),
  invocationMode: 'direct_task',
  requestedAutonomyMode: '',
  effectiveRuntimeProfileId: 'profile-001',
  effectiveRuntimeProfileVersion: 1,
  status: 'completed',
  waitReason: '',
  createdAt: DateTime(2026, 4, 14, 10, 0),
  startedAt: DateTime(2026, 4, 14, 10, 1),
  completedAt: DateTime(2026, 4, 14, 10, 7),
  artifactManifestReference: 'artifact://run-001',
  resultSummary: 'Completed run',
  operatorActions: <OperatorActionRecord>[],
  profileSnapshot: RuntimeProfileSnapshot(
    profileId: 'profile-001',
    version: 1,
    tenantId: 'tenant-001',
    agentId: 'agent-001',
    model: '',
    provider: '',
    allowedCapabilities: <String>['filesystem_read'],
    deniedCapabilities: <String>[],
    approvalPolicy: ApprovalPolicySnapshot(
      mode: 'auto_approve',
      requiredRole: '',
      expiresAfterSec: 0,
    ),
    writeScope: <String>[],
    storageScope: StorageScopeSnapshot(
      namespace: 'tenant-001',
      artifactPrefix: 'artifacts/tenant-001',
      allowedReadPrefixes: <String>[],
      allowedWritePrefixes: <String>[],
      retentionDays: 30,
    ),
    secretBindings: <SecretBindingRefSnapshot>[],
    integrationPermissions: <String>[],
    runtimeLimits: RuntimeLimitsSnapshot(maxRunSeconds: 300, maxTurns: 20),
    observabilityTags: <String, String>{},
    sourceLayers: <String>[],
    resolvedAt: DateTime(2026, 4, 14, 10, 0),
  ),
);

final ApprovalRecord _approval = ApprovalRecord(
  approvalRequestId: 'apr-001',
  runId: 'run-001',
  approverId: '',
  decision: 'pending',
  reason: '',
  createdAt: DateTime(2026, 4, 14, 10, 2),
  resolvedAt: null,
  expiresAt: DateTime(2026, 4, 14, 10, 12),
);
