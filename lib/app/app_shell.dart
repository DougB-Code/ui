import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      case null:
      case '':
      case '/':
        return AppSection.runs;
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

class _NavigationGroup {
  const _NavigationGroup(this.label, this.sections);

  final String label;
  final List<AppSection> sections;
}

const List<_NavigationGroup> _navigationGroups = <_NavigationGroup>[
  _NavigationGroup('Operations', <AppSection>[
    AppSection.summary,
    AppSection.runs,
    AppSection.approvals,
    AppSection.artifacts,
    AppSection.audits,
  ]),
  _NavigationGroup('Control Plane', <AppSection>[AppSection.controlPlane]),
  _NavigationGroup('Harness Config', <AppSection>[
    AppSection.harnessAgents,
    AppSection.harnessTools,
    AppSection.harnessWorkflows,
    AppSection.providers,
  ]),
];

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

class _BetaShellState extends State<BetaShell> with WidgetsBindingObserver {
  late AppSection _section;
  final Map<AppSection, Widget> _contentCache = <AppSection, Widget>{};
  final _deploymentMode = const String.fromEnvironment(
    'CONTROL_PLANE_DEPLOYMENT',
    defaultValue: 'local',
  ).toLowerCase();
  bool _railExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _section = widget.initialSection;
    _ensureContentLoaded(_section);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BetaShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != oldWidget.initialSection) {
      _section = widget.initialSection;
    }

    final apiConfigurationChanged =
        widget.controlPlaneApi != oldWidget.controlPlaneApi ||
        widget.harnessConfigApi != oldWidget.harnessConfigApi ||
        widget.operationsApi != oldWidget.operationsApi ||
        widget.providerApi != oldWidget.providerApi;
    if (apiConfigurationChanged) {
      _contentCache.clear();
    }
    _ensureContentLoaded(_section);
  }

  @override
  Future<bool> didPushRoute(String route) async {
    _selectSection(AppSectionRouting.fromRouteName(route), syncRoute: false);
    return true;
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final path = routeInformation.uri.path.isEmpty
        ? '/'
        : routeInformation.uri.path;
    _selectSection(AppSectionRouting.fromRouteName(path), syncRoute: false);
    return true;
  }

  void _ensureContentLoaded(AppSection section) {
    _contentCache.putIfAbsent(section, () => _buildContentPane(section));
  }

  Widget _buildContentPane(AppSection section) {
    return switch (section) {
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
  }

  void _selectSection(AppSection section, {bool syncRoute = true}) {
    if (section == _section) {
      return;
    }
    setState(() {
      _section = section;
      _ensureContentLoaded(section);
    });
    if (syncRoute) {
      SystemNavigator.routeInformationUpdated(
        uri: Uri.parse(section.routePath),
      );
    }
  }

  void _showLogoutPlaceholder() {
    showAppMessage(context, 'Logout is not available in the beta shell yet.');
  }

  void _toggleRail() {
    setState(() => _railExpanded = !_railExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF090D16),
              Color(0xFF0B1221),
              Color(0xFF060A14),
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppRail(
              expanded: _railExpanded,
              selected: _section,
              deploymentMode: _deploymentMode,
              onToggleExpanded: _toggleRail,
              onSelect: _selectSection,
              onLogout: _showLogoutPlaceholder,
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xA60C121E)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderBar(
                        section: _section,
                        controlPlaneBaseUrl: widget.controlPlaneBaseUrl,
                        deploymentMode: _deploymentMode,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: IndexedStack(
                          index: AppSection.values.indexOf(_section),
                          sizing: StackFit.expand,
                          children: AppSection.values.map((AppSection section) {
                            return KeyedSubtree(
                              key: ValueKey<AppSection>(section),
                              child:
                                  _contentCache[section] ??
                                  const SizedBox.shrink(),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppRail extends StatelessWidget {
  const _AppRail({
    required this.expanded,
    required this.selected,
    required this.deploymentMode,
    required this.onToggleExpanded,
    required this.onSelect,
    required this.onLogout,
  });

  final bool expanded;
  final AppSection selected;
  final String deploymentMode;
  final VoidCallback onToggleExpanded;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? 304 : 84,
      color: const Color(0xCC09101C),
      padding: EdgeInsets.fromLTRB(
        expanded ? 18 : 12,
        18,
        expanded ? 18 : 12,
        18,
      ),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          _RailIconButton(
            icon: expanded
                ? Icons.arrow_back_ios_new_rounded
                : Icons.arrow_forward_ios_rounded,
            tooltip: expanded ? 'Collapse navigation' : 'Expand navigation',
            onTap: onToggleExpanded,
          ),
          if (expanded) ...[
            const SizedBox(height: 18),
            const _BrandLockup(),
            const SizedBox(height: 28),
          ] else
            const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final group in _navigationGroups) ...[
                  if (expanded) ...[
                    _NavLabel(group.label),
                    const SizedBox(height: 8),
                    for (final section in group.sections) ...[
                      _NavButton(
                        section: section,
                        selected: selected == section,
                        badge: _badgeForSection(section),
                        onTap: onSelect,
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 14),
                  ] else ...[
                    for (final section in group.sections) ...[
                      _RailNavButton(
                        section: section,
                        selected: selected == section,
                        badge: _badgeForSection(section),
                        onTap: onSelect,
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
          if (expanded)
            _FooterNavButton(
              icon: Icons.logout_rounded,
              label: 'Logout',
              onTap: onLogout,
            ),
          if (!expanded)
            _RailIconButton(
              icon: Icons.logout_rounded,
              tooltip: 'Logout',
              onTap: onLogout,
            ),
        ],
      ),
    );
  }

  String? _badgeForSection(AppSection section) {
    if (deploymentMode != 'cloudflare') {
      return null;
    }
    switch (section) {
      case AppSection.harnessAgents:
      case AppSection.harnessTools:
      case AppSection.harnessWorkflows:
      case AppSection.providers:
        return 'local only';
      default:
        return null;
    }
  }
}

class _RailNavButton extends StatelessWidget {
  const _RailNavButton({
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
    return Center(
      child: Tooltip(
        message: badge == null ? section.label : '${section.label} ($badge)',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onTap(section),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: selected ? panelRaisedColor : Colors.transparent,
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          accentColor.withValues(alpha: 0.20),
                          infoColor.withValues(alpha: 0.12),
                        ],
                      )
                    : null,
                border: selected
                    ? Border.all(color: infoColor.withValues(alpha: 0.32))
                    : null,
              ),
              child: Icon(
                section.icon,
                color: selected ? textPrimaryColor : textMutedColor,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: panelAltColor,
              border: Border.all(color: borderColor.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, color: textMutedColor, size: 22),
          ),
        ),
      ),
    );
  }
}

class _FooterNavButton extends StatelessWidget {
  const _FooterNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: textMutedColor, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: textMutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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
