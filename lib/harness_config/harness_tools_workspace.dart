import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/shared/side_panel.dart';
import 'package:ui/shared/ui.dart';
import 'package:ui/shared/workspace_shell.dart';

enum _ToolEntryKind { toolGroup, externalTool, mcpServer }

enum _ToolPlatformFilter { all, linuxOnly, macOsOnly, windowsOnly }

enum _ToolSortMode { name, type, platform }

enum _ToolDetailTab { overview, access, runtime, document }

enum _ExternalToolOverviewSection { definition, runtime, schema, platforms }

enum _McpServerOverviewSection { definition, connection, scope, platforms }

enum _ToolPlatformGroup {
  toolGroups,
  allPlatforms,
  linuxOnly,
  macOsOnly,
  windowsOnly,
  customPlatforms,
}

enum _ToolResourceAccess { none, execute, read, write }

extension on _ToolResourceAccess {
  String get label {
    return switch (this) {
      _ToolResourceAccess.none => '-',
      _ToolResourceAccess.execute => 'EXECUTE',
      _ToolResourceAccess.read => 'READ',
      _ToolResourceAccess.write => 'WRITE',
    };
  }
}

class _WorkspacePopupButton<T> extends StatelessWidget {
  const _WorkspacePopupButton({
    required this.value,
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  final T value;
  final String label;
  final IconData icon;
  final String tooltip;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return ConfigWorkspacePopupButton<T>(
      value: value,
      label: label,
      icon: icon,
      tooltip: tooltip,
      items: items,
      itemLabel: itemLabel,
      onSelected: onSelected,
    );
  }
}

class _ToolDetailTabs extends StatelessWidget {
  const _ToolDetailTabs({required this.activeTab, required this.onTabChanged});

  final _ToolDetailTab activeTab;
  final ValueChanged<_ToolDetailTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return ConfigWorkspaceTabBar<_ToolDetailTab>(
      items: _ToolDetailTab.values,
      value: activeTab,
      labelBuilder: (_ToolDetailTab tab) => tab.label,
      onChanged: onTabChanged,
    );
  }
}

class _WorkspaceSectionCard extends StatelessWidget {
  const _WorkspaceSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConfigWorkspaceSectionCard(title: title, child: child);
  }
}

class _ManagedTextField extends StatelessWidget {
  const _ManagedTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.hintText,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return AppManagedTextField(
      label: label,
      value: value,
      maxLines: maxLines,
      hintText: hintText,
      onChanged: onChanged,
    );
  }
}

class _ManagedNumberField extends StatelessWidget {
  const _ManagedNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppManagedNumberField(
      label: label,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ToggleField extends StatelessWidget {
  const _ToggleField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x99212D41),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _JsonEditor extends StatelessWidget {
  const _JsonEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final jsonValue = const JsonEncoder.withIndent('  ').convert(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManagedTextField(
          label: label,
          value: jsonValue == '{}' ? '' : jsonValue,
          maxLines: 10,
          onChanged: (String rawValue) {
            final trimmed = rawValue.trim();
            if (trimmed.isEmpty) {
              onChanged(const <String, dynamic>{});
              return;
            }
            try {
              final decoded = jsonDecode(trimmed);
              if (decoded is Map<String, dynamic>) {
                onChanged(decoded);
              }
            } catch (_) {
              return;
            }
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter valid JSON. The editor keeps the last valid object value.',
          style: TextStyle(color: textSubtleColor),
        ),
      ],
    );
  }
}

class _LineListEditor extends StatelessWidget {
  const _LineListEditor({
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
    this.addOptions = const <String>[],
    this.addLabel,
  });

  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final List<String> addOptions;
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ManagedTextField(
          label: label,
          value: values.join('\n'),
          maxLines: 6,
          hintText: hint,
          onChanged: (String rawValue) => onChanged(_lineList(rawValue)),
        ),
        if (addOptions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                addLabel ?? 'Add',
                style: const TextStyle(
                  color: textMutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final option in addOptions)
                OutlinedButton(
                  onPressed: () => onChanged(<String>[...values, option]),
                  child: Text(option),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _KeyValueEditor extends StatelessWidget {
  const _KeyValueEditor({
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final Map<String, String> values;
  final ValueChanged<Map<String, String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final lines = values.entries
        .map((MapEntry<String, String> entry) => '${entry.key}=${entry.value}')
        .join('\n');
    return _ManagedTextField(
      label: label,
      value: lines,
      maxLines: 6,
      hintText: hint,
      onChanged: (String rawValue) => onChanged(_keyValueMap(rawValue)),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.fallbackLabel,
    required this.onChanged,
    this.labelBuilder,
  });

  final String label;
  final T value;
  final List<T> options;
  final String fallbackLabel;
  final ValueChanged<T> onChanged;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return AppDropdownField<T>(
      label: label,
      value: value,
      options: options,
      fallbackLabel: fallbackLabel,
      labelBuilder: labelBuilder,
      onChanged: (T? nextValue) {
        if (nextValue != null) {
          onChanged(nextValue);
        }
      },
    );
  }
}

class _AccessToggleGrid extends StatelessWidget {
  const _AccessToggleGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth > 620 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 14)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: children
              .map((Widget child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _ResourceAccessCard extends StatelessWidget {
  const _ResourceAccessCard({
    required this.label,
    required this.description,
    required this.enabled,
    required this.onEnabledChanged,
    required this.tone,
    this.child,
  });

  final String label;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final Color tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x85162230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Switch.adaptive(
                value: enabled,
                onChanged: onEnabledChanged,
                activeThumbColor: tone,
                activeTrackColor: tone.withValues(alpha: 0.35),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: textMutedColor, height: 1.5),
          ),
          if (child != null) ...[const SizedBox(height: 14), child!],
        ],
      ),
    );
  }
}

class _AccessMiniPill extends StatelessWidget {
  const _AccessMiniPill({required this.label, required this.mode});

  final String label;
  final _ToolResourceAccess mode;

  @override
  Widget build(BuildContext context) {
    final tone = switch (mode) {
      _ToolResourceAccess.none => textSubtleColor,
      _ToolResourceAccess.execute => successColor,
      _ToolResourceAccess.read => infoColor,
      _ToolResourceAccess.write => accentColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(
          alpha: mode == _ToolResourceAccess.none ? 0.08 : 0.16,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppReadOnlyField(label: label, value: value),
    );
  }
}

class _ToolsValidationPanel extends StatelessWidget {
  const _ToolsValidationPanel({required this.report});

  final HarnessConfigValidationReport report;

  @override
  Widget build(BuildContext context) {
    final ok = report.status.toLowerCase() == 'ok';
    final tags = <String>[
      if (report.externalToolCount > 0) 'external:${report.externalToolCount}',
      if (report.mcpServerCount > 0) 'mcp:${report.mcpServerCount}',
      if (report.toolPlatform.isNotEmpty) report.toolPlatform,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ok ? successColor : dangerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: ok ? 'Valid' : 'Invalid',
                color: ok ? successColor : dangerColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.summary.isEmpty
                      ? 'Validation finished.'
                      : report.summary,
                  style: const TextStyle(color: textPrimaryColor),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map((String tag) => StatusPill(label: tag, color: infoColor))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolWorkspaceEntry {
  const _ToolWorkspaceEntry({
    required this.id,
    required this.sourceIndex,
    required this.name,
    required this.kind,
    required this.primarySummary,
    required this.commandSummary,
    required this.url,
    required this.toolNamePrefix,
    required this.relatedGroups,
    required this.memberTools,
    required this.supportedPlatforms,
    required this.platformGroup,
    required this.filesystemAccessMode,
    required this.networkAccess,
    required this.platformOverrideCount,
    required this.searchIndex,
  });

  final String id;
  final int sourceIndex;
  final String name;
  final _ToolEntryKind kind;
  final String primarySummary;
  final String commandSummary;
  final String url;
  final String toolNamePrefix;
  final List<String> relatedGroups;
  final List<String> memberTools;
  final List<String> supportedPlatforms;
  final _ToolPlatformGroup platformGroup;
  final _ToolResourceAccess filesystemAccessMode;
  final bool networkAccess;
  final int platformOverrideCount;
  final List<String> searchIndex;

  String get platformDescription {
    if (kind == _ToolEntryKind.toolGroup) {
      return 'Platform coverage is inherited from the tools included in this group.';
    }
    if (supportedPlatforms.isEmpty) {
      return 'This entry is defined without explicit platform coverage.';
    }
    if (_samePlatforms(supportedPlatforms, _allPlatforms)) {
      return 'This entry is available across Windows, Linux, and Mac OS.';
    }
    return 'This entry is available on ${supportedPlatforms.map(_platformLongLabel).join(', ')}.';
  }

  List<String> get platformPillLabels {
    if (kind == _ToolEntryKind.toolGroup) {
      return const <String>['-'];
    }
    if (supportedPlatforms.isEmpty) {
      return const <String>['-'];
    }
    return supportedPlatforms.map(_platformPillLabel).toList();
  }

  List<String> get platformHeaderPills {
    if (kind == _ToolEntryKind.toolGroup) {
      return const <String>['-'];
    }
    return platformPillLabels;
  }

  bool supportsPlatform(String platform) {
    return supportedPlatforms.contains(platform);
  }
}

class _ToolWorkspaceSnapshot {
  const _ToolWorkspaceSnapshot({required this.entries});

  final List<_ToolWorkspaceEntry> entries;

  factory _ToolWorkspaceSnapshot.fromCatalog(HarnessToolCatalog catalog) {
    final entries = <_ToolWorkspaceEntry>[];
    final toolGroupMemberships = <String, List<String>>{};

    for (final group in catalog.toolGroups) {
      for (final toolName in group.tools) {
        toolGroupMemberships
            .putIfAbsent(toolName, () => <String>[])
            .add(group.name);
      }
    }

    final externalEntries = <String, _ToolWorkspaceEntry>{};
    for (var index = 0; index < catalog.externalTools.length; index++) {
      final tool = catalog.externalTools[index];
      final supportedPlatforms = _supportedPlatformsForExternalTool(tool);
      externalEntries[tool.name] = _ToolWorkspaceEntry(
        id: 'external:$index',
        sourceIndex: index,
        name: tool.name,
        kind: _ToolEntryKind.externalTool,
        primarySummary: blankAsUnknown(tool.filesystem),
        commandSummary: _commandSummary(
          tool.command,
          tool.platforms.values.map(
            (HarnessExternalToolPlatformSummary platform) => platform.command,
          ),
        ),
        url: '',
        toolNamePrefix: '',
        relatedGroups: toolGroupMemberships[tool.name] ?? const <String>[],
        memberTools: const <String>[],
        supportedPlatforms: supportedPlatforms,
        platformGroup: _platformGroupForPlatforms(supportedPlatforms),
        filesystemAccessMode: _filesystemAccessMode(tool.filesystem),
        networkAccess: tool.network,
        platformOverrideCount: tool.platformOverrideCount,
        searchIndex: <String>[
          tool.filesystem,
          if (tool.network) 'network',
          tool.command.join(' '),
          tool.args.join(' '),
          ...tool.platforms.keys,
        ],
      );
    }

    final mcpEntries = <String, _ToolWorkspaceEntry>{};
    for (var index = 0; index < catalog.mcpServers.length; index++) {
      final server = catalog.mcpServers[index];
      final supportedPlatforms = _supportedPlatformsForMcpServer(server);
      mcpEntries[server.name] = _ToolWorkspaceEntry(
        id: 'mcp:$index',
        sourceIndex: index,
        name: server.name,
        kind: _ToolEntryKind.mcpServer,
        primarySummary: _joinNonEmpty(<String>[
          server.lifecycle,
          server.transport,
        ]),
        commandSummary: _commandSummary(
          server.command,
          server.platforms.values.map(
            (HarnessMcpServerPlatformSummary platform) => platform.command,
          ),
        ),
        url: server.url,
        toolNamePrefix: server.toolNamePrefix,
        relatedGroups: toolGroupMemberships[server.name] ?? const <String>[],
        memberTools: const <String>[],
        supportedPlatforms: supportedPlatforms,
        platformGroup: _platformGroupForPlatforms(supportedPlatforms),
        filesystemAccessMode: _filesystemAccessMode(server.filesystem),
        networkAccess: server.network,
        platformOverrideCount: server.platformOverrideCount,
        searchIndex: <String>[
          server.lifecycle,
          server.transport,
          server.url,
          server.filesystem,
          if (server.network) 'network',
          server.command.join(' '),
          server.args.join(' '),
          server.toolNamePrefix,
          ...server.includeTools,
          ...server.excludeTools,
          ...server.platforms.keys,
        ],
      );
    }

    entries.addAll(externalEntries.values);
    entries.addAll(mcpEntries.values);

    final executableByName = <String, _ToolWorkspaceEntry>{
      ...externalEntries,
      ...mcpEntries,
    };

    for (var index = 0; index < catalog.toolGroups.length; index++) {
      final group = catalog.toolGroups[index];
      final members = group.tools
          .map((String toolName) => executableByName[toolName])
          .whereType<_ToolWorkspaceEntry>()
          .toList();
      entries.add(
        _ToolWorkspaceEntry(
          id: 'group:$index',
          sourceIndex: index,
          name: group.name,
          kind: _ToolEntryKind.toolGroup,
          primarySummary:
              '${group.tools.length} tool${group.tools.length == 1 ? '' : 's'}',
          commandSummary: '',
          url: '',
          toolNamePrefix: '',
          relatedGroups: const <String>[],
          memberTools: group.tools,
          supportedPlatforms: _aggregatePlatforms(members),
          platformGroup: _ToolPlatformGroup.toolGroups,
          filesystemAccessMode: _mergeResourceAccess(
            members.map(
              (_ToolWorkspaceEntry entry) => entry.filesystemAccessMode,
            ),
          ),
          networkAccess: _mergeNetworkAccess(
            members.map((_ToolWorkspaceEntry entry) => entry.networkAccess),
          ),
          platformOverrideCount: members.fold<int>(
            0,
            (int total, _ToolWorkspaceEntry member) =>
                total + member.platformOverrideCount,
          ),
          searchIndex: <String>[...group.tools],
        ),
      );
    }

    entries.sort(
      (_ToolWorkspaceEntry left, _ToolWorkspaceEntry right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return _ToolWorkspaceSnapshot(entries: entries);
  }
}

String _commandSummary(
  List<String> primary,
  Iterable<List<String>> overrideCommands,
) {
  if (primary.isNotEmpty) {
    return primary.join(' ');
  }
  for (final command in overrideCommands) {
    if (command.isNotEmpty) {
      return command.join(' ');
    }
  }
  return '';
}

List<String> _supportedPlatformsForExternalTool(
  HarnessExternalToolSummary tool,
) {
  return _supportedPlatformsFromOverrides(
    tool.platforms.keys,
    fallbackToAllPlatforms:
        tool.platforms.isEmpty || tool.platforms.containsKey('default'),
  );
}

List<String> _supportedPlatformsForMcpServer(HarnessMcpServerSummary server) {
  return _supportedPlatformsFromOverrides(
    server.platforms.keys,
    fallbackToAllPlatforms:
        server.platforms.isEmpty || server.platforms.containsKey('default'),
  );
}

List<String> _supportedPlatformsFromOverrides(
  Iterable<String> keys, {
  required bool fallbackToAllPlatforms,
}) {
  final platforms = <String>{};
  for (final key in keys) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) {
      continue;
    }
    if (normalized == 'default') {
      platforms.addAll(_allPlatforms);
      continue;
    }
    platforms.add(normalized);
  }
  if (platforms.isEmpty && fallbackToAllPlatforms) {
    platforms.addAll(_allPlatforms);
  }
  final result = platforms.toList()..sort();
  return result;
}

HarnessExternalToolSummary _setExternalToolPlatformCoverage(
  HarnessExternalToolSummary tool,
  String platform,
  bool enabled,
) {
  final normalizedPlatform = platform.trim().toLowerCase();
  final supported = _supportedPlatformsForExternalTool(tool).toSet();
  final nextPlatforms = Map<String, HarnessExternalToolPlatformSummary>.from(
    tool.platforms,
  );
  if (enabled) {
    if (supported.contains(normalizedPlatform)) {
      return tool;
    }
    nextPlatforms[normalizedPlatform] = _externalRuntimeBase(tool);
    return tool.copyWith(platforms: nextPlatforms);
  }
  if (!supported.contains(normalizedPlatform)) {
    return tool;
  }
  if (nextPlatforms.containsKey('default') &&
      _allPlatforms.contains(normalizedPlatform)) {
    final defaultValue =
        nextPlatforms.remove('default') ?? _externalRuntimeBase(tool);
    for (final candidate in _allPlatforms) {
      if (candidate == normalizedPlatform) {
        continue;
      }
      nextPlatforms.putIfAbsent(candidate, () => defaultValue);
    }
    return tool.copyWith(platforms: nextPlatforms);
  }
  if (nextPlatforms.isEmpty && _allPlatforms.contains(normalizedPlatform)) {
    final base = _externalRuntimeBase(tool);
    for (final candidate in _allPlatforms) {
      if (candidate == normalizedPlatform) {
        continue;
      }
      nextPlatforms[candidate] = base;
    }
    return _externalToolWithoutBaseRuntime(
      tool,
    ).copyWith(platforms: nextPlatforms);
  }
  nextPlatforms.remove(normalizedPlatform);
  return tool.copyWith(platforms: nextPlatforms);
}

HarnessMcpServerSummary _setMcpServerPlatformCoverage(
  HarnessMcpServerSummary server,
  String platform,
  bool enabled,
) {
  final normalizedPlatform = platform.trim().toLowerCase();
  final supported = _supportedPlatformsForMcpServer(server).toSet();
  final nextPlatforms = Map<String, HarnessMcpServerPlatformSummary>.from(
    server.platforms,
  );
  if (enabled) {
    if (supported.contains(normalizedPlatform)) {
      return server;
    }
    nextPlatforms[normalizedPlatform] = _mcpRuntimeBase(server);
    return server.copyWith(platforms: nextPlatforms);
  }
  if (!supported.contains(normalizedPlatform)) {
    return server;
  }
  if (nextPlatforms.containsKey('default') &&
      _allPlatforms.contains(normalizedPlatform)) {
    final defaultValue =
        nextPlatforms.remove('default') ?? _mcpRuntimeBase(server);
    for (final candidate in _allPlatforms) {
      if (candidate == normalizedPlatform) {
        continue;
      }
      nextPlatforms.putIfAbsent(candidate, () => defaultValue);
    }
    return server.copyWith(platforms: nextPlatforms);
  }
  if (nextPlatforms.isEmpty && _allPlatforms.contains(normalizedPlatform)) {
    final base = _mcpRuntimeBase(server);
    for (final candidate in _allPlatforms) {
      if (candidate == normalizedPlatform) {
        continue;
      }
      nextPlatforms[candidate] = base;
    }
    return _mcpServerWithoutBaseRuntime(
      server,
    ).copyWith(platforms: nextPlatforms);
  }
  nextPlatforms.remove(normalizedPlatform);
  return server.copyWith(platforms: nextPlatforms);
}

HarnessExternalToolPlatformSummary _externalRuntimeBase(
  HarnessExternalToolSummary tool,
) {
  final firstPlatform = tool.platforms.values.isNotEmpty
      ? tool.platforms.values.first
      : null;
  return tool.platforms['default'] ??
      firstPlatform ??
      HarnessExternalToolPlatformSummary(
        timeoutSeconds: tool.timeoutSeconds,
        command: tool.command,
        args: tool.args,
        workingDir: tool.workingDir,
        env: tool.env,
        stdinMode: tool.stdinMode,
        tempFiles: tool.tempFiles,
        outputFormat: tool.outputFormat,
      );
}

HarnessMcpServerPlatformSummary _mcpRuntimeBase(
  HarnessMcpServerSummary server,
) {
  final firstPlatform = server.platforms.values.isNotEmpty
      ? server.platforms.values.first
      : null;
  return server.platforms['default'] ??
      firstPlatform ??
      HarnessMcpServerPlatformSummary(
        lifecycle: server.lifecycle,
        transport: server.transport,
        url: server.url,
        healthcheckUrl: server.healthcheckUrl,
        command: server.command,
        args: server.args,
        workingDir: server.workingDir,
        env: server.env,
        timeoutSeconds: server.timeoutSeconds,
        startupTimeoutSeconds: server.startupTimeoutSeconds,
        shutdownTimeoutSeconds: server.shutdownTimeoutSeconds,
      );
}

HarnessExternalToolSummary _externalToolWithoutBaseRuntime(
  HarnessExternalToolSummary tool,
) {
  return tool.copyWith(
    timeoutSeconds: 0,
    command: const <String>[],
    args: const <String>[],
    workingDir: '',
    env: const <String, String>{},
    stdinMode: '',
    tempFiles: const <HarnessExternalToolTempFile>[],
    outputFormat: '',
  );
}

HarnessMcpServerSummary _mcpServerWithoutBaseRuntime(
  HarnessMcpServerSummary server,
) {
  return server.copyWith(
    lifecycle: '',
    transport: '',
    url: '',
    healthcheckUrl: '',
    command: const <String>[],
    args: const <String>[],
    workingDir: '',
    env: const <String, String>{},
    timeoutSeconds: 0,
    startupTimeoutSeconds: 0,
    shutdownTimeoutSeconds: 0,
  );
}

_ToolPlatformGroup _platformGroupForPlatforms(List<String> supportedPlatforms) {
  final normalized = supportedPlatforms.toSet().toList()..sort();
  if (_samePlatforms(normalized, _allPlatforms)) {
    return _ToolPlatformGroup.allPlatforms;
  }
  if (normalized.length == 1) {
    return switch (normalized.first) {
      'linux' => _ToolPlatformGroup.linuxOnly,
      'darwin' => _ToolPlatformGroup.macOsOnly,
      'windows' => _ToolPlatformGroup.windowsOnly,
      _ => _ToolPlatformGroup.customPlatforms,
    };
  }
  return _ToolPlatformGroup.customPlatforms;
}

bool _samePlatforms(List<String> left, List<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

List<String> _aggregatePlatforms(List<_ToolWorkspaceEntry> members) {
  final platforms = <String>{};
  for (final member in members) {
    platforms.addAll(member.supportedPlatforms);
  }
  final result = platforms.toList()..sort();
  return result;
}

const List<String> _allPlatforms = <String>['darwin', 'linux', 'windows'];
const List<String> _coveragePlatforms = <String>[
  'darwin',
  'linux',
  'windows',
  'bsd',
];

_ToolResourceAccess _filesystemAccessMode(String filesystem) {
  switch (filesystem.trim().toLowerCase()) {
    case 'write':
      return _ToolResourceAccess.write;
    case 'read':
      return _ToolResourceAccess.read;
    case 'execute':
      return _ToolResourceAccess.execute;
    default:
      return _ToolResourceAccess.none;
  }
}

_ToolResourceAccess _mergeResourceAccess(
  Iterable<_ToolResourceAccess> accessModes,
) {
  var merged = _ToolResourceAccess.none;
  for (final mode in accessModes) {
    if (mode == _ToolResourceAccess.write) {
      return _ToolResourceAccess.write;
    }
    if (mode == _ToolResourceAccess.read) {
      merged = _ToolResourceAccess.read;
      continue;
    }
    if (mode == _ToolResourceAccess.execute &&
        merged == _ToolResourceAccess.none) {
      merged = _ToolResourceAccess.execute;
    }
  }
  return merged;
}

bool _mergeNetworkAccess(Iterable<bool> values) {
  for (final value in values) {
    if (value) {
      return true;
    }
  }
  return false;
}

String _platformPillLabel(String platform) {
  switch (platform.trim().toLowerCase()) {
    case 'windows':
    case 'win':
      return 'Win';
    case 'linux':
      return 'Linux';
    case 'darwin':
    case 'mac':
    case 'macos':
    case 'osx':
      return 'Mac';
    case 'bsd':
    case 'freebsd':
    case 'openbsd':
    case 'netbsd':
      return 'BSD';
    default:
      return _titleCase(platform);
  }
}

List<String> _panelPlatformPills(_ToolWorkspaceEntry entry) {
  if (entry.supportedPlatforms.isEmpty) {
    return const <String>['-'];
  }
  return entry.supportedPlatforms
      .map(_platformPillLabel)
      .toList(growable: false);
}

String _platformLongLabel(String platform) {
  switch (platform.trim().toLowerCase()) {
    case 'windows':
    case 'win':
      return 'Windows';
    case 'linux':
      return 'Linux';
    case 'darwin':
    case 'mac':
    case 'macos':
    case 'osx':
      return 'Mac OS';
    case 'bsd':
    case 'freebsd':
    case 'openbsd':
    case 'netbsd':
      return 'BSD';
    default:
      return _titleCase(platform);
  }
}

String _platformEditorTitle(String key) {
  switch (key.trim().toLowerCase()) {
    case 'default':
      return 'Default';
    case 'darwin':
      return 'Mac OS';
    case 'linux':
      return 'Linux';
    case 'windows':
      return 'Windows';
    case 'bsd':
    case 'freebsd':
    case 'openbsd':
    case 'netbsd':
      return 'BSD';
    default:
      return _titleCase(key);
  }
}

String _normalizedPlatformKey(String key) {
  switch (key.trim().toLowerCase()) {
    case 'default':
      return 'default';
    case 'darwin':
    case 'mac':
    case 'macos':
    case 'osx':
      return 'darwin';
    case 'linux':
      return 'linux';
    case 'windows':
    case 'win':
      return 'windows';
    case 'bsd':
    case 'freebsd':
    case 'openbsd':
    case 'netbsd':
      return 'bsd';
    default:
      return key.trim().toLowerCase();
  }
}

String _titleCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

List<String> _editablePlatformKeys(Iterable<String> existingKeys) {
  final keys = existingKeys.toSet().toList();
  keys.sort((String left, String right) {
    return _platformSortKey(left).compareTo(_platformSortKey(right));
  });
  return keys;
}

String _platformSortKey(String key) {
  return switch (_normalizedPlatformKey(key)) {
    'linux' => '1-linux',
    'darwin' => '2-darwin',
    'windows' => '3-windows',
    'bsd' => '4-bsd',
    'default' => '9-default',
    _ => '5-${key.toLowerCase()}',
  };
}

class _PlatformPanelOption {
  const _PlatformPanelOption({required this.key, required this.exists});

  final String key;
  final bool exists;
}

List<_PlatformPanelOption> _platformPanelOptions(
  Iterable<String> existingKeys,
) {
  final existing = _editablePlatformKeys(existingKeys);
  final existingByNormalized = <String, String>{};
  for (final key in existing) {
    existingByNormalized.putIfAbsent(_normalizedPlatformKey(key), () => key);
  }

  final options = <_PlatformPanelOption>[];
  final used = <String>{};
  for (final option in const <String>[
    'default',
    'linux',
    'darwin',
    'windows',
    'bsd',
  ]) {
    final existingKey = existingByNormalized[option];
    if (existingKey != null) {
      options.add(_PlatformPanelOption(key: existingKey, exists: true));
      used.add(existingKey);
      continue;
    }
    options.add(_PlatformPanelOption(key: option, exists: false));
  }

  for (final key in existing) {
    if (!used.contains(key)) {
      options.add(_PlatformPanelOption(key: key, exists: true));
    }
  }

  return options;
}

String? _resolvePlatformPanelKey(
  String? selectedKey,
  Iterable<String> existingKeys,
) {
  final existingOptions = _platformPanelOptions(
    existingKeys,
  ).where((option) => option.exists).toList();
  if (existingOptions.isEmpty) {
    return null;
  }
  if (selectedKey == null) {
    return existingOptions.first.key;
  }
  final normalizedSelected = _normalizedPlatformKey(selectedKey);
  for (final option in existingOptions) {
    if (_normalizedPlatformKey(option.key) == normalizedSelected) {
      return option.key;
    }
  }
  return existingOptions.first.key;
}

List<String> _lineList(String rawValue) {
  return rawValue
      .split('\n')
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();
}

Map<String, String> _keyValueMap(String rawValue) {
  final values = <String, String>{};
  for (final line in rawValue.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final splitIndex = trimmed.indexOf('=');
    if (splitIndex == -1) {
      continue;
    }
    final key = trimmed.substring(0, splitIndex).trim();
    final value = trimmed.substring(splitIndex + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      values[key] = value;
    }
  }
  return values;
}

String _joinNonEmpty(Iterable<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' • ');
}

String _entryYamlDocument(
  HarnessToolCatalog catalog,
  _ToolWorkspaceEntry entry,
) {
  final document = switch (entry.kind) {
    _ToolEntryKind.toolGroup => <String, dynamic>{
      'tools': <String, dynamic>{
        'tool_groups': <Map<String, dynamic>>[
          catalog.toolGroups[entry.sourceIndex].toJson(),
        ],
      },
    },
    _ToolEntryKind.externalTool => <String, dynamic>{
      'tools': <String, dynamic>{
        'external_tools': <Map<String, dynamic>>[
          catalog.externalTools[entry.sourceIndex].toJson(),
        ],
      },
    },
    _ToolEntryKind.mcpServer => <String, dynamic>{
      'tools': <String, dynamic>{
        'mcp_servers': <Map<String, dynamic>>[
          catalog.mcpServers[entry.sourceIndex].toJson(),
        ],
      },
    },
  };
  return _yamlDocument(document);
}

String _yamlDocument(Map<String, dynamic> value) {
  return _yamlLines(value, 0).join('\n');
}

List<String> _yamlLines(Object? value, int indent) {
  final prefix = ' ' * indent;
  if (value is Map<String, dynamic>) {
    final lines = <String>[];
    for (final entry in value.entries) {
      if (entry.value is Map<String, dynamic> || entry.value is List<dynamic>) {
        lines.add('$prefix${entry.key}:');
        lines.addAll(_yamlLines(entry.value, indent + 2));
      } else {
        lines.add('$prefix${entry.key}: ${_yamlScalar(entry.value)}');
      }
    }
    return lines;
  }
  if (value is List<dynamic>) {
    if (value.isEmpty) {
      return <String>['$prefix[]'];
    }
    final lines = <String>[];
    for (final item in value) {
      if (item is Map<String, dynamic> || item is List<dynamic>) {
        lines.add('$prefix-');
        lines.addAll(_yamlLines(item, indent + 2));
      } else {
        lines.add('$prefix- ${_yamlScalar(item)}');
      }
    }
    return lines;
  }
  return <String>['$prefix${_yamlScalar(value)}'];
}

String _yamlScalar(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is bool || value is num) {
    return value.toString();
  }
  final stringValue = value.toString();
  final escaped = stringValue
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
}

extension on HarnessToolCatalog {
  HarnessToolCatalog copyWith({
    String? configPath,
    String? yaml,
    List<HarnessToolGroupSummary>? toolGroups,
    List<HarnessExternalToolSummary>? externalTools,
    List<HarnessMcpServerSummary>? mcpServers,
  }) {
    return HarnessToolCatalog(
      configPath: configPath ?? this.configPath,
      yaml: yaml ?? this.yaml,
      toolGroups: toolGroups ?? this.toolGroups,
      externalTools: externalTools ?? this.externalTools,
      mcpServers: mcpServers ?? this.mcpServers,
    );
  }
}

extension on HarnessToolGroupSummary {
  HarnessToolGroupSummary copyWith({String? name, List<String>? tools}) {
    return HarnessToolGroupSummary(
      name: name ?? this.name,
      tools: tools ?? this.tools,
    );
  }
}

extension on HarnessExternalToolTempFile {
  HarnessExternalToolTempFile copyWith({
    String? name,
    String? inputKey,
    String? format,
    String? suffix,
    bool? required,
  }) {
    return HarnessExternalToolTempFile(
      name: name ?? this.name,
      inputKey: inputKey ?? this.inputKey,
      format: format ?? this.format,
      suffix: suffix ?? this.suffix,
      required: required ?? this.required,
    );
  }
}

extension on HarnessExternalToolPlatformSummary {
  HarnessExternalToolPlatformSummary copyWith({
    int? timeoutSeconds,
    List<String>? command,
    List<String>? args,
    String? workingDir,
    Map<String, String>? env,
    String? stdinMode,
    List<HarnessExternalToolTempFile>? tempFiles,
    String? outputFormat,
  }) {
    return HarnessExternalToolPlatformSummary(
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      command: command ?? this.command,
      args: args ?? this.args,
      workingDir: workingDir ?? this.workingDir,
      env: env ?? this.env,
      stdinMode: stdinMode ?? this.stdinMode,
      tempFiles: tempFiles ?? this.tempFiles,
      outputFormat: outputFormat ?? this.outputFormat,
    );
  }
}

extension on HarnessExternalToolSummary {
  HarnessExternalToolSummary copyWith({
    String? name,
    Map<String, dynamic>? inputSchema,
    String? filesystem,
    bool? network,
    bool? idempotent,
    int? timeoutSeconds,
    List<String>? command,
    List<String>? args,
    String? workingDir,
    Map<String, String>? env,
    bool? inheritEnv,
    String? stdinMode,
    List<HarnessExternalToolTempFile>? tempFiles,
    String? outputFormat,
    Map<String, HarnessExternalToolPlatformSummary>? platforms,
  }) {
    return HarnessExternalToolSummary(
      name: name ?? this.name,
      inputSchema: inputSchema ?? this.inputSchema,
      filesystem: filesystem ?? this.filesystem,
      network: network ?? this.network,
      idempotent: idempotent ?? this.idempotent,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      command: command ?? this.command,
      args: args ?? this.args,
      workingDir: workingDir ?? this.workingDir,
      env: env ?? this.env,
      inheritEnv: inheritEnv ?? this.inheritEnv,
      stdinMode: stdinMode ?? this.stdinMode,
      tempFiles: tempFiles ?? this.tempFiles,
      outputFormat: outputFormat ?? this.outputFormat,
      platforms: platforms ?? this.platforms,
    );
  }
}

extension on HarnessMcpServerPlatformSummary {
  HarnessMcpServerPlatformSummary copyWith({
    String? lifecycle,
    String? transport,
    String? url,
    String? healthcheckUrl,
    List<String>? command,
    List<String>? args,
    String? workingDir,
    Map<String, String>? env,
    int? timeoutSeconds,
    int? startupTimeoutSeconds,
    int? shutdownTimeoutSeconds,
  }) {
    return HarnessMcpServerPlatformSummary(
      lifecycle: lifecycle ?? this.lifecycle,
      transport: transport ?? this.transport,
      url: url ?? this.url,
      healthcheckUrl: healthcheckUrl ?? this.healthcheckUrl,
      command: command ?? this.command,
      args: args ?? this.args,
      workingDir: workingDir ?? this.workingDir,
      env: env ?? this.env,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      startupTimeoutSeconds:
          startupTimeoutSeconds ?? this.startupTimeoutSeconds,
      shutdownTimeoutSeconds:
          shutdownTimeoutSeconds ?? this.shutdownTimeoutSeconds,
    );
  }
}

extension on HarnessMcpServerSummary {
  HarnessMcpServerSummary copyWith({
    String? name,
    String? lifecycle,
    String? transport,
    String? url,
    String? healthcheckUrl,
    List<String>? command,
    List<String>? args,
    String? workingDir,
    Map<String, String>? env,
    bool? inheritEnv,
    int? timeoutSeconds,
    int? startupTimeoutSeconds,
    int? shutdownTimeoutSeconds,
    String? toolNamePrefix,
    List<String>? includeTools,
    List<String>? excludeTools,
    String? filesystem,
    bool? network,
    bool? idempotent,
    Map<String, HarnessMcpServerPlatformSummary>? platforms,
  }) {
    return HarnessMcpServerSummary(
      name: name ?? this.name,
      lifecycle: lifecycle ?? this.lifecycle,
      transport: transport ?? this.transport,
      url: url ?? this.url,
      healthcheckUrl: healthcheckUrl ?? this.healthcheckUrl,
      command: command ?? this.command,
      args: args ?? this.args,
      workingDir: workingDir ?? this.workingDir,
      env: env ?? this.env,
      inheritEnv: inheritEnv ?? this.inheritEnv,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      startupTimeoutSeconds:
          startupTimeoutSeconds ?? this.startupTimeoutSeconds,
      shutdownTimeoutSeconds:
          shutdownTimeoutSeconds ?? this.shutdownTimeoutSeconds,
      toolNamePrefix: toolNamePrefix ?? this.toolNamePrefix,
      includeTools: includeTools ?? this.includeTools,
      excludeTools: excludeTools ?? this.excludeTools,
      filesystem: filesystem ?? this.filesystem,
      network: network ?? this.network,
      idempotent: idempotent ?? this.idempotent,
      platforms: platforms ?? this.platforms,
    );
  }
}

HarnessMcpServerPlatformSummary _externalPlatformToMcpPlatform(
  HarnessExternalToolPlatformSummary platform,
) {
  return HarnessMcpServerPlatformSummary(
    lifecycle: '',
    transport: '',
    url: '',
    healthcheckUrl: '',
    command: platform.command,
    args: platform.args,
    workingDir: platform.workingDir,
    env: platform.env,
    timeoutSeconds: platform.timeoutSeconds,
    startupTimeoutSeconds: 0,
    shutdownTimeoutSeconds: 0,
  );
}

HarnessExternalToolPlatformSummary _mcpPlatformToExternalPlatform(
  HarnessMcpServerPlatformSummary platform,
) {
  return HarnessExternalToolPlatformSummary(
    timeoutSeconds: platform.timeoutSeconds,
    command: platform.command,
    args: platform.args,
    workingDir: platform.workingDir,
    env: platform.env,
    stdinMode: '',
    tempFiles: const <HarnessExternalToolTempFile>[],
    outputFormat: '',
  );
}

HarnessMcpServerSummary _externalToolToMcpServer(
  HarnessExternalToolSummary tool, {
  required String name,
}) {
  return HarnessMcpServerSummary(
    name: name,
    lifecycle: 'persistent',
    transport: 'stdio',
    url: '',
    healthcheckUrl: '',
    command: tool.command,
    args: tool.args,
    workingDir: tool.workingDir,
    env: tool.env,
    inheritEnv: tool.inheritEnv,
    timeoutSeconds: tool.timeoutSeconds,
    startupTimeoutSeconds: 30,
    shutdownTimeoutSeconds: 15,
    toolNamePrefix: '',
    includeTools: const <String>[],
    excludeTools: const <String>[],
    filesystem: tool.filesystem,
    network: tool.network,
    idempotent: tool.idempotent,
    platforms: Map<String, HarnessMcpServerPlatformSummary>.fromEntries(
      tool.platforms.entries.map(
        (MapEntry<String, HarnessExternalToolPlatformSummary> entry) =>
            MapEntry<String, HarnessMcpServerPlatformSummary>(
              entry.key,
              _externalPlatformToMcpPlatform(entry.value),
            ),
      ),
    ),
  );
}

HarnessExternalToolSummary _mcpServerToExternalTool(
  HarnessMcpServerSummary server, {
  required String name,
}) {
  return HarnessExternalToolSummary(
    name: name,
    inputSchema: const <String, dynamic>{},
    filesystem: server.filesystem,
    network: server.network,
    idempotent: server.idempotent,
    timeoutSeconds: server.timeoutSeconds,
    command: server.command,
    args: server.args,
    workingDir: server.workingDir,
    env: server.env,
    inheritEnv: server.inheritEnv,
    stdinMode: '',
    tempFiles: const <HarnessExternalToolTempFile>[],
    outputFormat: 'text',
    platforms: Map<String, HarnessExternalToolPlatformSummary>.fromEntries(
      server.platforms.entries.map(
        (MapEntry<String, HarnessMcpServerPlatformSummary> entry) =>
            MapEntry<String, HarnessExternalToolPlatformSummary>(
              entry.key,
              _mcpPlatformToExternalPlatform(entry.value),
            ),
      ),
    ),
  );
}

class _ToolsCollectionPane extends StatelessWidget {
  const _ToolsCollectionPane({
    required this.entriesByKind,
    required this.initialSectionId,
    required this.platformFilter,
    required this.sortMode,
    required this.selectedEntryId,
    required this.onSectionChanged,
    required this.onPlatformFilterChanged,
    required this.onSortModeChanged,
    required this.onSelectEntry,
    required this.onCreateToolGroup,
    required this.onCreateExternalTool,
    required this.onCreateMcpServer,
  });

  final Map<_ToolEntryKind, List<_ToolWorkspaceEntry>> entriesByKind;
  final String? initialSectionId;
  final _ToolPlatformFilter platformFilter;
  final _ToolSortMode sortMode;
  final String? selectedEntryId;
  final ValueChanged<_ToolEntryKind> onSectionChanged;
  final ValueChanged<_ToolPlatformFilter> onPlatformFilterChanged;
  final ValueChanged<_ToolSortMode> onSortModeChanged;
  final ValueChanged<_ToolWorkspaceEntry> onSelectEntry;
  final VoidCallback onCreateToolGroup;
  final VoidCallback onCreateExternalTool;
  final VoidCallback onCreateMcpServer;

  String _subtitleForEntry(_ToolWorkspaceEntry entry) {
    switch (entry.kind) {
      case _ToolEntryKind.toolGroup:
        final previewMembers = entry.memberTools
            .take(3)
            .toList(growable: false);
        final memberSummary = previewMembers.isEmpty
            ? ''
            : previewMembers.join(', ');
        return _joinNonEmpty(<String>[entry.primarySummary, memberSummary]);
      case _ToolEntryKind.externalTool:
        return _joinNonEmpty(<String>[
          entry.primarySummary,
          blankAsUnknown(entry.commandSummary),
        ]);
      case _ToolEntryKind.mcpServer:
        return _joinNonEmpty(<String>[
          entry.primarySummary,
          entry.url.isNotEmpty
              ? entry.url
              : blankAsUnknown(entry.commandSummary),
        ]);
    }
  }

  List<Widget> _footerForEntry(_ToolWorkspaceEntry entry) {
    final footer = <Widget>[
      for (final label in _panelPlatformPills(entry))
        StatusPill(label: label, color: infoColor),
      _AccessMiniPill(
        label: 'FS:${entry.filesystemAccessMode.label}',
        mode: entry.filesystemAccessMode,
      ),
      _AccessMiniPill(
        label: entry.networkAccess ? 'NET:ACCESS' : 'NET:-',
        mode: entry.networkAccess
            ? _ToolResourceAccess.execute
            : _ToolResourceAccess.none,
      ),
    ];

    if (entry.kind == _ToolEntryKind.toolGroup) {
      footer.add(
        StatusPill(
          label:
              '${entry.memberTools.length} member${entry.memberTools.length == 1 ? '' : 's'}',
          color: warningColor,
        ),
      );
    } else if (entry.relatedGroups.isNotEmpty) {
      footer.add(
        StatusPill(
          label:
              '${entry.relatedGroups.length} group${entry.relatedGroups.length == 1 ? '' : 's'}',
          color: accentColor,
        ),
      );
    }

    if (entry.toolNamePrefix.isNotEmpty) {
      footer.add(StatusPill(label: entry.toolNamePrefix, color: successColor));
    }
    return footer;
  }

  VoidCallback _onCreateForKind(_ToolEntryKind kind) {
    return switch (kind) {
      _ToolEntryKind.toolGroup => onCreateToolGroup,
      _ToolEntryKind.externalTool => onCreateExternalTool,
      _ToolEntryKind.mcpServer => onCreateMcpServer,
    };
  }

  Widget _buildCreateButton(_ToolEntryKind kind) {
    return FilledButton.icon(
      onPressed: _onCreateForKind(kind),
      icon: Icon(kind.createIcon),
      label: Text(kind.createLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDenseSidePanel<_ToolWorkspaceEntry>(
      initialSectionId: initialSectionId,
      selectedEntryId: selectedEntryId,
      entryId: (_ToolWorkspaceEntry entry) => entry.id,
      onSelectEntry: onSelectEntry,
      searchHintText: 'Filter tool groups, CLI tools, and MCP servers...',
      emptyTitle: 'No tool panels',
      emptyBody: 'Tool sections will appear here once data is loaded.',
      onSectionChanged: (String sectionId) {
        onSectionChanged(
          _ToolEntryKind.values.firstWhere(
            (_ToolEntryKind kind) => kind.sectionId == sectionId,
          ),
        );
      },
      sections: _ToolEntryKind.values
          .map((_ToolEntryKind kind) {
            final entries =
                entriesByKind[kind] ?? const <_ToolWorkspaceEntry>[];
            return AppDenseSidePanelSection<_ToolWorkspaceEntry>(
              id: kind.sectionId,
              label: kind.panelLabel,
              icon: kind.panelIcon,
              entries: entries,
              quickActionsBuilder: (BuildContext context, String searchQuery) {
                return _buildCreateButton(kind);
              },
              searchFields: (_ToolWorkspaceEntry entry) => <String>[
                entry.name,
                entry.kind.label,
                entry.primarySummary,
                entry.commandSummary,
                entry.url,
                entry.toolNamePrefix,
                ...entry.relatedGroups,
                ...entry.memberTools,
                ...entry.searchIndex,
                ...entry.supportedPlatforms,
              ],
              emptyTitle: 'No matching ${kind.emptyLabel}',
              emptyBody: platformFilter == _ToolPlatformFilter.all
                  ? 'Try a different search term to find ${kind.emptySearchDescription}.'
                  : 'Try a different search term or clear the platform filter to find ${kind.emptySearchDescription}.',
              headerBuilder: (BuildContext context, _, __, ___) {
                return _ToolSectionToolbar(
                  platformFilter: platformFilter,
                  sortMode: sortMode,
                  onPlatformFilterChanged: onPlatformFilterChanged,
                  onSortModeChanged: onSortModeChanged,
                );
              },
              rowBuilder:
                  (
                    BuildContext context,
                    _ToolWorkspaceEntry entry,
                    bool selected,
                    VoidCallback onTap,
                  ) {
                    return AppDenseSidePanelRow(
                      title: entry.name,
                      subtitle: _subtitleForEntry(entry),
                      selected: selected,
                      onTap: onTap,
                      trailing: StatusPill(
                        label: entry.kind.label,
                        color: entry.kind.tone,
                      ),
                      footer: _footerForEntry(entry),
                    );
                  },
            );
          })
          .toList(growable: false),
    );
  }
}

class _ToolSectionToolbar extends StatelessWidget {
  const _ToolSectionToolbar({
    required this.platformFilter,
    required this.sortMode,
    required this.onPlatformFilterChanged,
    required this.onSortModeChanged,
  });

  final _ToolPlatformFilter platformFilter;
  final _ToolSortMode sortMode;
  final ValueChanged<_ToolPlatformFilter> onPlatformFilterChanged;
  final ValueChanged<_ToolSortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _WorkspacePopupButton<_ToolPlatformFilter>(
          value: platformFilter,
          label: 'Platform: ${platformFilter.label}',
          icon: Icons.devices_outlined,
          tooltip: 'Filter by platform coverage',
          items: _ToolPlatformFilter.values,
          itemLabel: (_ToolPlatformFilter value) => value.label,
          onSelected: onPlatformFilterChanged,
        ),
        _WorkspacePopupButton<_ToolSortMode>(
          value: sortMode,
          label: sortMode.label,
          icon: Icons.swap_vert_rounded,
          tooltip: 'Sort tools',
          items: const <_ToolSortMode>[
            _ToolSortMode.name,
            _ToolSortMode.platform,
          ],
          itemLabel: (_ToolSortMode value) => value.label,
          onSelected: onSortModeChanged,
        ),
      ],
    );
  }
}

class _ToolDetailPane extends StatelessWidget {
  const _ToolDetailPane({
    required this.catalog,
    required this.configPath,
    required this.selectedEntry,
    required this.activeTab,
    required this.validation,
    required this.onTabChanged,
    required this.onReplaceToolGroup,
    required this.onReplaceExternalTool,
    required this.onReplaceMcpServer,
    required this.onChangeEntryKind,
    required this.onDeleteEntry,
  });

  final HarnessToolCatalog catalog;
  final String configPath;
  final _ToolWorkspaceEntry? selectedEntry;
  final _ToolDetailTab activeTab;
  final HarnessConfigValidationReport? validation;
  final ValueChanged<_ToolDetailTab> onTabChanged;
  final void Function(int index, HarnessToolGroupSummary value)
  onReplaceToolGroup;
  final void Function(int index, HarnessExternalToolSummary value)
  onReplaceExternalTool;
  final void Function(int index, HarnessMcpServerSummary value)
  onReplaceMcpServer;
  final void Function(_ToolWorkspaceEntry entry, _ToolEntryKind value)
  onChangeEntryKind;
  final ValueChanged<_ToolWorkspaceEntry> onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    if (selectedEntry == null) {
      return const Center(
        child: EmptyState(
          title: 'No tool selected',
          body: 'Pick a tool, MCP server, or tool group to inspect it here.',
        ),
      );
    }

    final entry = selectedEntry!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: textPrimaryColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Delete entry',
                    onPressed: () => onDeleteEntry(entry),
                    color: dangerColor,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        _ToolDetailTabs(activeTab: activeTab, onTabChanged: onTabChanged),
        Expanded(
          child: switch (activeTab) {
            _ToolDetailTab.overview => _ToolOverviewTab(
              catalog: catalog,
              entry: entry,
              configPath: configPath,
              onReplaceToolGroup: onReplaceToolGroup,
              onReplaceExternalTool: onReplaceExternalTool,
              onReplaceMcpServer: onReplaceMcpServer,
              onChangeEntryKind: onChangeEntryKind,
            ),
            _ToolDetailTab.access => _ToolAccessTab(
              catalog: catalog,
              entry: entry,
              onReplaceToolGroup: onReplaceToolGroup,
              onReplaceExternalTool: onReplaceExternalTool,
              onReplaceMcpServer: onReplaceMcpServer,
            ),
            _ToolDetailTab.runtime => _ToolRuntimeTab(
              catalog: catalog,
              entry: entry,
              onReplaceExternalTool: onReplaceExternalTool,
              onReplaceMcpServer: onReplaceMcpServer,
            ),
            _ToolDetailTab.document => _ToolDocumentTab(
              catalog: catalog,
              entry: entry,
              configPath: configPath,
              validation: validation,
              onReplaceExternalTool: onReplaceExternalTool,
              onReplaceMcpServer: onReplaceMcpServer,
            ),
          },
        ),
      ],
    );
  }
}

class _ToolOverviewTab extends StatelessWidget {
  const _ToolOverviewTab({
    required this.catalog,
    required this.entry,
    required this.configPath,
    required this.onReplaceToolGroup,
    required this.onReplaceExternalTool,
    required this.onReplaceMcpServer,
    required this.onChangeEntryKind,
  });

  final HarnessToolCatalog catalog;
  final _ToolWorkspaceEntry entry;
  final String configPath;
  final void Function(int index, HarnessToolGroupSummary value)
  onReplaceToolGroup;
  final void Function(int index, HarnessExternalToolSummary value)
  onReplaceExternalTool;
  final void Function(int index, HarnessMcpServerSummary value)
  onReplaceMcpServer;
  final void Function(_ToolWorkspaceEntry entry, _ToolEntryKind value)
  onChangeEntryKind;

  @override
  Widget build(BuildContext context) {
    void updateName(String value) {
      final nextName = value.trim();
      switch (entry.kind) {
        case _ToolEntryKind.toolGroup:
          onReplaceToolGroup(
            entry.sourceIndex,
            catalog.toolGroups[entry.sourceIndex].copyWith(name: nextName),
          );
        case _ToolEntryKind.externalTool:
          onReplaceExternalTool(
            entry.sourceIndex,
            catalog.externalTools[entry.sourceIndex].copyWith(name: nextName),
          );
        case _ToolEntryKind.mcpServer:
          onReplaceMcpServer(
            entry.sourceIndex,
            catalog.mcpServers[entry.sourceIndex].copyWith(name: nextName),
          );
      }
    }

    void updateExternalCoverage(String platform, bool enabled) {
      final tool = catalog.externalTools[entry.sourceIndex];
      onReplaceExternalTool(
        entry.sourceIndex,
        _setExternalToolPlatformCoverage(tool, platform, enabled),
      );
    }

    void updateMcpCoverage(String platform, bool enabled) {
      final server = catalog.mcpServers[entry.sourceIndex];
      onReplaceMcpServer(
        entry.sourceIndex,
        _setMcpServerPlatformCoverage(server, platform, enabled),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        _WorkspaceSectionCard(
          title: 'General',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ManagedTextField(
                label: 'Name',
                value: entry.name,
                onChanged: updateName,
              ),
              const SizedBox(height: 14),
              entry.kind == _ToolEntryKind.toolGroup
                  ? _ReadOnlyRow(label: 'Entity type', value: entry.kind.label)
                  : _DropdownField<_ToolEntryKind>(
                      label: 'Entity type',
                      value: entry.kind,
                      options: const <_ToolEntryKind>[
                        _ToolEntryKind.externalTool,
                        _ToolEntryKind.mcpServer,
                      ],
                      fallbackLabel: 'Choose type',
                      labelBuilder: (_ToolEntryKind value) => value.label,
                      onChanged: (_ToolEntryKind value) =>
                          onChangeEntryKind(entry, value),
                    ),
              const SizedBox(height: 4),
              const Text(
                'Platforms',
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              entry.kind == _ToolEntryKind.toolGroup
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in entry.platformPillLabels)
                          StatusPill(label: label, color: textMutedColor),
                      ],
                    )
                  : _PlatformCoverageToggles(
                      supportedPlatforms: entry.supportedPlatforms,
                      onToggle: entry.kind == _ToolEntryKind.externalTool
                          ? updateExternalCoverage
                          : updateMcpCoverage,
                    ),
              if (entry.relatedGroups.isNotEmpty) ...[
                const SizedBox(height: 14),
                TagSection(
                  title: 'Group membership',
                  tags: entry.relatedGroups,
                ),
              ],
              const SizedBox(height: 14),
              _ReadOnlyRow(
                label: 'Catalog path',
                value: blankAsUnknown(configPath),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolAccessTab extends StatelessWidget {
  const _ToolAccessTab({
    required this.catalog,
    required this.entry,
    required this.onReplaceToolGroup,
    required this.onReplaceExternalTool,
    required this.onReplaceMcpServer,
  });

  final HarnessToolCatalog catalog;
  final _ToolWorkspaceEntry entry;
  final void Function(int index, HarnessToolGroupSummary value)
  onReplaceToolGroup;
  final void Function(int index, HarnessExternalToolSummary value)
  onReplaceExternalTool;
  final void Function(int index, HarnessMcpServerSummary value)
  onReplaceMcpServer;

  @override
  Widget build(BuildContext context) {
    final filesystem = switch (entry.kind) {
      _ToolEntryKind.toolGroup => '',
      _ToolEntryKind.externalTool =>
        catalog.externalTools[entry.sourceIndex].filesystem,
      _ToolEntryKind.mcpServer =>
        catalog.mcpServers[entry.sourceIndex].filesystem,
    };
    final network = switch (entry.kind) {
      _ToolEntryKind.toolGroup => false,
      _ToolEntryKind.externalTool =>
        catalog.externalTools[entry.sourceIndex].network,
      _ToolEntryKind.mcpServer => catalog.mcpServers[entry.sourceIndex].network,
    };

    void updateAccess({String? nextFilesystem, bool? nextNetwork}) {
      switch (entry.kind) {
        case _ToolEntryKind.toolGroup:
          return;
        case _ToolEntryKind.externalTool:
          final tool = catalog.externalTools[entry.sourceIndex];
          onReplaceExternalTool(
            entry.sourceIndex,
            tool.copyWith(
              filesystem: nextFilesystem ?? tool.filesystem,
              network: nextNetwork ?? tool.network,
            ),
          );
        case _ToolEntryKind.mcpServer:
          final server = catalog.mcpServers[entry.sourceIndex];
          onReplaceMcpServer(
            entry.sourceIndex,
            server.copyWith(
              filesystem: nextFilesystem ?? server.filesystem,
              network: nextNetwork ?? server.network,
            ),
          );
      }
    }

    final filesystemEnabled = filesystem.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        _WorkspaceSectionCard(
          title: 'Resource access',
          child: entry.kind == _ToolEntryKind.toolGroup
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tool groups inherit access from their members. Use the member tools below to change the actual access footprint.',
                      style: TextStyle(color: textMutedColor, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _AccessMiniPill(
                          label: 'FS:${entry.filesystemAccessMode.label}',
                          mode: entry.filesystemAccessMode,
                        ),
                        _AccessMiniPill(
                          label: entry.networkAccess ? 'NET:ACCESS' : 'NET:-',
                          mode: entry.networkAccess
                              ? _ToolResourceAccess.execute
                              : _ToolResourceAccess.none,
                        ),
                      ],
                    ),
                  ],
                )
              : _AccessToggleGrid(
                  children: [
                    _ResourceAccessCard(
                      label: 'Filesystem',
                      description:
                          'Marks this definition as accessing workspace or local files. Choose whether that access is process-style execution, read, or write.',
                      enabled: filesystemEnabled,
                      tone: infoColor,
                      onEnabledChanged: (bool value) {
                        updateAccess(nextFilesystem: value ? 'execute' : '');
                      },
                      child: filesystemEnabled
                          ? _DropdownField<String>(
                              label: 'Filesystem access',
                              value: filesystem,
                              options: const <String>[
                                'execute',
                                'read',
                                'write',
                              ],
                              fallbackLabel: 'Not set',
                              onChanged: (String value) =>
                                  updateAccess(nextFilesystem: value),
                            )
                          : null,
                    ),
                    _ResourceAccessCard(
                      label: 'Network',
                      description:
                          'Marks this definition as reaching remote services or URLs at any level, including HTTP, TCP, UDP, SSH, or sockets.',
                      enabled: network,
                      tone: accentColor,
                      onEnabledChanged: (bool value) =>
                          updateAccess(nextNetwork: value),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        switch (entry.kind) {
          _ToolEntryKind.toolGroup => _ToolGroupEditor(
            group: catalog.toolGroups[entry.sourceIndex],
            allToolNames: <String>[
              ...catalog.externalTools.map(
                (HarnessExternalToolSummary t) => t.name,
              ),
              ...catalog.mcpServers.map((HarnessMcpServerSummary s) => s.name),
            ]..sort(),
            onChanged: (HarnessToolGroupSummary value) =>
                onReplaceToolGroup(entry.sourceIndex, value),
          ),
          _ToolEntryKind.externalTool => _ExternalToolEditor(
            key: const ValueKey<String>('access-external-editor'),
            tool: catalog.externalTools[entry.sourceIndex],
            relatedGroups: entry.relatedGroups,
            sections: const <_ExternalToolOverviewSection>[
              _ExternalToolOverviewSection.definition,
            ],
            initialSection: _ExternalToolOverviewSection.definition,
            onChanged: (HarnessExternalToolSummary value) =>
                onReplaceExternalTool(entry.sourceIndex, value),
          ),
          _ToolEntryKind.mcpServer => _McpServerEditor(
            key: const ValueKey<String>('access-mcp-editor'),
            server: catalog.mcpServers[entry.sourceIndex],
            relatedGroups: entry.relatedGroups,
            sections: const <_McpServerOverviewSection>[
              _McpServerOverviewSection.definition,
              _McpServerOverviewSection.scope,
            ],
            initialSection: _McpServerOverviewSection.definition,
            onChanged: (HarnessMcpServerSummary value) =>
                onReplaceMcpServer(entry.sourceIndex, value),
          ),
        },
      ],
    );
  }
}

class _ToolRuntimeTab extends StatelessWidget {
  const _ToolRuntimeTab({
    required this.catalog,
    required this.entry,
    required this.onReplaceExternalTool,
    required this.onReplaceMcpServer,
  });

  final HarnessToolCatalog catalog;
  final _ToolWorkspaceEntry entry;
  final void Function(int index, HarnessExternalToolSummary value)
  onReplaceExternalTool;
  final void Function(int index, HarnessMcpServerSummary value)
  onReplaceMcpServer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        switch (entry.kind) {
          _ToolEntryKind.toolGroup => const InfoPanel(
            title: 'No runtime settings',
            body:
                'Tool groups only organize member entries. Runtime and schema settings live on the individual tools and MCP servers in this workspace.',
          ),
          _ToolEntryKind.externalTool => _ExternalToolRuntimeEditor(
            tool: catalog.externalTools[entry.sourceIndex],
            onChanged: (HarnessExternalToolSummary value) =>
                onReplaceExternalTool(entry.sourceIndex, value),
          ),
          _ToolEntryKind.mcpServer => _McpServerRuntimeEditor(
            server: catalog.mcpServers[entry.sourceIndex],
            onChanged: (HarnessMcpServerSummary value) =>
                onReplaceMcpServer(entry.sourceIndex, value),
          ),
        },
      ],
    );
  }
}

class _ExternalToolRuntimeEditor extends StatelessWidget {
  const _ExternalToolRuntimeEditor({
    required this.tool,
    required this.onChanged,
  });

  final HarnessExternalToolSummary tool;
  final ValueChanged<HarnessExternalToolSummary> onChanged;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSectionCard(
      title: 'Runtime',
      child: Column(
        children: [
          _ManagedNumberField(
            label: 'Timeout seconds',
            value: tool.timeoutSeconds,
            onChanged: (int value) =>
                onChanged(tool.copyWith(timeoutSeconds: value)),
          ),
          const SizedBox(height: 14),
          _ManagedTextField(
            label: 'STDIN mode',
            value: tool.stdinMode,
            hintText: 'json | text | not set',
            onChanged: (String value) =>
                onChanged(tool.copyWith(stdinMode: value.trim())),
          ),
          const SizedBox(height: 14),
          _ManagedTextField(
            label: 'Output format',
            value: tool.outputFormat,
            hintText: 'text | json | silent',
            onChanged: (String value) =>
                onChanged(tool.copyWith(outputFormat: value.trim())),
          ),
          const SizedBox(height: 14),
          _LineListEditor(
            label: 'Command',
            hint: 'One executable token per line.',
            values: tool.command,
            onChanged: (List<String> value) =>
                onChanged(tool.copyWith(command: value)),
          ),
          const SizedBox(height: 14),
          _LineListEditor(
            label: 'Args',
            hint: 'One argument token per line.',
            values: tool.args,
            onChanged: (List<String> value) =>
                onChanged(tool.copyWith(args: value)),
          ),
          const SizedBox(height: 14),
          _KeyValueEditor(
            label: 'Environment',
            hint: 'Use KEY=VALUE per line.',
            values: tool.env,
            onChanged: (Map<String, String> value) =>
                onChanged(tool.copyWith(env: value)),
          ),
          const SizedBox(height: 14),
          _JsonEditor(
            label: 'Input schema',
            value: tool.inputSchema,
            onChanged: (Map<String, dynamic> value) =>
                onChanged(tool.copyWith(inputSchema: value)),
          ),
          const SizedBox(height: 14),
          _TempFileEditor(
            files: tool.tempFiles,
            onChanged: (List<HarnessExternalToolTempFile> value) =>
                onChanged(tool.copyWith(tempFiles: value)),
          ),
        ],
      ),
    );
  }
}

class _McpServerRuntimeEditor extends StatelessWidget {
  const _McpServerRuntimeEditor({
    required this.server,
    required this.onChanged,
  });

  final HarnessMcpServerSummary server;
  final ValueChanged<HarnessMcpServerSummary> onChanged;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSectionCard(
      title: 'Runtime',
      child: Column(
        children: [
          _ManagedTextField(
            label: 'URL',
            value: server.url,
            onChanged: (String value) =>
                onChanged(server.copyWith(url: value.trim())),
          ),
          const SizedBox(height: 14),
          _ManagedTextField(
            label: 'Healthcheck URL',
            value: server.healthcheckUrl,
            onChanged: (String value) =>
                onChanged(server.copyWith(healthcheckUrl: value.trim())),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ManagedNumberField(
                  label: 'Run timeout',
                  value: server.timeoutSeconds,
                  onChanged: (int value) =>
                      onChanged(server.copyWith(timeoutSeconds: value)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ManagedNumberField(
                  label: 'Startup timeout',
                  value: server.startupTimeoutSeconds,
                  onChanged: (int value) =>
                      onChanged(server.copyWith(startupTimeoutSeconds: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ManagedNumberField(
            label: 'Shutdown timeout',
            value: server.shutdownTimeoutSeconds,
            onChanged: (int value) =>
                onChanged(server.copyWith(shutdownTimeoutSeconds: value)),
          ),
          const SizedBox(height: 14),
          _LineListEditor(
            label: 'Command',
            hint: 'One executable token per line.',
            values: server.command,
            onChanged: (List<String> value) =>
                onChanged(server.copyWith(command: value)),
          ),
          const SizedBox(height: 14),
          _LineListEditor(
            label: 'Args',
            hint: 'One argument token per line.',
            values: server.args,
            onChanged: (List<String> value) =>
                onChanged(server.copyWith(args: value)),
          ),
          const SizedBox(height: 14),
          _KeyValueEditor(
            label: 'Environment',
            hint: 'Use KEY=VALUE per line.',
            values: server.env,
            onChanged: (Map<String, String> value) =>
                onChanged(server.copyWith(env: value)),
          ),
        ],
      ),
    );
  }
}

class _ToolDocumentTab extends StatelessWidget {
  const _ToolDocumentTab({
    required this.catalog,
    required this.entry,
    required this.configPath,
    required this.validation,
    required this.onReplaceExternalTool,
    required this.onReplaceMcpServer,
  });

  final HarnessToolCatalog catalog;
  final _ToolWorkspaceEntry entry;
  final String configPath;
  final HarnessConfigValidationReport? validation;
  final void Function(int index, HarnessExternalToolSummary value)
  onReplaceExternalTool;
  final void Function(int index, HarnessMcpServerSummary value)
  onReplaceMcpServer;

  @override
  Widget build(BuildContext context) {
    final entryYaml = _entryYamlDocument(catalog, entry);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        switch (entry.kind) {
          _ToolEntryKind.toolGroup => const InfoPanel(
            title: 'No platform overrides',
            body:
                'Tool groups inherit platform coverage from their member tools, so they do not define their own platform override blocks.',
          ),
          _ToolEntryKind.externalTool => _WorkspaceSectionCard(
            title: 'Platform overrides',
            child: _ExternalToolPlatformEditor(
              platforms: catalog.externalTools[entry.sourceIndex].platforms,
              onChanged:
                  (Map<String, HarnessExternalToolPlatformSummary> value) =>
                      onReplaceExternalTool(
                        entry.sourceIndex,
                        catalog.externalTools[entry.sourceIndex].copyWith(
                          platforms: value,
                        ),
                      ),
            ),
          ),
          _ToolEntryKind.mcpServer => _WorkspaceSectionCard(
            title: 'Platform overrides',
            child: _McpServerPlatformEditor(
              platforms: catalog.mcpServers[entry.sourceIndex].platforms,
              onChanged: (Map<String, HarnessMcpServerPlatformSummary> value) =>
                  onReplaceMcpServer(
                    entry.sourceIndex,
                    catalog.mcpServers[entry.sourceIndex].copyWith(
                      platforms: value,
                    ),
                  ),
            ),
          ),
        },
        const SizedBox(height: 18),
        _WorkspaceSectionCard(
          title: 'Selected entry YAML',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This view shows only the selected tool, MCP server, or tool group as YAML. The control plane remains the source of truth for canonical save formatting.',
                style: TextStyle(color: textMutedColor, height: 1.5),
              ),
              const SizedBox(height: 14),
              AppReadOnlyField(
                label: 'Catalog path',
                value: blankAsUnknown(configPath),
              ),
            ],
          ),
        ),
        if (validation != null) ...[
          const SizedBox(height: 18),
          _ToolsValidationPanel(report: validation!),
        ],
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0x99212D41),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: SelectableText(
            entryYaml,
            style: const TextStyle(
              color: textPrimaryColor,
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolGroupEditor extends StatelessWidget {
  const _ToolGroupEditor({
    required this.group,
    required this.allToolNames,
    required this.onChanged,
  });

  final HarnessToolGroupSummary group;
  final List<String> allToolNames;
  final ValueChanged<HarnessToolGroupSummary> onChanged;

  @override
  Widget build(BuildContext context) {
    final remainingTools = allToolNames
        .where((String toolName) => !group.tools.contains(toolName))
        .toList();
    return Column(
      children: [
        _WorkspaceSectionCard(
          title: 'Tool group members',
          child: Column(
            children: [
              _LineListEditor(
                label: 'Member tools',
                hint:
                    'One tool name per line. Order here is preserved in the saved catalog.',
                values: group.tools,
                addOptions: remainingTools,
                addLabel: 'Add member',
                onChanged: (List<String> value) =>
                    onChanged(group.copyWith(tools: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExternalToolEditor extends StatefulWidget {
  const _ExternalToolEditor({
    super.key,
    required this.tool,
    required this.relatedGroups,
    required this.sections,
    required this.onChanged,
    this.initialSection,
  });

  final HarnessExternalToolSummary tool;
  final List<String> relatedGroups;
  final List<_ExternalToolOverviewSection> sections;
  final ValueChanged<HarnessExternalToolSummary> onChanged;
  final _ExternalToolOverviewSection? initialSection;

  @override
  State<_ExternalToolEditor> createState() => _ExternalToolEditorState();
}

class _ExternalToolEditorState extends State<_ExternalToolEditor> {
  late _ExternalToolOverviewSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection ?? widget.sections.first;
  }

  @override
  void didUpdateWidget(covariant _ExternalToolEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.sections.contains(_section)) {
      _section = widget.initialSection ?? widget.sections.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Column(
      children: [
        if (widget.sections.length > 1) ...[
          _OverviewSectionMenu<_ExternalToolOverviewSection>(
            items: widget.sections,
            value: _section,
            label: (_ExternalToolOverviewSection value) => switch (value) {
              _ExternalToolOverviewSection.definition => 'Definition',
              _ExternalToolOverviewSection.runtime => 'Runtime',
              _ExternalToolOverviewSection.schema => 'Schema',
              _ExternalToolOverviewSection.platforms => 'Platforms',
            },
            onChanged: (_ExternalToolOverviewSection value) {
              setState(() => _section = value);
            },
          ),
          const SizedBox(height: 18),
        ],
        switch (_section) {
          _ExternalToolOverviewSection.definition => _WorkspaceSectionCard(
            title: 'Definition',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ToggleField(
                        label: 'Idempotent',
                        value: tool.idempotent,
                        onChanged: (bool value) =>
                            widget.onChanged(tool.copyWith(idempotent: value)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ToggleField(
                        label: 'Inherit env',
                        value: tool.inheritEnv,
                        onChanged: (bool value) =>
                            widget.onChanged(tool.copyWith(inheritEnv: value)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ExternalToolOverviewSection.runtime => _WorkspaceSectionCard(
            title: 'Runtime',
            child: Column(
              children: [
                _ManagedNumberField(
                  label: 'Timeout seconds',
                  value: tool.timeoutSeconds,
                  onChanged: (int value) =>
                      widget.onChanged(tool.copyWith(timeoutSeconds: value)),
                ),
                const SizedBox(height: 14),
                _ManagedTextField(
                  label: 'STDIN mode',
                  value: tool.stdinMode,
                  hintText: 'json | text | not set',
                  onChanged: (String value) =>
                      widget.onChanged(tool.copyWith(stdinMode: value.trim())),
                ),
                const SizedBox(height: 14),
                _ManagedTextField(
                  label: 'Output format',
                  value: tool.outputFormat,
                  hintText: 'text | json | silent',
                  onChanged: (String value) => widget.onChanged(
                    tool.copyWith(outputFormat: value.trim()),
                  ),
                ),
                const SizedBox(height: 14),
                _LineListEditor(
                  label: 'Command',
                  hint: 'One executable token per line.',
                  values: tool.command,
                  onChanged: (List<String> value) =>
                      widget.onChanged(tool.copyWith(command: value)),
                ),
                const SizedBox(height: 14),
                _LineListEditor(
                  label: 'Args',
                  hint: 'One argument token per line.',
                  values: tool.args,
                  onChanged: (List<String> value) =>
                      widget.onChanged(tool.copyWith(args: value)),
                ),
                const SizedBox(height: 14),
                _KeyValueEditor(
                  label: 'Environment',
                  hint: 'Use KEY=VALUE per line.',
                  values: tool.env,
                  onChanged: (Map<String, String> value) =>
                      widget.onChanged(tool.copyWith(env: value)),
                ),
              ],
            ),
          ),
          _ExternalToolOverviewSection.schema => _WorkspaceSectionCard(
            title: 'Schema and temp files',
            child: Column(
              children: [
                _JsonEditor(
                  label: 'Input schema',
                  value: tool.inputSchema,
                  onChanged: (Map<String, dynamic> value) =>
                      widget.onChanged(tool.copyWith(inputSchema: value)),
                ),
                const SizedBox(height: 14),
                _TempFileEditor(
                  files: tool.tempFiles,
                  onChanged: (List<HarnessExternalToolTempFile> value) =>
                      widget.onChanged(tool.copyWith(tempFiles: value)),
                ),
              ],
            ),
          ),
          _ExternalToolOverviewSection.platforms => _WorkspaceSectionCard(
            title: 'Platform overrides',
            child: _ExternalToolPlatformEditor(
              platforms: tool.platforms,
              onChanged:
                  (Map<String, HarnessExternalToolPlatformSummary> value) =>
                      widget.onChanged(tool.copyWith(platforms: value)),
            ),
          ),
        },
      ],
    );
  }
}

class _McpServerEditor extends StatefulWidget {
  const _McpServerEditor({
    super.key,
    required this.server,
    required this.relatedGroups,
    required this.sections,
    required this.onChanged,
    this.initialSection,
  });

  final HarnessMcpServerSummary server;
  final List<String> relatedGroups;
  final List<_McpServerOverviewSection> sections;
  final ValueChanged<HarnessMcpServerSummary> onChanged;
  final _McpServerOverviewSection? initialSection;

  @override
  State<_McpServerEditor> createState() => _McpServerEditorState();
}

class _McpServerEditorState extends State<_McpServerEditor> {
  late _McpServerOverviewSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection ?? widget.sections.first;
  }

  @override
  void didUpdateWidget(covariant _McpServerEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.sections.contains(_section)) {
      _section = widget.initialSection ?? widget.sections.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    return Column(
      children: [
        if (widget.sections.length > 1) ...[
          _OverviewSectionMenu<_McpServerOverviewSection>(
            items: widget.sections,
            value: _section,
            label: (_McpServerOverviewSection value) => switch (value) {
              _McpServerOverviewSection.definition => 'Definition',
              _McpServerOverviewSection.connection => 'Connection',
              _McpServerOverviewSection.scope => 'Scope',
              _McpServerOverviewSection.platforms => 'Platforms',
            },
            onChanged: (_McpServerOverviewSection value) {
              setState(() => _section = value);
            },
          ),
          const SizedBox(height: 18),
        ],
        switch (_section) {
          _McpServerOverviewSection.definition => _WorkspaceSectionCard(
            title: 'Definition',
            child: Column(
              children: [
                _DropdownField<String>(
                  label: 'Lifecycle',
                  value: server.lifecycle,
                  options: const <String>['persistent', 'per_call'],
                  fallbackLabel: 'Not set',
                  onChanged: (String value) =>
                      widget.onChanged(server.copyWith(lifecycle: value)),
                ),
                const SizedBox(height: 14),
                _DropdownField<String>(
                  label: 'Transport',
                  value: server.transport,
                  options: const <String>['stdio', 'http'],
                  fallbackLabel: 'Not set',
                  onChanged: (String value) =>
                      widget.onChanged(server.copyWith(transport: value)),
                ),
                const SizedBox(height: 14),
                _ManagedTextField(
                  label: 'Tool name prefix',
                  value: server.toolNamePrefix,
                  onChanged: (String value) => widget.onChanged(
                    server.copyWith(toolNamePrefix: value.trim()),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ToggleField(
                        label: 'Idempotent',
                        value: server.idempotent,
                        onChanged: (bool value) => widget.onChanged(
                          server.copyWith(idempotent: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ToggleField(
                        label: 'Inherit env',
                        value: server.inheritEnv,
                        onChanged: (bool value) => widget.onChanged(
                          server.copyWith(inheritEnv: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _McpServerOverviewSection.connection => _WorkspaceSectionCard(
            title: 'Connection and process',
            child: Column(
              children: [
                _ManagedTextField(
                  label: 'URL',
                  value: server.url,
                  onChanged: (String value) =>
                      widget.onChanged(server.copyWith(url: value.trim())),
                ),
                const SizedBox(height: 14),
                _ManagedTextField(
                  label: 'Healthcheck URL',
                  value: server.healthcheckUrl,
                  onChanged: (String value) => widget.onChanged(
                    server.copyWith(healthcheckUrl: value.trim()),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ManagedNumberField(
                        label: 'Run timeout',
                        value: server.timeoutSeconds,
                        onChanged: (int value) => widget.onChanged(
                          server.copyWith(timeoutSeconds: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ManagedNumberField(
                        label: 'Startup timeout',
                        value: server.startupTimeoutSeconds,
                        onChanged: (int value) => widget.onChanged(
                          server.copyWith(startupTimeoutSeconds: value),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ManagedNumberField(
                  label: 'Shutdown timeout',
                  value: server.shutdownTimeoutSeconds,
                  onChanged: (int value) => widget.onChanged(
                    server.copyWith(shutdownTimeoutSeconds: value),
                  ),
                ),
                const SizedBox(height: 14),
                _LineListEditor(
                  label: 'Command',
                  hint: 'One executable token per line.',
                  values: server.command,
                  onChanged: (List<String> value) =>
                      widget.onChanged(server.copyWith(command: value)),
                ),
                const SizedBox(height: 14),
                _LineListEditor(
                  label: 'Args',
                  hint: 'One argument token per line.',
                  values: server.args,
                  onChanged: (List<String> value) =>
                      widget.onChanged(server.copyWith(args: value)),
                ),
                const SizedBox(height: 14),
                _KeyValueEditor(
                  label: 'Environment',
                  hint: 'Use KEY=VALUE per line.',
                  values: server.env,
                  onChanged: (Map<String, String> value) =>
                      widget.onChanged(server.copyWith(env: value)),
                ),
              ],
            ),
          ),
          _McpServerOverviewSection.scope => _WorkspaceSectionCard(
            title: 'Tool scope',
            child: Column(
              children: [
                _LineListEditor(
                  label: 'Include tools',
                  hint: 'Optional allow-list, one exposed tool name per line.',
                  values: server.includeTools,
                  onChanged: (List<String> value) =>
                      widget.onChanged(server.copyWith(includeTools: value)),
                ),
                const SizedBox(height: 14),
                _LineListEditor(
                  label: 'Exclude tools',
                  hint: 'Optional deny-list, one exposed tool name per line.',
                  values: server.excludeTools,
                  onChanged: (List<String> value) =>
                      widget.onChanged(server.copyWith(excludeTools: value)),
                ),
              ],
            ),
          ),
          _McpServerOverviewSection.platforms => _WorkspaceSectionCard(
            title: 'Platform overrides',
            child: _McpServerPlatformEditor(
              platforms: server.platforms,
              onChanged: (Map<String, HarnessMcpServerPlatformSummary> value) =>
                  widget.onChanged(server.copyWith(platforms: value)),
            ),
          ),
        },
      ],
    );
  }
}

class _ExternalToolPlatformEditor extends StatelessWidget {
  const _ExternalToolPlatformEditor({
    required this.platforms,
    required this.onChanged,
  });

  final Map<String, HarnessExternalToolPlatformSummary> platforms;
  final ValueChanged<Map<String, HarnessExternalToolPlatformSummary>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PlatformOverrideEditor<HarnessExternalToolPlatformSummary>(
      platforms: platforms,
      createPlatform: () => HarnessExternalToolPlatformSummary(
        timeoutSeconds: 0,
        command: const <String>[],
        args: const <String>[],
        workingDir: '',
        env: const <String, String>{},
        stdinMode: '',
        tempFiles: const <HarnessExternalToolTempFile>[],
        outputFormat: '',
      ),
      emptyStateBody:
          'Select a platform to create an override and edit platform-specific command settings.',
      onChanged: onChanged,
      fieldsBuilder:
          (
            HarnessExternalToolPlatformSummary value,
            ValueChanged<HarnessExternalToolPlatformSummary> onValueChanged,
          ) => _ExternalToolPlatformFields(
            value: value,
            onChanged: onValueChanged,
          ),
    );
  }
}

class _McpServerPlatformEditor extends StatelessWidget {
  const _McpServerPlatformEditor({
    required this.platforms,
    required this.onChanged,
  });

  final Map<String, HarnessMcpServerPlatformSummary> platforms;
  final ValueChanged<Map<String, HarnessMcpServerPlatformSummary>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _PlatformOverrideEditor<HarnessMcpServerPlatformSummary>(
      platforms: platforms,
      createPlatform: () => HarnessMcpServerPlatformSummary(
        lifecycle: '',
        transport: '',
        url: '',
        healthcheckUrl: '',
        command: const <String>[],
        args: const <String>[],
        workingDir: '',
        env: const <String, String>{},
        timeoutSeconds: 0,
        startupTimeoutSeconds: 0,
        shutdownTimeoutSeconds: 0,
      ),
      emptyStateBody:
          'Select a platform to create an override and edit platform-specific server bootstrap settings.',
      onChanged: onChanged,
      fieldsBuilder:
          (
            HarnessMcpServerPlatformSummary value,
            ValueChanged<HarnessMcpServerPlatformSummary> onValueChanged,
          ) =>
              _McpServerPlatformFields(value: value, onChanged: onValueChanged),
    );
  }
}

class _PlatformOverrideEditor<T> extends StatefulWidget {
  const _PlatformOverrideEditor({
    required this.platforms,
    required this.createPlatform,
    required this.emptyStateBody,
    required this.onChanged,
    required this.fieldsBuilder,
  });

  final Map<String, T> platforms;
  final T Function() createPlatform;
  final String emptyStateBody;
  final ValueChanged<Map<String, T>> onChanged;
  final Widget Function(T value, ValueChanged<T> onChanged) fieldsBuilder;

  @override
  State<_PlatformOverrideEditor<T>> createState() =>
      _PlatformOverrideEditorState<T>();
}

class _PlatformOverrideEditorState<T>
    extends State<_PlatformOverrideEditor<T>> {
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _selectedKey = _resolvePlatformPanelKey(null, widget.platforms.keys);
  }

  @override
  void didUpdateWidget(covariant _PlatformOverrideEditor<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedKey = _resolvePlatformPanelKey(
      _selectedKey,
      widget.platforms.keys,
    );
  }

  void _selectOrAddPlatform(_PlatformPanelOption option) {
    if (option.exists) {
      setState(() => _selectedKey = option.key);
      return;
    }
    final next = Map<String, T>.from(widget.platforms);
    next[option.key] = widget.createPlatform();
    setState(() => _selectedKey = option.key);
    widget.onChanged(next);
  }

  void _updatePlatform(String key, T value) {
    final next = Map<String, T>.from(widget.platforms);
    next[key] = value;
    widget.onChanged(next);
  }

  void _removePlatform(String key) {
    final next = Map<String, T>.from(widget.platforms)..remove(key);
    final nextSelection =
        _normalizedPlatformKey(_selectedKey ?? '') ==
            _normalizedPlatformKey(key)
        ? null
        : _selectedKey;
    setState(() {
      _selectedKey = _resolvePlatformPanelKey(nextSelection, next.keys);
    });
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _resolvePlatformPanelKey(
      _selectedKey,
      widget.platforms.keys,
    );
    final options = _platformPanelOptions(widget.platforms.keys);

    if (selectedKey == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlatformSelectorBar(
            label: 'Platform',
            options: options,
            selectedKey: null,
            onSelected: _selectOrAddPlatform,
          ),
          InfoPanel(
            title: 'No platform overrides',
            body: widget.emptyStateBody,
          ),
        ],
      );
    }

    final value = widget.platforms[selectedKey];
    if (value == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlatformSelectorBar(
          label: 'Platform',
          options: options,
          selectedKey: selectedKey,
          onSelected: _selectOrAddPlatform,
        ),
        _PlatformCard(
          title: _platformEditorTitle(selectedKey),
          onRemove: () => _removePlatform(selectedKey),
          child: widget.fieldsBuilder(
            value,
            (T nextValue) => _updatePlatform(selectedKey, nextValue),
          ),
        ),
      ],
    );
  }
}

class _ExternalToolPlatformFields extends StatelessWidget {
  const _ExternalToolPlatformFields({
    required this.value,
    required this.onChanged,
  });

  final HarnessExternalToolPlatformSummary value;
  final ValueChanged<HarnessExternalToolPlatformSummary> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ManagedNumberField(
          label: 'Timeout seconds',
          value: value.timeoutSeconds,
          onChanged: (int nextValue) =>
              onChanged(value.copyWith(timeoutSeconds: nextValue)),
        ),
        const SizedBox(height: 14),
        _LineListEditor(
          label: 'Command',
          hint: 'One executable token per line.',
          values: value.command,
          onChanged: (List<String> nextValue) =>
              onChanged(value.copyWith(command: nextValue)),
        ),
        const SizedBox(height: 14),
        _LineListEditor(
          label: 'Args',
          hint: 'One argument token per line.',
          values: value.args,
          onChanged: (List<String> nextValue) =>
              onChanged(value.copyWith(args: nextValue)),
        ),
        const SizedBox(height: 14),
        _ManagedTextField(
          label: 'Working directory',
          value: value.workingDir,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(workingDir: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _ManagedTextField(
          label: 'STDIN mode',
          value: value.stdinMode,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(stdinMode: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _ManagedTextField(
          label: 'Output format',
          value: value.outputFormat,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(outputFormat: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _KeyValueEditor(
          label: 'Environment',
          hint: 'Use KEY=VALUE per line.',
          values: value.env,
          onChanged: (Map<String, String> nextValue) =>
              onChanged(value.copyWith(env: nextValue)),
        ),
        const SizedBox(height: 14),
        _TempFileEditor(
          files: value.tempFiles,
          onChanged: (List<HarnessExternalToolTempFile> nextValue) =>
              onChanged(value.copyWith(tempFiles: nextValue)),
        ),
      ],
    );
  }
}

class _McpServerPlatformFields extends StatelessWidget {
  const _McpServerPlatformFields({
    required this.value,
    required this.onChanged,
  });

  final HarnessMcpServerPlatformSummary value;
  final ValueChanged<HarnessMcpServerPlatformSummary> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ManagedTextField(
          label: 'Lifecycle',
          value: value.lifecycle,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(lifecycle: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _ManagedTextField(
          label: 'Transport',
          value: value.transport,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(transport: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _ManagedTextField(
          label: 'URL',
          value: value.url,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(url: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _ManagedTextField(
          label: 'Healthcheck URL',
          value: value.healthcheckUrl,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(healthcheckUrl: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _ManagedTextField(
          label: 'Working directory',
          value: value.workingDir,
          onChanged: (String nextValue) =>
              onChanged(value.copyWith(workingDir: nextValue.trim())),
        ),
        const SizedBox(height: 14),
        _LineListEditor(
          label: 'Command',
          hint: 'One executable token per line.',
          values: value.command,
          onChanged: (List<String> nextValue) =>
              onChanged(value.copyWith(command: nextValue)),
        ),
        const SizedBox(height: 14),
        _LineListEditor(
          label: 'Args',
          hint: 'One argument token per line.',
          values: value.args,
          onChanged: (List<String> nextValue) =>
              onChanged(value.copyWith(args: nextValue)),
        ),
        const SizedBox(height: 14),
        _KeyValueEditor(
          label: 'Environment',
          hint: 'Use KEY=VALUE per line.',
          values: value.env,
          onChanged: (Map<String, String> nextValue) =>
              onChanged(value.copyWith(env: nextValue)),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ManagedNumberField(
                label: 'Run timeout',
                value: value.timeoutSeconds,
                onChanged: (int nextValue) =>
                    onChanged(value.copyWith(timeoutSeconds: nextValue)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ManagedNumberField(
                label: 'Startup timeout',
                value: value.startupTimeoutSeconds,
                onChanged: (int nextValue) =>
                    onChanged(value.copyWith(startupTimeoutSeconds: nextValue)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ManagedNumberField(
          label: 'Shutdown timeout',
          value: value.shutdownTimeoutSeconds,
          onChanged: (int nextValue) =>
              onChanged(value.copyWith(shutdownTimeoutSeconds: nextValue)),
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.title,
    required this.child,
    required this.onRemove,
  });

  final String title;
  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x66172231),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TempFileEditor extends StatelessWidget {
  const _TempFileEditor({required this.files, required this.onChanged});

  final List<HarnessExternalToolTempFile> files;
  final ValueChanged<List<HarnessExternalToolTempFile>> onChanged;

  @override
  Widget build(BuildContext context) {
    void addFile() {
      onChanged(<HarnessExternalToolTempFile>[
        ...files,
        HarnessExternalToolTempFile(
          name: 'temp_file_${files.length + 1}',
          inputKey: '',
          format: 'text',
          suffix: '',
          required: false,
        ),
      ]);
    }

    void updateFile(int index, HarnessExternalToolTempFile nextFile) {
      final next = files.toList();
      next[index] = nextFile;
      onChanged(next);
    }

    void removeFile(int index) {
      final next = files.toList()..removeAt(index);
      onChanged(next);
    }

    void moveFile(int index, int delta) {
      final newIndex = index + delta;
      if (newIndex < 0 || newIndex >= files.length) {
        return;
      }
      final next = files.toList();
      final item = next.removeAt(index);
      next.insert(newIndex, item);
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Temporary files',
                style: TextStyle(
                  color: textPrimaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: addFile,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add file'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (files.isEmpty)
          const InfoPanel(
            title: 'No temp files',
            body:
                'Add temp files when the tool needs large inputs materialized before execution.',
          )
        else
          Column(
            children: [
              for (int index = 0; index < files.length; index++) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x66172231),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Temp file ${index + 1}',
                            style: const TextStyle(
                              color: textPrimaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: index > 0
                                ? () => moveFile(index, -1)
                                : null,
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            onPressed: index < files.length - 1
                                ? () => moveFile(index, 1)
                                : null,
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                          IconButton(
                            onPressed: () => removeFile(index),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ManagedTextField(
                        label: 'Name',
                        value: files[index].name,
                        onChanged: (String value) => updateFile(
                          index,
                          files[index].copyWith(name: value.trim()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ManagedTextField(
                        label: 'Input key',
                        value: files[index].inputKey,
                        onChanged: (String value) => updateFile(
                          index,
                          files[index].copyWith(inputKey: value.trim()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ManagedTextField(
                        label: 'Format',
                        value: files[index].format,
                        onChanged: (String value) => updateFile(
                          index,
                          files[index].copyWith(format: value.trim()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ManagedTextField(
                        label: 'Suffix',
                        value: files[index].suffix,
                        onChanged: (String value) => updateFile(
                          index,
                          files[index].copyWith(suffix: value.trim()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ToggleField(
                        label: 'Required',
                        value: files[index].required,
                        onChanged: (bool value) => updateFile(
                          index,
                          files[index].copyWith(required: value),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < files.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}

class _PlatformSelectorBar extends StatelessWidget {
  const _PlatformSelectorBar({
    required this.label,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  final String label;
  final List<_PlatformPanelOption> options;
  final String? selectedKey;
  final ValueChanged<_PlatformPanelOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textMutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final option in options)
            ChoiceChip(
              label: Text(_platformEditorTitle(option.key)),
              labelPadding: EdgeInsets.only(
                left: option.exists ? 4 : 2,
                right: 8,
              ),
              selected:
                  option.exists &&
                  selectedKey != null &&
                  _normalizedPlatformKey(selectedKey!) ==
                      _normalizedPlatformKey(option.key),
              avatarBoxConstraints: option.exists
                  ? null
                  : const BoxConstraints.tightFor(width: 14, height: 14),
              avatar: option.exists
                  ? null
                  : const Icon(Icons.add_rounded, size: 16),
              onSelected: (_) => onSelected(option),
            ),
        ],
      ),
    );
  }
}

class _PlatformCoverageToggles extends StatelessWidget {
  const _PlatformCoverageToggles({
    required this.supportedPlatforms,
    required this.onToggle,
  });

  final List<String> supportedPlatforms;
  final void Function(String platform, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final supported = supportedPlatforms.toSet();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final platform in _coveragePlatforms)
          FilterChip(
            label: Text(_platformPillLabel(platform)),
            selected: supported.contains(platform),
            onSelected: (bool value) => onToggle(platform, value),
          ),
      ],
    );
  }
}

class _OverviewSectionMenu<T> extends StatelessWidget {
  const _OverviewSectionMenu({
    required this.items,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final List<T> items;
  final T value;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          ChoiceChip(
            label: Text(label(item)),
            selected: item == value,
            onSelected: (_) => onChanged(item),
          ),
      ],
    );
  }
}

extension on _ToolPlatformFilter {
  String get label {
    return switch (this) {
      _ToolPlatformFilter.all => 'Any platform',
      _ToolPlatformFilter.linuxOnly => 'Linux',
      _ToolPlatformFilter.macOsOnly => 'Mac OS',
      _ToolPlatformFilter.windowsOnly => 'Windows',
    };
  }
}

extension on _ToolSortMode {
  String get label {
    return switch (this) {
      _ToolSortMode.name => 'Sort: Name',
      _ToolSortMode.type => 'Sort: Type',
      _ToolSortMode.platform => 'Sort: Platform',
    };
  }
}

extension on _ToolDetailTab {
  String get label {
    return switch (this) {
      _ToolDetailTab.overview => 'Overview',
      _ToolDetailTab.access => 'Access',
      _ToolDetailTab.runtime => 'Runtime',
      _ToolDetailTab.document => 'Advanced',
    };
  }
}

extension on _ToolEntryKind {
  String get sectionId {
    return switch (this) {
      _ToolEntryKind.toolGroup => 'tool-groups',
      _ToolEntryKind.externalTool => 'cli-tools',
      _ToolEntryKind.mcpServer => 'mcp-servers',
    };
  }

  String get panelLabel {
    return switch (this) {
      _ToolEntryKind.toolGroup => 'Groups',
      _ToolEntryKind.externalTool => 'CLI Tools',
      _ToolEntryKind.mcpServer => 'MCP Servers',
    };
  }

  IconData get panelIcon {
    return switch (this) {
      _ToolEntryKind.toolGroup => Icons.create_new_folder_outlined,
      _ToolEntryKind.externalTool => Icons.terminal_rounded,
      _ToolEntryKind.mcpServer => Icons.hub_outlined,
    };
  }

  String get label {
    return switch (this) {
      _ToolEntryKind.toolGroup => 'Group',
      _ToolEntryKind.externalTool => 'CLI',
      _ToolEntryKind.mcpServer => 'MCP',
    };
  }

  Color get tone {
    return switch (this) {
      _ToolEntryKind.toolGroup => accentColor,
      _ToolEntryKind.externalTool => infoColor,
      _ToolEntryKind.mcpServer => successColor,
    };
  }

  String get emptyLabel {
    return switch (this) {
      _ToolEntryKind.toolGroup => 'groups',
      _ToolEntryKind.externalTool => 'CLI tools',
      _ToolEntryKind.mcpServer => 'MCP servers',
    };
  }

  String get emptySearchDescription {
    return switch (this) {
      _ToolEntryKind.toolGroup => 'tool groups',
      _ToolEntryKind.externalTool => 'CLI tools',
      _ToolEntryKind.mcpServer => 'MCP servers',
    };
  }

  String get createLabel {
    return switch (this) {
      _ToolEntryKind.toolGroup => 'New Group',
      _ToolEntryKind.externalTool => 'New CLI',
      _ToolEntryKind.mcpServer => 'New MCP',
    };
  }

  IconData get createIcon {
    return switch (this) {
      _ToolEntryKind.toolGroup => Icons.create_new_folder_outlined,
      _ToolEntryKind.externalTool => Icons.terminal_rounded,
      _ToolEntryKind.mcpServer => Icons.hub_outlined,
    };
  }
}

extension on _ToolPlatformGroup {
  int get sortRank {
    return switch (this) {
      _ToolPlatformGroup.toolGroups => 0,
      _ToolPlatformGroup.allPlatforms => 1,
      _ToolPlatformGroup.linuxOnly => 2,
      _ToolPlatformGroup.macOsOnly => 3,
      _ToolPlatformGroup.windowsOnly => 4,
      _ToolPlatformGroup.customPlatforms => 5,
    };
  }
}

class HarnessToolsWorkspace extends StatefulWidget {
  const HarnessToolsWorkspace({
    super.key,
    required this.catalog,
    required this.documentYaml,
    required this.validation,
    required this.onCatalogChanged,
  });

  final HarnessToolCatalog catalog;
  final String documentYaml;
  final HarnessConfigValidationReport? validation;
  final ValueChanged<HarnessToolCatalog> onCatalogChanged;

  @override
  State<HarnessToolsWorkspace> createState() => _HarnessToolsWorkspaceState();
}

class _HarnessToolsWorkspaceState extends State<HarnessToolsWorkspace> {
  late _ToolWorkspaceSnapshot _snapshot;
  String? _selectedEntryId;
  _ToolPlatformFilter _platformFilter = _ToolPlatformFilter.all;
  _ToolSortMode _sortMode = _ToolSortMode.platform;
  _ToolDetailTab _detailTab = _ToolDetailTab.overview;

  @override
  void initState() {
    super.initState();
    _snapshot = _ToolWorkspaceSnapshot.fromCatalog(widget.catalog);
    _ensureSelection();
  }

  @override
  void didUpdateWidget(covariant HarnessToolsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_catalogEquals(oldWidget.catalog, widget.catalog)) {
      _snapshot = _ToolWorkspaceSnapshot.fromCatalog(widget.catalog);
      _ensureSelection();
    }
  }

  bool _catalogEquals(HarnessToolCatalog left, HarnessToolCatalog right) {
    if (left.configPath != right.configPath || left.yaml != right.yaml) {
      return false;
    }
    return left.toolGroups.length == right.toolGroups.length &&
        left.externalTools.length == right.externalTools.length &&
        left.mcpServers.length == right.mcpServers.length;
  }

  void _ensureSelection() {
    if (_selectedEntryId != null &&
        _snapshot.entries.any(
          (_ToolWorkspaceEntry entry) => entry.id == _selectedEntryId,
        )) {
      return;
    }
    _selectedEntryId = _snapshot.entries.isEmpty
        ? null
        : _snapshot.entries.first.id;
  }

  _ToolWorkspaceEntry? get _selectedEntry {
    final selectedId = _selectedEntryId;
    if (selectedId == null) {
      return _snapshot.entries.isEmpty ? null : _snapshot.entries.first;
    }
    for (final entry in _snapshot.entries) {
      if (entry.id == selectedId) {
        return entry;
      }
    }
    return _snapshot.entries.isEmpty ? null : _snapshot.entries.first;
  }

  bool _matchesPlatformFilter(_ToolWorkspaceEntry entry) {
    return switch (_platformFilter) {
      _ToolPlatformFilter.all => true,
      _ToolPlatformFilter.linuxOnly => entry.supportsPlatform('linux'),
      _ToolPlatformFilter.macOsOnly => entry.supportsPlatform('darwin'),
      _ToolPlatformFilter.windowsOnly => entry.supportsPlatform('windows'),
    };
  }

  void _sortEntries(List<_ToolWorkspaceEntry> entries) {
    entries.sort((_ToolWorkspaceEntry left, _ToolWorkspaceEntry right) {
      return switch (_sortMode) {
        _ToolSortMode.name => left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        ),
        _ToolSortMode.type => _compareStrings(
          left.kind.label,
          right.kind.label,
          fallbackLeft: left.name,
          fallbackRight: right.name,
        ),
        _ToolSortMode.platform => _comparePlatformGroups(left, right),
      };
    });
  }

  List<_ToolWorkspaceEntry> _entriesForKind(_ToolEntryKind kind) {
    final entries = _snapshot.entries
        .where((_ToolWorkspaceEntry entry) => entry.kind == kind)
        .where(_matchesPlatformFilter)
        .toList(growable: false);
    final sortedEntries = entries.toList();
    _sortEntries(sortedEntries);
    return sortedEntries;
  }

  void _selectFirstEntryForKind(_ToolEntryKind kind) {
    final nextEntry = _entriesForKind(kind).firstOrNull;
    setState(() {
      _selectedEntryId = nextEntry?.id;
      _detailTab = _ToolDetailTab.overview;
    });
  }

  void _pushCatalog(HarnessToolCatalog catalog, {String? selectedEntryId}) {
    widget.onCatalogChanged(catalog);
    setState(() {
      _snapshot = _ToolWorkspaceSnapshot.fromCatalog(catalog);
      _selectedEntryId = selectedEntryId ?? _selectedEntryId;
      _ensureSelection();
    });
  }

  String _nextUniqueName(String base, Iterable<String> existingNames) {
    final existing = existingNames.toSet();
    if (!existing.contains(base)) {
      return base;
    }
    var suffix = 2;
    while (existing.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }

  void _createToolGroup() {
    final name = _nextUniqueName(
      'new-tool-group',
      widget.catalog.toolGroups.map(
        (HarnessToolGroupSummary group) => group.name,
      ),
    );
    final next = widget.catalog.copyWith(
      toolGroups: <HarnessToolGroupSummary>[
        ...widget.catalog.toolGroups,
        HarnessToolGroupSummary(name: name, tools: const <String>[]),
      ],
    );
    _pushCatalog(next, selectedEntryId: 'group:${next.toolGroups.length - 1}');
  }

  void _createExternalTool() {
    final name = _nextUniqueName(
      'new-cli-tool',
      widget.catalog.externalTools.map(
        (HarnessExternalToolSummary tool) => tool.name,
      ),
    );
    final next = widget.catalog.copyWith(
      externalTools: <HarnessExternalToolSummary>[
        ...widget.catalog.externalTools,
        HarnessExternalToolSummary(
          name: name,
          inputSchema: const <String, dynamic>{},
          filesystem: 'read',
          network: false,
          idempotent: true,
          timeoutSeconds: 30,
          command: const <String>[],
          args: const <String>[],
          workingDir: '',
          env: const <String, String>{},
          inheritEnv: false,
          stdinMode: '',
          tempFiles: const <HarnessExternalToolTempFile>[],
          outputFormat: 'text',
          platforms: const <String, HarnessExternalToolPlatformSummary>{},
        ),
      ],
    );
    _pushCatalog(
      next,
      selectedEntryId: 'external:${next.externalTools.length - 1}',
    );
  }

  void _createMcpServer() {
    final name = _nextUniqueName(
      'new-mcp-server',
      widget.catalog.mcpServers.map(
        (HarnessMcpServerSummary server) => server.name,
      ),
    );
    final next = widget.catalog.copyWith(
      mcpServers: <HarnessMcpServerSummary>[
        ...widget.catalog.mcpServers,
        HarnessMcpServerSummary(
          name: name,
          lifecycle: 'persistent',
          transport: 'stdio',
          url: '',
          healthcheckUrl: '',
          command: const <String>[],
          args: const <String>[],
          workingDir: '',
          env: const <String, String>{},
          inheritEnv: false,
          timeoutSeconds: 30,
          startupTimeoutSeconds: 30,
          shutdownTimeoutSeconds: 15,
          toolNamePrefix: '',
          includeTools: const <String>[],
          excludeTools: const <String>[],
          filesystem: '',
          network: false,
          idempotent: false,
          platforms: const <String, HarnessMcpServerPlatformSummary>{},
        ),
      ],
    );
    _pushCatalog(next, selectedEntryId: 'mcp:${next.mcpServers.length - 1}');
  }

  void _replaceToolGroup(int index, HarnessToolGroupSummary value) {
    final nextGroups = widget.catalog.toolGroups.toList();
    nextGroups[index] = value;
    _pushCatalog(
      widget.catalog.copyWith(toolGroups: nextGroups),
      selectedEntryId: 'group:$index',
    );
  }

  void _replaceExternalTool(int index, HarnessExternalToolSummary value) {
    final nextTools = widget.catalog.externalTools.toList();
    nextTools[index] = value;
    _pushCatalog(
      widget.catalog.copyWith(externalTools: nextTools),
      selectedEntryId: 'external:$index',
    );
  }

  void _replaceMcpServer(int index, HarnessMcpServerSummary value) {
    final nextServers = widget.catalog.mcpServers.toList();
    nextServers[index] = value;
    _pushCatalog(
      widget.catalog.copyWith(mcpServers: nextServers),
      selectedEntryId: 'mcp:$index',
    );
  }

  void _changeEntryKind(_ToolWorkspaceEntry entry, _ToolEntryKind nextKind) {
    if (entry.kind == nextKind ||
        entry.kind == _ToolEntryKind.toolGroup ||
        nextKind == _ToolEntryKind.toolGroup) {
      return;
    }

    final existingNames = <String>[
      ...widget.catalog.externalTools.map(
        (HarnessExternalToolSummary tool) => tool.name,
      ),
      ...widget.catalog.mcpServers.map(
        (HarnessMcpServerSummary server) => server.name,
      ),
    ]..remove(entry.name);
    final nextName = _nextUniqueName(entry.name, existingNames);

    switch (entry.kind) {
      case _ToolEntryKind.toolGroup:
        return;
      case _ToolEntryKind.externalTool:
        final source = widget.catalog.externalTools[entry.sourceIndex];
        final nextTools = widget.catalog.externalTools.toList()
          ..removeAt(entry.sourceIndex);
        final nextServers = widget.catalog.mcpServers.toList();
        final insertIndex = nextServers.length;
        nextServers.add(_externalToolToMcpServer(source, name: nextName));
        _pushCatalog(
          widget.catalog.copyWith(
            externalTools: nextTools,
            mcpServers: nextServers,
          ),
          selectedEntryId: 'mcp:$insertIndex',
        );
      case _ToolEntryKind.mcpServer:
        final source = widget.catalog.mcpServers[entry.sourceIndex];
        final nextServers = widget.catalog.mcpServers.toList()
          ..removeAt(entry.sourceIndex);
        final nextTools = widget.catalog.externalTools.toList();
        final insertIndex = nextTools.length;
        nextTools.add(_mcpServerToExternalTool(source, name: nextName));
        _pushCatalog(
          widget.catalog.copyWith(
            externalTools: nextTools,
            mcpServers: nextServers,
          ),
          selectedEntryId: 'external:$insertIndex',
        );
    }
  }

  void _deleteEntry(_ToolWorkspaceEntry entry) {
    switch (entry.kind) {
      case _ToolEntryKind.toolGroup:
        final nextGroups = widget.catalog.toolGroups.toList()
          ..removeAt(entry.sourceIndex);
        _pushCatalog(widget.catalog.copyWith(toolGroups: nextGroups));
      case _ToolEntryKind.externalTool:
        final toolName = widget.catalog.externalTools[entry.sourceIndex].name;
        final nextTools = widget.catalog.externalTools.toList()
          ..removeAt(entry.sourceIndex);
        final nextGroups = widget.catalog.toolGroups
            .map(
              (HarnessToolGroupSummary group) => group.copyWith(
                tools: group.tools
                    .where((String member) => member != toolName)
                    .toList(),
              ),
            )
            .toList();
        _pushCatalog(
          widget.catalog.copyWith(
            externalTools: nextTools,
            toolGroups: nextGroups,
          ),
        );
      case _ToolEntryKind.mcpServer:
        final serverName = widget.catalog.mcpServers[entry.sourceIndex].name;
        final nextServers = widget.catalog.mcpServers.toList()
          ..removeAt(entry.sourceIndex);
        final nextGroups = widget.catalog.toolGroups
            .map(
              (HarnessToolGroupSummary group) => group.copyWith(
                tools: group.tools
                    .where((String member) => member != serverName)
                    .toList(),
              ),
            )
            .toList();
        _pushCatalog(
          widget.catalog.copyWith(
            mcpServers: nextServers,
            toolGroups: nextGroups,
          ),
        );
    }
  }

  int _compareStrings(
    String left,
    String right, {
    required String fallbackLeft,
    required String fallbackRight,
  }) {
    final primary = left.toLowerCase().compareTo(right.toLowerCase());
    if (primary != 0) {
      return primary;
    }
    return fallbackLeft.toLowerCase().compareTo(fallbackRight.toLowerCase());
  }

  int _comparePlatformGroups(
    _ToolWorkspaceEntry left,
    _ToolWorkspaceEntry right,
  ) {
    final platformCompare = left.platformGroup.sortRank.compareTo(
      right.platformGroup.sortRank,
    );
    if (platformCompare != 0) {
      return platformCompare;
    }
    final typeCompare = left.kind.label.toLowerCase().compareTo(
      right.kind.label,
    );
    if (typeCompare != 0) {
      return typeCompare;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntry = _selectedEntry;
    final entriesByKind = <_ToolEntryKind, List<_ToolWorkspaceEntry>>{
      for (final kind in _ToolEntryKind.values) kind: _entriesForKind(kind),
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1120;

        final collectionPane = _ToolsCollectionPane(
          entriesByKind: entriesByKind,
          initialSectionId: selectedEntry?.kind.sectionId,
          platformFilter: _platformFilter,
          sortMode: _sortMode,
          selectedEntryId: selectedEntry?.id,
          onSectionChanged: _selectFirstEntryForKind,
          onPlatformFilterChanged: (_ToolPlatformFilter value) {
            setState(() => _platformFilter = value);
          },
          onSortModeChanged: (_ToolSortMode value) {
            setState(() => _sortMode = value);
          },
          onSelectEntry: (_ToolWorkspaceEntry entry) {
            setState(() {
              _selectedEntryId = entry.id;
              _detailTab = _ToolDetailTab.overview;
            });
          },
          onCreateToolGroup: _createToolGroup,
          onCreateExternalTool: _createExternalTool,
          onCreateMcpServer: _createMcpServer,
        );

        final detailPane = _ToolDetailPane(
          catalog: widget.catalog,
          configPath: widget.catalog.configPath,
          selectedEntry: selectedEntry,
          activeTab: _detailTab,
          validation: widget.validation,
          onTabChanged: (_ToolDetailTab value) {
            setState(() => _detailTab = value);
          },
          onReplaceToolGroup: _replaceToolGroup,
          onReplaceExternalTool: _replaceExternalTool,
          onReplaceMcpServer: _replaceMcpServer,
          onChangeEntryKind: _changeEntryKind,
          onDeleteEntry: _deleteEntry,
        );

        return ConfigWorkspaceShell(
          stacked: stacked,
          collectionPane: collectionPane,
          detailPane: detailPane,
          collectionFlex: 52,
          detailFlex: 48,
          stackedCollectionFlex: 46,
          stackedDetailFlex: 54,
        );
      },
    );
  }
}
