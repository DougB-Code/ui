import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/control_plane_api.dart';
import 'package:ui/main.dart';
import 'package:ui/operations_api.dart';
import 'package:ui/provider_catalog_api.dart';

void main() {
  testWidgets('renders live-shell navigation and provider data', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));

    await tester.pumpWidget(
      AgentAwesomeBetaApp(
        controlPlaneBaseUrl: 'http://127.0.0.1:8080',
        controlPlaneApi: _FakeControlPlaneApi(),
        operationsApi: _FakeOperationsApi(),
        providerApi: _FakeProviderCatalogApi(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Runs'), findsWidgets);
    expect(find.text('Control Plane'), findsWidgets);
    expect(find.text('Providers'), findsWidgets);
    expect(find.text('Live API'), findsOneWidget);

    await tester.tap(find.text('Providers').first);
    await tester.pumpAndSettle();

    expect(find.text('openai-prod'), findsWidgets);
    expect(find.text('Provider editor'), findsOneWidget);

    await tester.tap(find.text('Runs').first);
    await tester.pumpAndSettle();

    expect(find.text('run-001'), findsWidgets);

    await tester.tap(find.text('Control Plane').first);
    await tester.pumpAndSettle();

    expect(find.text('Tenants'), findsWidgets);
    expect(find.text('Acme'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}

class _FakeOperationsApi implements OperationsApi {
  @override
  Future<RunRecord> getRun(String runId) async {
    return _run;
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
      ),
    ];
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
        allowedChannelIds: <String>['C-001'],
        allowedExternalUserIds: <String>['U-001'],
        allowedAgentIds: <String>['agent-001'],
      ),
    ];
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
        createdAt: DateTime(2026, 4, 14, 9, 0),
      ),
    ];
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
