import 'package:flutter/material.dart';
import 'package:ui/control_plane/control_plane_api.dart';
import 'package:ui/control_plane/control_plane_page.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/harness_config/harness_config_pages.dart';
import 'package:ui/operations/operations_api.dart';
import 'package:ui/operations/operations_pages.dart';
import 'package:ui/providers/provider_catalog_api.dart';
import 'package:ui/providers/providers_page.dart';
import 'package:ui/shared/ui.dart';

enum AppSection {
  summary('Summary', Icons.dashboard_outlined),
  runs('Runs', Icons.play_circle_outline_rounded),
  approvals('Approvals', Icons.rule_folder_outlined),
  artifacts('Artifacts', Icons.inventory_2_outlined),
  audits('Audits', Icons.gavel_outlined),
  controlPlane('Control Plane', Icons.hub_outlined),
  harnessAgents('Harness Agents', Icons.smart_toy_outlined),
  harnessTools('Harness Tools', Icons.build_outlined),
  harnessWorkflows('Harness Workflows', Icons.account_tree_outlined),
  providers('Providers', Icons.cloud_outlined);

  const AppSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

extension AppSectionRouting on AppSection {
  String get routePath {
    return switch (this) {
      AppSection.summary => '/summary',
      AppSection.runs => '/runs',
      AppSection.approvals => '/approvals',
      AppSection.artifacts => '/artifacts',
      AppSection.audits => '/audits',
      AppSection.controlPlane => '/control-plane',
      AppSection.harnessAgents => '/harness/agents',
      AppSection.harnessTools => '/harness/tools',
      AppSection.harnessWorkflows => '/harness/workflows',
      AppSection.providers => '/providers',
    };
  }

  static AppSection fromRouteName(String? routeName) {
    switch (routeName) {
      case '/':
      case '/summary':
        return AppSection.summary;
      case '/runs':
        return AppSection.runs;
      case '/approvals':
        return AppSection.approvals;
      case '/artifacts':
        return AppSection.artifacts;
      case '/audits':
        return AppSection.audits;
      case '/control-plane':
        return AppSection.controlPlane;
      case '/harness/agents':
        return AppSection.harnessAgents;
      case '/harness/tools':
        return AppSection.harnessTools;
      case '/harness/workflows':
        return AppSection.harnessWorkflows;
      case '/providers':
        return AppSection.providers;
      default:
        return AppSection.runs;
    }
  }
}

class BetaShell extends StatefulWidget {
  const BetaShell({
    super.key,
    required this.controlPlaneBaseUrl,
    required this.controlPlaneApi,
    required this.harnessConfigApi,
    required this.operationsApi,
    required this.providerApi,
    required this.initialSection,
  });

  final String controlPlaneBaseUrl;
  final ControlPlaneApi controlPlaneApi;
  final HarnessConfigApi harnessConfigApi;
  final OperationsApi operationsApi;
  final ProviderCatalogApi providerApi;
  final AppSection initialSection;

  @override
  State<BetaShell> createState() => _BetaShellState();
}

class _BetaShellState extends State<BetaShell> {
  late AppSection _section;
  final _deploymentMode = const String.fromEnvironment(
    'CONTROL_PLANE_DEPLOYMENT',
    defaultValue: 'local',
  ).toLowerCase();

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  @override
  void didUpdateWidget(covariant BetaShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != oldWidget.initialSection &&
        widget.initialSection != _section) {
      _section = widget.initialSection;
    }
  }

  void _selectSection(AppSection section) {
    if (section == _section) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(section.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_section) {
      AppSection.summary => SummaryPage(operationsApi: widget.operationsApi),
      AppSection.runs => RunsPage(
        operationsApi: widget.operationsApi,
        initialRunId: null,
      ),
      AppSection.approvals => ApprovalsPage(
        operationsApi: widget.operationsApi,
      ),
      AppSection.artifacts => ArtifactsPage(
        operationsApi: widget.operationsApi,
      ),
      AppSection.audits => AuditsPage(operationsApi: widget.operationsApi),
      AppSection.controlPlane => ControlPlanePage(
        controlPlaneApi: widget.controlPlaneApi,
      ),
      AppSection.harnessAgents => HarnessAgentsPage(
        harnessConfigApi: widget.harnessConfigApi,
        harnessConfigAvailable: _deploymentMode != 'cloudflare',
      ),
      AppSection.harnessTools => HarnessToolsPage(
        harnessConfigApi: widget.harnessConfigApi,
        harnessConfigAvailable: _deploymentMode != 'cloudflare',
      ),
      AppSection.harnessWorkflows => HarnessWorkflowsPage(
        harnessConfigApi: widget.harnessConfigApi,
        harnessConfigAvailable: _deploymentMode != 'cloudflare',
      ),
      AppSection.providers => ProvidersPage(
        providerApi: widget.providerApi,
        providerCatalogAvailable: _deploymentMode != 'cloudflare',
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              selected: _section,
              deploymentMode: _deploymentMode,
              onSelect: _selectSection,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderBar(
                      section: _section,
                      controlPlaneBaseUrl: widget.controlPlaneBaseUrl,
                      deploymentMode: _deploymentMode,
                    ),
                    const SizedBox(height: 18),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.deploymentMode,
    required this.onSelect,
  });

  final AppSection selected;
  final String deploymentMode;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0D131A),
        border: Border(right: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _NavLabel('Operations'),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.summary,
                  selected: selected == AppSection.summary,
                  onTap: onSelect,
                ),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.runs,
                  selected: selected == AppSection.runs,
                  onTap: onSelect,
                ),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.approvals,
                  selected: selected == AppSection.approvals,
                  onTap: onSelect,
                ),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.artifacts,
                  selected: selected == AppSection.artifacts,
                  onTap: onSelect,
                ),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.audits,
                  selected: selected == AppSection.audits,
                  onTap: onSelect,
                ),
                const SizedBox(height: 20),
                const _NavLabel('Control Plane'),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.controlPlane,
                  selected: selected == AppSection.controlPlane,
                  onTap: onSelect,
                ),
                const SizedBox(height: 20),
                const _NavLabel('Harness Config'),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.harnessAgents,
                  selected: selected == AppSection.harnessAgents,
                  badge: deploymentMode == 'cloudflare' ? 'local only' : null,
                  onTap: onSelect,
                ),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.harnessTools,
                  selected: selected == AppSection.harnessTools,
                  badge: deploymentMode == 'cloudflare' ? 'local only' : null,
                  onTap: onSelect,
                ),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.harnessWorkflows,
                  selected: selected == AppSection.harnessWorkflows,
                  badge: deploymentMode == 'cloudflare' ? 'local only' : null,
                  onTap: onSelect,
                ),
                const SizedBox(height: 8),
                _NavButton(
                  section: AppSection.providers,
                  selected: selected == AppSection.providers,
                  badge: deploymentMode == 'cloudflare' ? 'local only' : null,
                  onTap: onSelect,
                ),
                if (deploymentMode == 'cloudflare') ...[
                  const SizedBox(height: 16),
                  const InfoPanel(
                    title: 'Deployed mode',
                    body:
                        'Harness config editors are intentionally local-only. Run detail still shows live control-plane data, and harness session inspection appears when the deployment can read local harness state.',
                  ),
                ],
                const SizedBox(height: 16),
                const InfoPanel(
                  title: 'Beta mode',
                  body:
                      'This shell exposes only live control-plane-backed surfaces. Seed data and design-only sections have been removed from the beta path.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFE28A2B), Color(0xFFB85417)],
            ),
          ),
          child: const Icon(Icons.hub_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agent Awesome',
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Beta operator console',
                style: TextStyle(color: textMutedColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: textSubtleColor,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.section,
    required this.selected,
    this.badge,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final String? badge;
  final ValueChanged<AppSection> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? panelRaisedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(section),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                section.icon,
                color: selected ? textPrimaryColor : textMutedColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? textPrimaryColor : textMutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: warningColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.section,
    required this.controlPlaneBaseUrl,
    required this.deploymentMode,
  });

  final AppSection section;
  final String controlPlaneBaseUrl;
  final String deploymentMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Connected to $controlPlaneBaseUrl (${deploymentMode.toUpperCase()})',
                style: const TextStyle(color: textMutedColor),
              ),
            ],
          ),
        ),
        StatusPill(
          label: deploymentMode == 'cloudflare' ? 'Deployed mode' : 'Live API',
          color: deploymentMode == 'cloudflare' ? warningColor : successColor,
        ),
      ],
    );
  }
}
