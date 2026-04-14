part of 'main.dart';

enum AppSection {
  runs('Runs', Icons.play_circle_outline_rounded),
  artifacts('Artifacts', Icons.inventory_2_outlined),
  audits('Audits', Icons.gavel_outlined),
  controlPlane('Control Plane', Icons.hub_outlined),
  providers('Providers', Icons.cloud_outlined);

  const AppSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _BetaShell extends StatefulWidget {
  const _BetaShell({
    required this.controlPlaneBaseUrl,
    required this.controlPlaneApi,
    required this.operationsApi,
    required this.providerApi,
  });

  final String controlPlaneBaseUrl;
  final ControlPlaneApi controlPlaneApi;
  final OperationsApi operationsApi;
  final ProviderCatalogApi providerApi;

  @override
  State<_BetaShell> createState() => _BetaShellState();
}

class _BetaShellState extends State<_BetaShell> {
  AppSection _section = AppSection.runs;
  final _deploymentMode = const String.fromEnvironment(
    'CONTROL_PLANE_DEPLOYMENT',
    defaultValue: 'local',
  ).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final content = switch (_section) {
      AppSection.runs => _RunsPage(
        operationsApi: widget.operationsApi,
        initialRunId: null,
      ),
      AppSection.artifacts => _ArtifactsPage(
        operationsApi: widget.operationsApi,
      ),
      AppSection.audits => _AuditsPage(operationsApi: widget.operationsApi),
      AppSection.controlPlane => _ControlPlanePage(
        controlPlaneApi: widget.controlPlaneApi,
        operationsApi: widget.operationsApi,
      ),
      AppSection.providers => _ProvidersPage(
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
              onSelect: (AppSection section) {
                setState(() {
                  _section = section;
                });
              },
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
  const _Sidebar({required this.selected, required this.onSelect});

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0D131A),
        border: Border(right: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 24),
          const _NavLabel('Operations'),
          const SizedBox(height: 8),
          _NavButton(
            section: AppSection.runs,
            selected: selected == AppSection.runs,
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
            section: AppSection.providers,
            selected: selected == AppSection.providers,
            onTap: onSelect,
          ),
          const Spacer(),
          const _InfoPanel(
            title: 'Beta mode',
            body:
                'This shell exposes only live control-plane-backed surfaces. Seed data and design-only sections have been removed from the beta path.',
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
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Beta operator console',
                style: TextStyle(color: _textMuted, fontSize: 12),
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
        color: _textSubtle,
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
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final ValueChanged<AppSection> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _panelRaised : Colors.transparent,
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
                color: selected ? _textPrimary : _textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _textPrimary : _textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
                style: const TextStyle(color: _textMuted),
              ),
            ],
          ),
        ),
        _StatusPill(
          label: deploymentMode == 'cloudflare' ? 'Deployed mode' : 'Live API',
          color: deploymentMode == 'cloudflare' ? _warning : _success,
        ),
      ],
    );
  }
}
