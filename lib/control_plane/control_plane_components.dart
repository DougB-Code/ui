import 'package:flutter/material.dart';
import 'package:ui/control_plane/control_plane_api.dart';
import 'package:ui/shared/ui.dart';

class ControlPlaneOverviewMetrics extends StatelessWidget {
  const ControlPlaneOverviewMetrics({
    super.key,
    required this.tenants,
    required this.users,
    required this.agents,
    required this.installations,
    required this.conversations,
    required this.routes,
  });

  final List<TenantRecord> tenants;
  final List<UserRecord> users;
  final List<AgentRecord> agents;
  final List<InstallationRecord> installations;
  final List<ConversationRecord> conversations;
  final List<ChannelRouteRecord> routes;

  @override
  Widget build(BuildContext context) {
    final unhealthyRouteCount = routes
        .where((ChannelRouteRecord route) => route.status != 'active')
        .length;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        MetricCard(
          label: 'Tenants',
          value: '${tenants.length}',
          tone: accentColor,
          detail: 'Provisioned workspaces',
        ),
        MetricCard(
          label: 'Users',
          value: '${users.length}',
          tone: infoColor,
          detail: 'Known identities',
        ),
        MetricCard(
          label: 'Agents',
          value: '${agents.length}',
          tone: successColor,
          detail: 'Control-plane agents',
        ),
        MetricCard(
          label: 'Installations',
          value: '${installations.length}',
          tone: warningColor,
          detail: 'Mapped integrations',
        ),
        MetricCard(
          label: 'Conversations',
          value: '${conversations.length}',
          tone: infoColor,
          detail: 'Conversation records',
        ),
        MetricCard(
          label: 'Unhealthy routes',
          value: '$unhealthyRouteCount',
          tone: unhealthyRouteCount > 0 ? dangerColor : successColor,
          detail: 'Non-active channel mappings',
        ),
      ],
    );
  }
}

class ControlPlaneTwoPanelRow extends StatelessWidget {
  const ControlPlaneTwoPanelRow({
    super.key,
    required this.left,
    required this.right,
  });

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 1100) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class ControlPlaneEntityItem {
  const ControlPlaneEntityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final List<String> tags;
}

class ControlPlaneEntityPanel extends StatelessWidget {
  const ControlPlaneEntityPanel({
    super.key,
    required this.title,
    required this.items,
    this.selectedId,
    this.onSelect,
  });

  final String title;
  final List<ControlPlaneEntityItem> items;
  final String? selectedId;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: '$title (${items.length})',
      child: items.isEmpty
          ? const EmptyState(
              title: 'No records',
              body:
                  'No live records were returned for this control-plane view.',
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Scrollbar(
                thumbVisibility: items.length > 5,
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final item = items[index];
                    return InkWell(
                      onTap: onSelect == null ? null : () => onSelect!(item.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedId == item.id
                              ? panelRaisedColor
                              : panelAltColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedId == item.id
                                ? accentColor
                                : borderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: textPrimaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.subtitle,
                              style: const TextStyle(color: textMutedColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.meta,
                              style: const TextStyle(color: textSubtleColor),
                            ),
                            if (item.tags.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: item.tags
                                    .where(
                                      (String tag) => tag.trim().isNotEmpty,
                                    )
                                    .map(
                                      (String tag) =>
                                          ControlPlaneInlineTag(label: tag),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class ControlPlaneTenantDetailCard extends StatelessWidget {
  const ControlPlaneTenantDetailCard({
    super.key,
    required this.tenant,
    required this.actorController,
    required this.reasonController,
    required this.actionError,
    required this.actionLoading,
    required this.onDisable,
  });

  final TenantRecord? tenant;
  final TextEditingController actorController;
  final TextEditingController reasonController;
  final String? actionError;
  final bool actionLoading;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    if (tenant == null) {
      return const PanelCard(
        title: 'Tenant detail',
        child: EmptyState(
          title: 'No tenant selected',
          body:
              'Choose a tenant to inspect retention, onboarding, and live management actions.',
        ),
      );
    }
    return PanelCard(
      title: 'Tenant detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPanel(
            title: tenant!.displayName,
            body:
                'Tenant: ${tenant!.tenantId}\nStatus: ${tenant!.status}\nType: ${tenant!.type}\nRegion: ${blankAsUnknown(tenant!.region)}\nOwner: ${tenant!.ownerUserId}\nOnboarding: ${blankAsUnknown(tenant!.onboardingState)}\nCreated: ${formatDateTime(tenant!.createdAt)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Policies',
            body:
                'Default template: ${tenant!.defaultAgentTemplate}\nApproval mode: ${blankAsUnknown(tenant!.defaultApprovalMode)}\nMax run seconds: ${tenant!.maxRunSeconds}\nMax turns: ${tenant!.maxTurns}\nBudget max runs/day: ${tenant!.maxRunsPerDay}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Retention',
            body:
                'Run history days: ${tenant!.runHistoryDays}\nArtifact days: ${tenant!.artifactDays}\nAudit log days: ${tenant!.auditLogDays}',
          ),
          const SizedBox(height: 12),
          AppTextFormField(
            label: 'Disable actor ID',
            controller: actorController,
          ),
          const SizedBox(height: 10),
          AppTextFormField(
            label: 'Disable reason',
            controller: reasonController,
            minLines: 2,
            maxLines: 3,
          ),
          if (actionError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(actionError!, style: const TextStyle(color: dangerColor)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: actionLoading ? null : onDisable,
            child: actionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Disable tenant'),
          ),
        ],
      ),
    );
  }
}

class ControlPlaneAgentDetailCard extends StatelessWidget {
  const ControlPlaneAgentDetailCard({
    super.key,
    required this.agent,
    required this.actorController,
    required this.reasonController,
    required this.actionError,
    required this.actionLoading,
    required this.onDisable,
  });

  final AgentRecord? agent;
  final TextEditingController actorController;
  final TextEditingController reasonController;
  final String? actionError;
  final bool actionLoading;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    if (agent == null) {
      return const PanelCard(
        title: 'Agent detail',
        child: EmptyState(
          title: 'No agent selected',
          body:
              'Choose a control-plane agent to inspect bindings and management actions.',
        ),
      );
    }
    return PanelCard(
      title: 'Agent detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPanel(
            title: agent!.name,
            body:
                'Agent: ${agent!.agentId}\nTenant: ${agent!.tenantId}\nStatus: ${agent!.status}\nTemplate: ${agent!.templateId}\nOnboarding: ${blankAsUnknown(agent!.onboardingState)}\nApproval override: ${blankAsUnknown(agent!.approvalOverrideMode)}\nRuntime override: ${agent!.runtimeOverrideMaxRunSeconds}/${agent!.runtimeOverrideMaxTurns}',
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Enabled capabilities',
            tags: agent!.enabledCapabilities,
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Denied capabilities',
            tags: agent!.deniedCapabilities,
          ),
          const SizedBox(height: 12),
          TagSection(
            title: 'Integration bindings',
            tags: agent!.integrationBindings,
          ),
          const SizedBox(height: 12),
          AppTextFormField(
            label: 'Disable actor ID',
            controller: actorController,
          ),
          const SizedBox(height: 10),
          AppTextFormField(
            label: 'Disable reason',
            controller: reasonController,
            minLines: 2,
            maxLines: 3,
          ),
          if (actionError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(actionError!, style: const TextStyle(color: dangerColor)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: actionLoading ? null : onDisable,
            child: actionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Disable agent'),
          ),
        ],
      ),
    );
  }
}

class ControlPlaneInstallationDetailCard extends StatelessWidget {
  const ControlPlaneInstallationDetailCard({
    super.key,
    required this.loading,
    required this.error,
    required this.detail,
    required this.selectedInstallation,
    required this.actorController,
    required this.channelsController,
    required this.usersController,
    required this.agentsController,
    required this.actionError,
    required this.actionLoading,
    required this.onSave,
  });

  final bool loading;
  final String? error;
  final InstallationDetailRecord? detail;
  final InstallationRecord? selectedInstallation;
  final TextEditingController actorController;
  final TextEditingController channelsController;
  final TextEditingController usersController;
  final TextEditingController agentsController;
  final String? actionError;
  final bool actionLoading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PanelCard(
        title: 'Installation detail',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return PanelCard(
        title: 'Installation detail',
        child: InfoPanel(
          title: 'Installation detail',
          body: error!,
          tone: dangerColor,
        ),
      );
    }
    final installation = detail?.installation ?? selectedInstallation;
    if (installation == null) {
      return const PanelCard(
        title: 'Installation detail',
        child: EmptyState(
          title: 'No installation selected',
          body:
              'Choose an installation to inspect route health and update live access controls.',
        ),
      );
    }
    return PanelCard(
      title: 'Installation detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoPanel(
            title:
                '${installation.providerType}:${installation.externalWorkspaceId}',
            body:
                'Installation: ${installation.installationId}\nStatus: ${installation.status}\nTenant: ${installation.mappedTenantId}\nDefault agent: ${installation.mappedDefaultAgentId}\nInstalled by: ${installation.installedBy}\nInstalled at: ${formatDateTime(installation.installedAt)}\nLast verified: ${formatDateTime(installation.lastVerifiedAt)}\nAdapter version: ${installation.adapterVersion}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Route-aware health',
            body:
                'Linked routes: ${detail?.routeHealth.linkedRouteCount ?? 0}\nUnhealthy routes: ${detail?.routeHealth.unhealthyRouteCount ?? 0}\nMapped agent: ${blankAsUnknown(detail?.mappedAgent?.agentId ?? installation.mappedDefaultAgentId)}\nMapped agent onboarding: ${blankAsUnknown(detail?.routeHealth.mappedAgentOnboarding ?? '')}',
          ),
          const SizedBox(height: 12),
          AppTextFormField(
            label: 'Actor ID',
            controller: actorController,
          ),
          const SizedBox(height: 10),
          AppTextFormField(
            label: 'Allowed channel IDs (comma separated)',
            controller: channelsController,
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          AppTextFormField(
            label: 'Allowed external user IDs (comma separated)',
            controller: usersController,
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          AppTextFormField(
            label: 'Allowed agent IDs (comma separated)',
            controller: agentsController,
            minLines: 2,
            maxLines: 3,
          ),
          if (actionError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(actionError!, style: const TextStyle(color: dangerColor)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: actionLoading ? null : onSave,
            child: actionLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save installation access'),
          ),
        ],
      ),
    );
  }
}

class ControlPlaneConversationDetailCard extends StatelessWidget {
  const ControlPlaneConversationDetailCard({
    super.key,
    required this.loading,
    required this.detailError,
    required this.detail,
    required this.selectedConversation,
  });

  final bool loading;
  final String? detailError;
  final ConversationDetailRecord? detail;
  final ConversationRecord? selectedConversation;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PanelCard(
        title: 'Conversation detail',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final conversation = detail?.conversation ?? selectedConversation;
    if (conversation == null) {
      return const PanelCard(
        title: 'Conversation detail',
        child: EmptyState(
          title: 'No conversation selected',
          body:
              'Choose a conversation to inspect recent turns and pending execution state.',
        ),
      );
    }
    return PanelCard(
      title: 'Conversation detail',
      child: ListView(
        shrinkWrap: true,
        children: [
          InfoPanel(
            title: conversation.name.isEmpty
                ? conversation.conversationId
                : conversation.name,
            body:
                'Conversation: ${conversation.conversationId}\nTenant: ${conversation.tenantId}\nAgent: ${conversation.agentId}\nKind: ${blankAsUnknown(conversation.kind)}\nStatus: ${conversation.status}\nCreated: ${formatDateTime(conversation.createdAt)}',
          ),
          const SizedBox(height: 12),
          if (detailError != null)
            InfoPanel(
              title: 'Conversation state',
              body: detailError!,
              tone: dangerColor,
            )
          else if (detail == null)
            const InfoPanel(
              title: 'Conversation state',
              body: 'No persisted conversation state was found.',
            )
          else
            InfoPanel(
              title: 'Pending execution',
              body:
                  'Latest run: ${blankAsUnknown(detail!.state.latestRunId)}\nLatest approval: ${blankAsUnknown(detail!.state.latestApprovalRequestId)}\nPending status: ${detail!.state.pending == null ? 'not pending' : detail!.state.pending!.status}\nWait reason: ${detail!.state.pending == null ? 'not waiting' : blankAsUnknown(detail!.state.pending!.waitReason)}\nPending question: ${detail!.state.pending == null ? 'not set' : blankAsUnknown(detail!.state.pending!.pendingQuestion)}',
            ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Latest approval',
            body: detail?.latestApproval == null
                ? 'No approval record is linked to this conversation.'
                : 'Approval: ${detail!.latestApproval!.approvalRequestId}\nRun: ${detail!.latestApproval!.runId}\nDecision: ${detail!.latestApproval!.decision}\nApprover: ${blankAsUnknown(detail!.latestApproval!.approverId)}\nCreated: ${formatDateTime(detail!.latestApproval!.createdAt)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Latest run',
            body: detail?.latestRun == null
                ? 'No run is linked to this conversation yet.'
                : 'Run: ${detail!.latestRun!.runId}\nStatus: ${detail!.latestRun!.status}\nInvocation: ${blankAsUnknown(detail!.latestRun!.invocationMode)}\nCreated: ${formatDateTime(detail!.latestRun!.createdAt)}\nSummary: ${blankAsUnknown(detail!.latestRun!.resultSummary)}',
          ),
          const SizedBox(height: 12),
          InfoPanel(
            title: 'Route and install health',
            body:
                'Routes: ${detail?.routeHealth.routeCount ?? 0}\nInstallations: ${detail?.routeHealth.installationCount ?? 0}\nUnhealthy routes: ${detail?.routeHealth.unhealthyRouteCount ?? 0}\nInactive installations: ${detail?.routeHealth.inactiveInstallationCount ?? 0}',
          ),
          const SizedBox(height: 12),
          SubsectionTitle('Recent turns'),
          const SizedBox(height: 8),
          if (detail == null || detail!.state.turns.isEmpty)
            const InfoPanel(
              title: 'Recent turns',
              body: 'No recent turns were recorded for this conversation.',
            )
          else
            ...detail!.state.turns.reversed
                .take(6)
                .map(
                  (ConversationTurnItem turn) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InfoPanel(
                      title: '${turn.role} • ${formatDateTime(turn.createdAt)}',
                      body:
                          '${turn.content}\nActor: ${blankAsUnknown(turn.actorId)}\nRun: ${blankAsUnknown(turn.runId)}',
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class ControlPlaneRoutesPanel extends StatelessWidget {
  const ControlPlaneRoutesPanel({
    super.key,
    required this.routes,
    required this.onRefresh,
  });

  final List<ChannelRouteRecord> routes;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      title: 'Channel routes',
      trailing: FilledButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      child: routes.isEmpty
          ? const EmptyState(
              title: 'No routes',
              body: 'No channel routes have been provisioned yet.',
            )
          : Column(
              children: routes
                  .map(
                    (ChannelRouteRecord route) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InfoPanel(
                        title:
                            '${route.providerType}:${blankAsUnknown(route.channelId)}',
                        body:
                            'Route: ${route.routeId}\nConversation: ${route.conversationId}\nInstallation: ${blankAsUnknown(route.installationId)}\nThread: ${blankAsUnknown(route.threadId)}\nStatus: ${route.status}\nCreated: ${formatDateTime(route.createdAt)}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class ControlPlaneInlineTag extends StatelessWidget {
  const ControlPlaneInlineTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: panelRaisedColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: textMutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
