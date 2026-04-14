import 'package:flutter/material.dart';
import 'package:ui/control_plane_api.dart';
import 'package:ui/harness_config_api.dart';
import 'package:ui/operations_api.dart';
import 'package:ui/provider_catalog_api.dart';

part 'app_shell.dart';
part 'operations_pages.dart';
part 'control_plane_page.dart';
part 'harness_config_pages.dart';
part 'providers_page.dart';

void main() {
  runApp(
    AgentAwesomeBetaApp(
      controlPlaneBaseUrl: const String.fromEnvironment(
        'CONTROL_PLANE_BASE_URL',
        defaultValue: 'http://127.0.0.1:8080',
      ),
      controlPlaneApi: HttpControlPlaneApi.fromEnvironment(),
      harnessConfigApi: HttpHarnessConfigApi.fromEnvironment(),
      operationsApi: HttpOperationsApi.fromEnvironment(),
      providerApi: HttpProviderCatalogApi.fromEnvironment(),
    ),
  );
}

class AgentAwesomeBetaApp extends StatelessWidget {
  const AgentAwesomeBetaApp({
    super.key,
    required this.controlPlaneBaseUrl,
    required this.controlPlaneApi,
    required this.harnessConfigApi,
    required this.operationsApi,
    required this.providerApi,
  });

  final String controlPlaneBaseUrl;
  final ControlPlaneApi controlPlaneApi;
  final HarnessConfigApi harnessConfigApi;
  final OperationsApi operationsApi;
  final ProviderCatalogApi providerApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _info,
          surface: _panel,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
          bodyMedium: TextStyle(color: _textMuted, height: 1.45),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _panelAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accent),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
      home: _BetaShell(
        controlPlaneBaseUrl: controlPlaneBaseUrl,
        controlPlaneApi: controlPlaneApi,
        harnessConfigApi: harnessConfigApi,
        operationsApi: operationsApi,
        providerApi: providerApi,
      ),
    );
  }
}

const _bg = Color(0xFF10151C);
const _panel = Color(0xFF17202B);
const _panelAlt = Color(0xFF1D2835);
const _panelRaised = Color(0xFF233142);
const _border = Color(0xFF324355);
const _textPrimary = Color(0xFFF4F7FA);
const _textMuted = Color(0xFFB8C4D3);
const _textSubtle = Color(0xFF7E8DA0);
const _accent = Color(0xFFE28A2B);
const _info = Color(0xFF3BA0FF);
const _success = Color(0xFF26C281);
const _warning = Color(0xFFF4B942);
const _danger = Color(0xFFE25C5C);

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
    this.fill = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 16),
            if (fill) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.tone,
    required this.detail,
  });

  final String label;
  final String value;
  final Color tone;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textMuted)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: tone,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(color: _textSubtle)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: _textMuted, height: 1.5)),
        ],
      ),
    );
  }
}

class _SubsectionTitle extends StatelessWidget {
  const _SubsectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: _textMuted)),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubsectionTitle(title),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const _InfoPanel(title: 'None', body: 'No values recorded.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (String tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _panelAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(color: _textPrimary),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 42, color: _textSubtle),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: _danger),
            const SizedBox(height: 14),
            const Text(
              'The control plane request failed',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: _textMuted),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'running':
      return _info;
    case 'waiting_approval':
    case 'waiting_user':
      return _warning;
    case 'completed':
      return _success;
    case 'blocked':
    case 'failed':
    case 'cancelled':
      return _danger;
    case 'queued':
      return _accent;
    default:
      return _textMuted;
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'not recorded';
  }
  final twoDigitMonth = value.month.toString().padLeft(2, '0');
  final twoDigitDay = value.day.toString().padLeft(2, '0');
  final twoDigitHour = value.hour.toString().padLeft(2, '0');
  final twoDigitMinute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
}

String _blankAsUnknown(String value) {
  return value.trim().isEmpty ? 'not set' : value.trim();
}
