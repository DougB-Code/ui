import 'package:flutter/material.dart';

const bgColor = Color(0xFF090D16);
const panelColor = Color(0xB3141C2B);
const panelAltColor = Color(0xD61A2435);
const panelRaisedColor = Color(0xFF1E2D45);
const borderColor = Color(0xFF2A3A52);
const textPrimaryColor = Color(0xFFF4F7FA);
const textMutedColor = Color(0xFFB8C4D3);
const textSubtleColor = Color(0xFF7E8DA0);
const accentColor = Color(0xFFEE9A3D);
const infoColor = Color(0xFF37B6F6);
const successColor = Color(0xFF26C281);
const warningColor = Color(0xFFF4B942);
const dangerColor = Color(0xFFE25C5C);

class ScreenHeaderActionsController extends ValueNotifier<List<Widget>> {
  ScreenHeaderActionsController() : super(const <Widget>[]);

  void setActions(List<Widget> actions) {
    value = List<Widget>.unmodifiable(actions);
  }

  void clear() {
    value = const <Widget>[];
  }
}

ThemeData buildAgentAwesomeTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: bgColor,
    colorScheme: const ColorScheme.dark(
      primary: accentColor,
      secondary: infoColor,
      surface: panelColor,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: textPrimaryColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimaryColor,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: textPrimaryColor,
      ),
      bodyMedium: TextStyle(color: textMutedColor, height: 1.45),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x99212D41),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accentColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2B6C8A),
        foregroundColor: textPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textMutedColor,
        side: BorderSide(color: borderColor.withValues(alpha: 0.8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class AppFieldBlock extends StatelessWidget {
  const AppFieldBlock({
    super.key,
    required this.label,
    required this.child,
    this.spacing = 8,
  });

  final String label;
  final Widget child;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: spacing),
        child,
      ],
    );
  }
}

class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.fieldKey,
    this.onChanged,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.hintText,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.style,
  }) : assert(
         controller == null || initialValue == null,
         'Use either controller or initialValue, not both.',
       );

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final String? hintText;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final multiline = (maxLines ?? 1) > 1 || (minLines ?? 1) > 1;
    return AppFieldBlock(
      label: label,
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        initialValue: initialValue,
        onChanged: onChanged,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        readOnly: readOnly,
        enabled: enabled,
        obscureText: obscureText,
        style: style,
        decoration: InputDecoration(
          hintText: hintText,
          alignLabelWithHint: multiline,
        ),
      ),
    );
  }
}

class AppManagedTextField extends StatefulWidget {
  const AppManagedTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.hintText,
    this.keyboardType,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final int? minLines;
  final String? hintText;
  final TextInputType? keyboardType;

  @override
  State<AppManagedTextField> createState() => _AppManagedTextFieldState();
}

class _AppManagedTextFieldState extends State<AppManagedTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant AppManagedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = (widget.maxLines ?? 1) > 1 || (widget.minLines ?? 1) > 1;
    return AppFieldBlock(
      label: widget.label,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          hintText: widget.hintText,
          alignLabelWithHint: multiline,
        ),
      ),
    );
  }
}

class AppManagedNumberField extends StatelessWidget {
  const AppManagedNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppManagedTextField(
      label: label,
      value: value == 0 ? '' : value.toString(),
      keyboardType: TextInputType.number,
      onChanged: (String rawValue) =>
          onChanged(int.tryParse(rawValue.trim()) ?? 0),
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.fieldKey,
    this.fallbackLabel,
    this.labelBuilder,
  });

  final String label;
  final List<T> options;
  final T? value;
  final Key? fieldKey;
  final String? fallbackLabel;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return AppFieldBlock(
      label: label,
      child: DropdownButtonFormField<T>(
        key: fieldKey,
        isExpanded: true,
        initialValue: options.contains(value) ? value : null,
        hint: fallbackLabel == null ? null : Text(fallbackLabel!),
        items: options
            .map(
              (T option) => DropdownMenuItem<T>(
                value: option,
                child: Text(labelBuilder?.call(option) ?? option.toString()),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class AppReadOnlyField extends StatelessWidget {
  const AppReadOnlyField({
    super.key,
    required this.label,
    required this.value,
    this.actionIcon,
    this.onAction,
  });

  final String label;
  final String value;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppFieldBlock(
      label: label,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0x99212D41),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textMutedColor),
                ),
              ),
            ),
            if (actionIcon != null)
              Container(
                width: 56,
                height: double.infinity,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: borderColor.withValues(alpha: 0.85)),
                  ),
                ),
                child: IconButton(
                  onPressed: onAction,
                  icon: Icon(actionIcon, color: textMutedColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
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
        color: panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
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

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
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
        color: panelColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: textMutedColor)),
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
          Text(detail, style: const TextStyle(color: textSubtleColor)),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

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

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.title,
    required this.body,
    this.tone,
  });

  final String title;
  final String body;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone ?? borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tone ?? textPrimaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: textMutedColor, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class SubsectionTitle extends StatelessWidget {
  const SubsectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: textMutedColor)),
    );
  }
}

class TagSection extends StatelessWidget {
  const TagSection({super.key, required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubsectionTitle(title),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const InfoPanel(title: 'None', body: 'No values recorded.')
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
                      color: panelAltColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(color: textPrimaryColor),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body});

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
            const Icon(Icons.inbox_outlined, size: 42, color: textSubtleColor),
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
              style: const TextStyle(color: textMutedColor),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

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
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: dangerColor,
            ),
            const SizedBox(height: 14),
            const Text(
              'The control plane request failed',
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: textMutedColor),
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

Color statusColor(String status) {
  switch (status) {
    case 'running':
      return infoColor;
    case 'waiting_approval':
    case 'waiting_user':
      return warningColor;
    case 'completed':
      return successColor;
    case 'blocked':
    case 'failed':
    case 'cancelled':
      return dangerColor;
    case 'queued':
      return accentColor;
    default:
      return textMutedColor;
  }
}

String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'not recorded';
  }
  final twoDigitMonth = value.month.toString().padLeft(2, '0');
  final twoDigitDay = value.day.toString().padLeft(2, '0');
  final twoDigitHour = value.hour.toString().padLeft(2, '0');
  final twoDigitMinute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
}

String blankAsUnknown(String value) {
  return value.trim().isEmpty ? 'not set' : value.trim();
}
