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
  harnessAgents('Agents', Icons.smart_toy_outlined),
  harnessTools('Tools', Icons.build_outlined),
  harnessRules('Rules', Icons.rule_folder_outlined),
  harnessWorkflows('Workflows', Icons.account_tree_outlined),
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
      AppSection.harnessRules => '/harness/rules',
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
      case '/harness/rules':
        return AppSection.harnessRules;
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
    AppSection.harnessWorkflows,
    AppSection.harnessRules,
    AppSection.harnessAgents,
    AppSection.harnessTools,
    AppSection.providers,
  ]),
];

const String _railLogoAssetPath = 'assets/images/agentawesome-logo.png';
const ValueKey<String> _appRailKey = ValueKey<String>('app-rail');
const ValueKey<String> _appRailLogoKey = ValueKey<String>('app-rail-logo');
const ValueKey<String> _appRailExpandIconKey = ValueKey<String>(
  'app-rail-expand-icon',
);
const Color _appRailBackgroundColor = Color(0xCC09101C);

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
  late final Map<AppSection, ScreenHeaderActionsController>
  _headerActionControllers = <AppSection, ScreenHeaderActionsController>{
    for (final AppSection section in AppSection.values)
      section: ScreenHeaderActionsController(),
  };
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
    for (final controller in _headerActionControllers.values) {
      controller.dispose();
    }
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
        headerActionsController:
            _headerActionControllers[AppSection.harnessAgents]!,
      ),
      AppSection.harnessTools => HarnessToolsPage(
        harnessConfigApi: widget.harnessConfigApi,
        harnessConfigAvailable: _deploymentMode != 'cloudflare',
        headerActionsController:
            _headerActionControllers[AppSection.harnessTools]!,
      ),
      AppSection.harnessRules => HarnessRulesPage(
        harnessConfigApi: widget.harnessConfigApi,
        harnessConfigAvailable: _deploymentMode != 'cloudflare',
        headerActionsController:
            _headerActionControllers[AppSection.harnessRules]!,
      ),
      AppSection.harnessWorkflows => HarnessWorkflowsPage(
        harnessConfigApi: widget.harnessConfigApi,
        harnessConfigAvailable: _deploymentMode != 'cloudflare',
        headerActionsController:
            _headerActionControllers[AppSection.harnessWorkflows]!,
      ),
      AppSection.providers => ProvidersPage(
        providerApi: widget.providerApi,
        providerCatalogAvailable: _deploymentMode != 'cloudflare',
        headerActionsController:
            _headerActionControllers[AppSection.providers]!,
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
                decoration: const BoxDecoration(color: _appRailBackgroundColor),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderBar(
                        section: _section,
                        actionController: _headerActionControllers[_section]!,
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

class _AppRail extends StatefulWidget {
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
  State<_AppRail> createState() => _AppRailState();
}

class _AppRailState extends State<_AppRail> {
  bool _toggleControlHovered = false;

  bool get _showToggleIcon => !widget.expanded && _toggleControlHovered;

  void _setToggleControlHovered(bool hovered) {
    if (_toggleControlHovered == hovered) {
      return;
    }
    setState(() => _toggleControlHovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.expanded ? MouseCursor.defer : SystemMouseCursors.click,
      child: AnimatedContainer(
        key: _appRailKey,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: widget.expanded ? 304 : 84,
        color: _appRailBackgroundColor,
        padding: EdgeInsets.fromLTRB(
          widget.expanded ? 18 : 12,
          18,
          widget.expanded ? 18 : 12,
          18,
        ),
        child: Column(
          crossAxisAlignment: widget.expanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (widget.expanded)
              Row(
                children: [
                  const _RailLogoBadge(
                    key: _appRailLogoKey,
                    size: 44,
                    padded: false,
                  ),
                  const Spacer(),
                  _RailIconButton(
                    icon: Icons.menu_open_rounded,
                    tooltip: 'Collapse navigation',
                    onTap: widget.onToggleExpanded,
                  ),
                ],
              )
            else
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: MouseRegion(
                  onEnter: (_) => _setToggleControlHovered(true),
                  onExit: (_) => _setToggleControlHovered(false),
                  child: _RailSurfaceButton(
                    tooltip: 'Expand navigation',
                    onTap: widget.onToggleExpanded,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: _showToggleIcon
                          ? const Icon(
                              Icons.menu_open_rounded,
                              key: _appRailExpandIconKey,
                              color: textPrimaryColor,
                              size: 22,
                            )
                          : const _RailLogoBadge(
                              key: _appRailLogoKey,
                              size: 44,
                              padded: false,
                            ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: widget.expanded ? 24 : 18),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final group in _navigationGroups) ...[
                    if (widget.expanded) ...[
                      _NavLabel(group.label),
                      const SizedBox(height: 8),
                      for (final section in group.sections) ...[
                        _NavButton(
                          section: section,
                          selected: widget.selected == section,
                          badge: _badgeForSection(section),
                          onTap: widget.onSelect,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 14),
                    ] else ...[
                      for (final section in group.sections) ...[
                        _RailNavButton(
                          section: section,
                          selected: widget.selected == section,
                          badge: _badgeForSection(section),
                          onTap: widget.onSelect,
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
            if (widget.expanded)
              _FooterNavButton(
                icon: Icons.logout_rounded,
                label: 'Logout',
                onTap: widget.onLogout,
              ),
            if (!widget.expanded)
              _RailIconButton(
                icon: Icons.logout_rounded,
                tooltip: 'Logout',
                onTap: widget.onLogout,
                fullWidth: true,
              ),
          ],
        ),
      ),
    );
  }

  String? _badgeForSection(AppSection section) {
    if (widget.deploymentMode != 'cloudflare') {
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: badge == null ? section.label : '${section.label} ($badge)',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onTap(section),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Center(
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
    this.fullWidth = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _RailSurfaceButton(
        onTap: onTap,
        tooltip: tooltip,
        fullWidth: fullWidth,
        child: Icon(icon, color: textMutedColor, size: 22),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
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
      ),
    );
  }
}

class _RailSurfaceButton extends StatelessWidget {
  const _RailSurfaceButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.fullWidth = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: fullWidth ? double.infinity : 44,
            height: 44,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: panelAltColor,
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.45),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailLogoBadge extends StatelessWidget {
  const _RailLogoBadge({super.key, required this.size, this.padded = true});

  final double size;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF050A12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(padded ? 3 : 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            _railLogoAssetPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
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
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.section, required this.actionController});

  final AppSection section;
  final ScreenHeaderActionsController actionController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Widget>>(
      valueListenable: actionController,
      builder: (BuildContext context, List<Widget> actions, Widget? child) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final stacked = constraints.maxWidth < 980;
            final actionMenu = _HeaderActionMenu(actions: actions);
            final sectionHeader = Wrap(
              spacing: 14,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  section.label,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionHeader,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    actionMenu,
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: sectionHeader),
                if (actions.isNotEmpty) actionMenu,
              ],
            );
          },
        );
      },
    );
  }
}

class _HeaderActionMenu extends StatelessWidget {
  const _HeaderActionMenu({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: Align(
        key: ValueKey<String>(
          actions
              .map(
                (Widget widget) =>
                    widget.key?.toString() ?? widget.runtimeType.toString(),
              )
              .join('|'),
        ),
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          children: actions,
        ),
      ),
    );
  }
}
