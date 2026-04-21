import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/shared/side_panel.dart';
import 'package:ui/shared/ui.dart';
import 'package:ui/shared/workspace_shell.dart';

class HarnessRulesWorkspace extends StatefulWidget {
  const HarnessRulesWorkspace({
    super.key,
    required this.catalog,
    required this.controller,
    required this.validation,
  });

  final HarnessWorkflowCatalog catalog;
  final TextEditingController controller;
  final HarnessConfigValidationReport? validation;

  @override
  State<HarnessRulesWorkspace> createState() => _HarnessRulesWorkspaceState();
}

class _HarnessRulesWorkspaceState extends State<HarnessRulesWorkspace> {
  static const String _rulesSectionId = 'rules-catalog';
  static const String _ruleSetsSectionId = 'rule-sets-catalog';

  Map<String, Object?> _documentExtras = <String, Object?>{};
  List<Object?> _rawRules = <Object?>[];
  List<Object?> _rawRuleSets = <Object?>[];
  String _searchQuery = '';
  String? _selectedEntryId;
  int _editorVersion = 0;
  String? _catalogParseError;

  @override
  void initState() {
    super.initState();
    _loadDraftsFromSource();
  }

  @override
  void didUpdateWidget(covariant HarnessRulesWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog.yaml != widget.catalog.yaml ||
        oldWidget.catalog.configPath != widget.catalog.configPath ||
        oldWidget.catalog.rules.length != widget.catalog.rules.length ||
        oldWidget.catalog.ruleSets.length != widget.catalog.ruleSets.length) {
      _loadDraftsFromSource(preserveSelection: true);
    }
  }

  void _loadDraftsFromSource({bool preserveSelection = false}) {
    final previousSelection = preserveSelection
        ? _selectedEntry?.entryKey
        : null;

    Map<String, Object?> extras = <String, Object?>{};
    List<Object?> rawRules = <Object?>[];
    List<Object?> rawRuleSets = <Object?>[];
    String? parseError;

    try {
      final document = _MiniYamlParser(widget.controller.text).parseDocument();
      if (document is! Map<String, Object?>) {
        throw const _MiniYamlException('Expected a map at the document root.');
      }
      extras = LinkedHashMap<String, Object?>.from(document)
        ..remove('rules')
        ..remove('rule_sets');
      rawRules =
          ((document['rules'] as List<Object?>?) ?? const <Object?>[]).toList();
      rawRuleSets =
          ((document['rule_sets'] as List<Object?>?) ?? const <Object?>[])
              .toList();
    } on _MiniYamlException catch (error) {
      parseError = error.message;
    } catch (error) {
      parseError = error.toString();
    }

    if (rawRules.isEmpty) {
      rawRules = widget.catalog.rules
          .map(
            (HarnessWorkflowRuleSummary value) => <String, Object?>{
              'name': value.name,
              if (value.file.isNotEmpty) 'file': value.file,
            },
          )
          .toList(growable: false);
    }

    if (rawRuleSets.isEmpty) {
      rawRuleSets = widget.catalog.ruleSets
          .map(
            (HarnessWorkflowRuleSetSummary value) => <String, Object?>{
              'name': value.name,
              if (value.rules.isNotEmpty) 'rules': value.rules,
              if (value.maxCycle > 0) 'max_cycle': value.maxCycle,
              if (value.returnErrorOnFailedRuleEvaluation != null)
                'return_error_on_failed_rule_evaluation':
                    value.returnErrorOnFailedRuleEvaluation,
              if (value.failClosed != null) 'fail_closed': value.failClosed,
            },
          )
          .toList(growable: false);
    }

    setState(() {
      _documentExtras = extras;
      _rawRules = rawRules;
      _rawRuleSets = rawRuleSets;
      _catalogParseError = parseError;
      _editorVersion += 1;
      _restoreSelection(preferredEntryKey: previousSelection);
    });
    _syncControllerFromDrafts();
  }

  List<_IndexedSharedRuleDraft> get _indexedRules {
    final drafts = <_IndexedSharedRuleDraft>[];
    for (int index = 0; index < _rawRules.length; index++) {
      final raw = _rawRules[index];
      if (raw is! Map<String, Object?>) {
        continue;
      }
      drafts.add(
        _IndexedSharedRuleDraft(
          rawIndex: index,
          draft: _WorkflowRuleDraft.fromYaml(raw),
        ),
      );
    }
    return drafts;
  }

  List<_IndexedSharedRuleSetDraft> get _indexedRuleSets {
    final drafts = <_IndexedSharedRuleSetDraft>[];
    for (int index = 0; index < _rawRuleSets.length; index++) {
      final raw = _rawRuleSets[index];
      if (raw is! Map<String, Object?>) {
        continue;
      }
      drafts.add(
        _IndexedSharedRuleSetDraft(
          rawIndex: index,
          draft: _WorkflowRuleSetDraft.fromYaml(raw),
        ),
      );
    }
    return drafts;
  }

  int get _unsupportedEntryCount =>
      _rawRules.where((Object? value) => value is! Map<String, Object?>).length +
      _rawRuleSets.where((Object? value) => value is! Map<String, Object?>).length;

  List<_RulesWorkspaceEntry> get _entries => <_RulesWorkspaceEntry>[
    ..._indexedRules.map(
      (_IndexedSharedRuleDraft value) => _RulesWorkspaceEntry(
        kind: _RulesWorkspaceEntryKind.rule,
        rawIndex: value.rawIndex,
      ),
    ),
    ..._indexedRuleSets.map(
      (_IndexedSharedRuleSetDraft value) => _RulesWorkspaceEntry(
        kind: _RulesWorkspaceEntryKind.ruleSet,
        rawIndex: value.rawIndex,
      ),
    ),
  ];

  _RulesWorkspaceEntry? get _selectedEntry {
    final entries = _entries;
    if (entries.isEmpty) {
      return null;
    }
    final selectedEntryId = _selectedEntryId;
    if (selectedEntryId == null) {
      return entries.first;
    }
    return entries.where((_RulesWorkspaceEntry value) => value.entryId == selectedEntryId).firstOrNull ??
        entries.first;
  }

  _IndexedSharedRuleDraft? get _selectedRule {
    final entry = _selectedEntry;
    if (entry == null || entry.kind != _RulesWorkspaceEntryKind.rule) {
      return null;
    }
    return _indexedRules
        .where((_IndexedSharedRuleDraft value) => value.rawIndex == entry.rawIndex)
        .firstOrNull;
  }

  _IndexedSharedRuleSetDraft? get _selectedRuleSet {
    final entry = _selectedEntry;
    if (entry == null || entry.kind != _RulesWorkspaceEntryKind.ruleSet) {
      return null;
    }
    return _indexedRuleSets
        .where((_IndexedSharedRuleSetDraft value) => value.rawIndex == entry.rawIndex)
        .firstOrNull;
  }

  void _restoreSelection({String? preferredEntryKey}) {
    final entries = _entries;
    if (entries.isEmpty) {
      _selectedEntryId = null;
      return;
    }
    final selected = entries.firstWhere(
      (_RulesWorkspaceEntry value) => value.entryKey == preferredEntryKey,
      orElse: () => entries.first,
    );
    _selectedEntryId = selected.entryId;
  }

  void _syncControllerFromDrafts() {
    final root = <String, Object?>{}..addAll(_documentExtras);
    if (_rawRules.isNotEmpty) {
      root['rules'] = _rawRules;
    }
    if (_rawRuleSets.isNotEmpty) {
      root['rule_sets'] = _rawRuleSets;
    }
    final yaml = _MiniYamlWriter.serialize(root);
    if (widget.controller.text == yaml) {
      return;
    }
    widget.controller.value = TextEditingValue(
      text: yaml,
      selection: TextSelection.collapsed(offset: yaml.length),
    );
  }

  String _fieldKey(String field) => 'shared-rules|$field|$_editorVersion';

  List<String> _ruleOptions({String currentValue = ''}) {
    final options = LinkedHashSet<String>.from(
      _indexedRules
          .map((_IndexedSharedRuleDraft value) => value.draft.name)
          .where((String value) => value.trim().isNotEmpty),
    );
    if (currentValue.trim().isNotEmpty) {
      options.add(currentValue.trim());
    }
    return options.toList(growable: false);
  }

  List<String> _ruleSetOptions({String currentValue = ''}) {
    final options = LinkedHashSet<String>.from(
      _indexedRuleSets
          .map((_IndexedSharedRuleSetDraft value) => value.draft.name)
          .where((String value) => value.trim().isNotEmpty),
    );
    if (currentValue.trim().isNotEmpty) {
      options.add(currentValue.trim());
    }
    return options.toList(growable: false);
  }

  String _nextRuleName() {
    final existing = _ruleOptions().toSet();
    for (int index = 1; ; index++) {
      final candidate = 'rule_$index';
      if (!existing.contains(candidate)) {
        return candidate;
      }
    }
  }

  String _nextRuleSetName() {
    final existing = _ruleSetOptions().toSet();
    for (int index = 1; ; index++) {
      final candidate = 'rule_set_$index';
      if (!existing.contains(candidate)) {
        return candidate;
      }
    }
  }

  void _selectEntry(_RulesWorkspaceEntry entry) {
    setState(() {
      _selectedEntryId = entry.entryId;
    });
  }

  void _addRule() {
    setState(() {
      _rawRules = <Object?>[
        ..._rawRules,
        _WorkflowRuleDraft(
          name: _nextRuleName(),
          file: '${_nextRuleName()}.grl',
        ).toYamlMap(),
      ];
      _selectedEntryId =
          '${_RulesWorkspaceEntryKind.rule.name}:${_rawRules.length - 1}';
      _editorVersion += 1;
      _syncControllerFromDrafts();
    });
  }

  void _addRuleSet() {
    setState(() {
      _rawRuleSets = <Object?>[
        ..._rawRuleSets,
        _WorkflowRuleSetDraft(
          name: _nextRuleSetName(),
          rules: _indexedRules.isEmpty ? const <String>[] : <String>[_indexedRules.first.draft.name],
          returnErrorOnFailedRuleEvaluation: true,
          failClosed: true,
        ).toYamlMap(),
      ];
      _selectedEntryId =
          '${_RulesWorkspaceEntryKind.ruleSet.name}:${_rawRuleSets.length - 1}';
      _editorVersion += 1;
      _syncControllerFromDrafts();
    });
  }

  void _updateRule(
    int rawIndex,
    void Function(_WorkflowRuleDraft draft) mutate,
  ) {
    if (rawIndex < 0 || rawIndex >= _rawRules.length) {
      return;
    }
    final raw = _rawRules[rawIndex];
    if (raw is! Map<String, Object?>) {
      return;
    }
    final draft = _WorkflowRuleDraft.fromYaml(raw);
    mutate(draft);
    setState(() {
      _rawRules[rawIndex] = draft.toYamlMap();
      _syncControllerFromDrafts();
    });
  }

  void _updateRuleSet(
    int rawIndex,
    void Function(_WorkflowRuleSetDraft draft) mutate,
  ) {
    if (rawIndex < 0 || rawIndex >= _rawRuleSets.length) {
      return;
    }
    final raw = _rawRuleSets[rawIndex];
    if (raw is! Map<String, Object?>) {
      return;
    }
    final draft = _WorkflowRuleSetDraft.fromYaml(raw);
    mutate(draft);
    setState(() {
      _rawRuleSets[rawIndex] = draft.toYamlMap();
      _syncControllerFromDrafts();
    });
  }

  void _deleteRule(int rawIndex) {
    if (rawIndex < 0 || rawIndex >= _rawRules.length) {
      return;
    }
    setState(() {
      final deleted = _rawRules[rawIndex];
      String deletedName = '';
      if (deleted is Map<String, Object?>) {
        deletedName = _WorkflowRuleDraft.fromYaml(deleted).name;
      }
      _rawRules.removeAt(rawIndex);
      if (deletedName.isNotEmpty) {
        for (int index = 0; index < _rawRuleSets.length; index++) {
          final raw = _rawRuleSets[index];
          if (raw is! Map<String, Object?>) {
            continue;
          }
          final draft = _WorkflowRuleSetDraft.fromYaml(raw);
          draft.rules = draft.rules
              .where((String value) => value.trim() != deletedName)
              .toList(growable: false);
          _rawRuleSets[index] = draft.toYamlMap();
        }
      }
      final entries = _entries;
      _selectedEntryId = entries.isEmpty ? null : entries.first.entryId;
      _editorVersion += 1;
      _syncControllerFromDrafts();
    });
  }

  void _deleteRuleSet(int rawIndex) {
    if (rawIndex < 0 || rawIndex >= _rawRuleSets.length) {
      return;
    }
    setState(() {
      _rawRuleSets.removeAt(rawIndex);
      final entries = _entries;
      _selectedEntryId = entries.isEmpty ? null : entries.first.entryId;
      _editorVersion += 1;
      _syncControllerFromDrafts();
    });
  }

  String _subtitleForRule(_WorkflowRuleDraft rule) {
    if (rule.file.trim().isEmpty) {
      return 'No GRL file configured';
    }
    return rule.file.trim();
  }

  String _subtitleForRuleSet(_WorkflowRuleSetDraft ruleSet) {
    final ruleCount = ruleSet.rules.length;
    if (ruleCount == 0) {
      return 'No rules selected';
    }
    return '$ruleCount rule${ruleCount == 1 ? '' : 's'}';
  }

  Widget _buildCollectionPane() {
    final indexedRules = _indexedRules;
    final indexedRuleSets = _indexedRuleSets;
    return AppDenseSidePanel<_RulesWorkspaceEntry>(
      initialSectionId: _rulesSectionId,
      initialSearchQuery: _searchQuery,
      onSearchChanged: (String value) {
        setState(() => _searchQuery = value);
      },
      selectedEntryId: _selectedEntry?.entryId,
      entryId: (_RulesWorkspaceEntry entry) => entry.entryId,
      onSelectEntry: _selectEntry,
      searchHintText: 'Search rules and rule sets...',
      emptyTitle: 'No rules',
      emptyBody:
          'Reusable GRL rules and rule sets will appear here once the catalog loads.',
      sections: <AppDenseSidePanelSection<_RulesWorkspaceEntry>>[
        AppDenseSidePanelSection<_RulesWorkspaceEntry>(
          id: _rulesSectionId,
          label: 'Rules',
          icon: Icons.rule_folder_outlined,
          entries: indexedRules
              .map(
                (_IndexedSharedRuleDraft value) => _RulesWorkspaceEntry(
                  kind: _RulesWorkspaceEntryKind.rule,
                  rawIndex: value.rawIndex,
                ),
              )
              .toList(growable: false),
          searchFields: (_RulesWorkspaceEntry entry) => <String>[
            _indexedRules
                    .where(
                      (_IndexedSharedRuleDraft value) =>
                          value.rawIndex == entry.rawIndex,
                    )
                    .firstOrNull
                    ?.draft
                    .name ??
                '',
          ],
          headerBuilder:
              (
                BuildContext context,
                List<_RulesWorkspaceEntry> entries,
                List<_RulesWorkspaceEntry> filteredEntries,
                String searchQuery,
              ) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entries.length} shared rule${entries.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: textMutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _addRule,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add rule'),
                    ),
                  ],
                );
              },
          rowBuilder:
              (
                BuildContext context,
                _RulesWorkspaceEntry entry,
                bool selected,
                VoidCallback onTap,
              ) {
                final rule = _indexedRules
                    .where(
                      (_IndexedSharedRuleDraft value) =>
                          value.rawIndex == entry.rawIndex,
                    )
                    .first
                    .draft;
                return AppDenseSidePanelRow(
                  title: rule.name.isEmpty ? 'Unnamed rule' : rule.name,
                  subtitle: _subtitleForRule(rule),
                  selected: selected,
                  onTap: onTap,
                  footer: <Widget>[
                    const StatusPill(label: 'grl', color: infoColor),
                  ],
                );
              },
          emptyTitle: 'No shared rules',
          emptyBody:
              'Add a rule here, then select it from workflow check steps.',
        ),
        AppDenseSidePanelSection<_RulesWorkspaceEntry>(
          id: _ruleSetsSectionId,
          label: 'Rule Sets',
          icon: Icons.library_books_outlined,
          entries: indexedRuleSets
              .map(
                (_IndexedSharedRuleSetDraft value) => _RulesWorkspaceEntry(
                  kind: _RulesWorkspaceEntryKind.ruleSet,
                  rawIndex: value.rawIndex,
                ),
              )
              .toList(growable: false),
          searchFields: (_RulesWorkspaceEntry entry) => <String>[
            _indexedRuleSets
                    .where(
                      (_IndexedSharedRuleSetDraft value) =>
                          value.rawIndex == entry.rawIndex,
                    )
                    .firstOrNull
                    ?.draft
                    .name ??
                '',
          ],
          headerBuilder:
              (
                BuildContext context,
                List<_RulesWorkspaceEntry> entries,
                List<_RulesWorkspaceEntry> filteredEntries,
                String searchQuery,
              ) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entries.length} rule set${entries.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: textMutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _addRuleSet,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add rule set'),
                    ),
                  ],
                );
              },
          rowBuilder:
              (
                BuildContext context,
                _RulesWorkspaceEntry entry,
                bool selected,
                VoidCallback onTap,
              ) {
                final ruleSet = _indexedRuleSets
                    .where(
                      (_IndexedSharedRuleSetDraft value) =>
                          value.rawIndex == entry.rawIndex,
                    )
                    .first
                    .draft;
                return AppDenseSidePanelRow(
                  title: ruleSet.name.isEmpty ? 'Unnamed rule set' : ruleSet.name,
                  subtitle: _subtitleForRuleSet(ruleSet),
                  selected: selected,
                  onTap: onTap,
                  footer: <Widget>[
                    const StatusPill(label: 'set', color: successColor),
                  ],
                );
              },
          emptyTitle: 'No rule sets',
          emptyBody:
              'Add a rule set here, then select it from workflow check steps.',
        ),
      ],
    );
  }

  Widget _buildDetailPane() {
    final selectedRule = _selectedRule;
    final selectedRuleSet = _selectedRuleSet;
    return Container(
      padding: const EdgeInsets.all(20),
      child: selectedRule == null && selectedRuleSet == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    title: 'No item selected',
                    body:
                        'Pick a rule or rule set on the left, or create one here to manage it.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _addRule,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add rule'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addRuleSet,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add rule set'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.validation != null) ...[
                    _WorkflowValidationSummaryCard(report: widget.validation!),
                  ],
                  if (_catalogParseError != null) ...[
                    const SizedBox(height: 12),
                    InfoPanel(
                      title: 'Source fallback in use',
                      body:
                          'The YAML document could not be parsed cleanly, so this screen fell back to the catalog summary. Parse error: $_catalogParseError',
                    ),
                  ],
                  if (_unsupportedEntryCount > 0) ...[
                    const SizedBox(height: 12),
                    InfoPanel(
                      title: 'Some entries still need YAML',
                      body:
                          '$_unsupportedEntryCount rule or rule set ${_unsupportedEntryCount == 1 ? 'entry uses' : 'entries use'} shapes this editor does not model directly yet. They are preserved in the underlying document.',
                    ),
                  ],
                  SizedBox(height: widget.validation == null ? 0 : 16),
                  if (selectedRule != null)
                    _buildRuleEditor(
                      rawIndex: selectedRule.rawIndex,
                      rule: selectedRule.draft,
                    ),
                  if (selectedRuleSet != null)
                    _buildRuleSetEditor(
                      rawIndex: selectedRuleSet.rawIndex,
                      ruleSet: selectedRuleSet.draft,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildRuleEditor({
    required int rawIndex,
    required _WorkflowRuleDraft rule,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: infoColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name.isEmpty ? 'Unnamed rule' : rule.name,
                      style: const TextStyle(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleForRule(rule),
                      style: const TextStyle(color: textMutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const StatusPill(label: 'grl', color: infoColor),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove rule',
                onPressed: () => _deleteRule(rawIndex),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InspectorTextField(
            key: ValueKey(_fieldKey('rule_${rawIndex}_name')),
            label: 'Rule name',
            initialValue: rule.name,
            helperText:
                'Rule sets reference this shared name. Keep it stable when the same rule is reused.',
            onChanged: (String value) {
              _updateRule(rawIndex, (_WorkflowRuleDraft target) {
                target.name = _slugify(value);
              });
            },
          ),
          const SizedBox(height: 12),
          _InspectorTextField(
            key: ValueKey(_fieldKey('rule_${rawIndex}_file')),
            label: 'GRL file',
            initialValue: rule.file,
            helperText:
                'Relative `.grl` file path inside the app config folder.',
            onChanged: (String value) {
              _updateRule(rawIndex, (_WorkflowRuleDraft target) {
                target.file = value.trim();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSetEditor({
    required int rawIndex,
    required _WorkflowRuleSetDraft ruleSet,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: successColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ruleSet.name.isEmpty
                          ? 'Unnamed rule set'
                          : ruleSet.name,
                      style: const TextStyle(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleForRuleSet(ruleSet),
                      style: const TextStyle(color: textMutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const StatusPill(label: 'set', color: successColor),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove rule set',
                onPressed: () => _deleteRuleSet(rawIndex),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InspectorTextField(
            key: ValueKey(_fieldKey('rule_set_${rawIndex}_name')),
            label: 'Rule Set name',
            initialValue: ruleSet.name,
            helperText:
                'Workflow gates reference this shared name. Keep it stable when multiple workflows reuse this rule set.',
            onChanged: (String value) {
              _updateRuleSet(rawIndex, (_WorkflowRuleSetDraft target) {
                target.name = _slugify(value);
              });
            },
          ),
          const SizedBox(height: 12),
          _InspectorMultilineField(
            key: ValueKey(_fieldKey('rule_set_${rawIndex}_rules')),
            label: 'Rules',
            hintText: 'One rule name per line',
            helperText:
                _ruleOptions().isEmpty
                    ? 'Add rules first, then include them here.'
                    : 'Available rules: ${_ruleOptions().join(', ')}',
            initialValue: ruleSet.rules.join('\n'),
            onChanged: (String value) {
              _updateRuleSet(rawIndex, (_WorkflowRuleSetDraft target) {
                target.rules = _splitLines(value);
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InspectorNumberField(
                  key: ValueKey(_fieldKey('rule_set_${rawIndex}_max_cycle')),
                  label: 'Default max cycle',
                  initialValue: _intText(ruleSet.maxCycle),
                  helperText:
                      'Workflow gates can override this when a specific path needs a different cycle cap.',
                  onChanged: (int value) {
                    _updateRuleSet(rawIndex, (_WorkflowRuleSetDraft target) {
                      target.maxCycle = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InspectorToggleTile(
                  title: 'Default fail closed',
                  value: ruleSet.failClosed ?? true,
                  subtitle:
                      'Workflow gates can override this when they need a different failure mode.',
                  onChanged: (bool value) {
                    _updateRuleSet(rawIndex, (_WorkflowRuleSetDraft target) {
                      target.failClosed = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InspectorToggleTile(
            title: 'Default return evaluation errors',
            value: ruleSet.returnErrorOnFailedRuleEvaluation ?? true,
            subtitle:
                'Workflow gates can override this when they want softer evaluation behavior.',
            onChanged: (bool value) {
              _updateRuleSet(rawIndex, (_WorkflowRuleSetDraft target) {
                target.returnErrorOnFailedRuleEvaluation = value;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1180;
        return ConfigWorkspaceShell(
          stacked: stacked,
          collectionPane: _buildCollectionPane(),
          detailPane: _buildDetailPane(),
          collectionFlex: 34,
          detailFlex: 66,
          stackedCollectionFlex: 38,
          stackedDetailFlex: 62,
        );
      },
    );
  }
}

enum _RulesWorkspaceEntryKind { rule, ruleSet }

class _RulesWorkspaceEntry {
  const _RulesWorkspaceEntry({required this.kind, required this.rawIndex});

  final _RulesWorkspaceEntryKind kind;
  final int rawIndex;

  String get entryId => '${kind.name}:$rawIndex';

  String get entryKey => entryId;
}

class _IndexedSharedRuleDraft {
  const _IndexedSharedRuleDraft({required this.rawIndex, required this.draft});

  final int rawIndex;
  final _WorkflowRuleDraft draft;
}

class _IndexedSharedRuleSetDraft {
  const _IndexedSharedRuleSetDraft({
    required this.rawIndex,
    required this.draft,
  });

  final int rawIndex;
  final _WorkflowRuleSetDraft draft;
}

class HarnessWorkflowsWorkspace extends StatefulWidget {
  const HarnessWorkflowsWorkspace({
    super.key,
    required this.catalog,
    required this.controller,
    required this.runTargetOptions,
    required this.validation,
  });

  final HarnessWorkflowCatalog catalog;
  final TextEditingController controller;
  final List<String> runTargetOptions;
  final HarnessConfigValidationReport? validation;

  @override
  State<HarnessWorkflowsWorkspace> createState() =>
      _HarnessWorkflowsWorkspaceState();
}

enum _WorkflowCollectionSection { all }

extension on _WorkflowCollectionSection {
  String get sectionId {
    return switch (this) {
      _WorkflowCollectionSection.all => 'workflow-all',
    };
  }

  String get panelLabel {
    return switch (this) {
      _WorkflowCollectionSection.all => 'Workflows',
    };
  }

  IconData get panelIcon {
    return switch (this) {
      _WorkflowCollectionSection.all => Icons.account_tree_outlined,
    };
  }

  String get emptyTitle {
    return switch (this) {
      _WorkflowCollectionSection.all => 'No matching workflows',
    };
  }

  String get emptyBody {
    return switch (this) {
      _WorkflowCollectionSection.all =>
        'Try a different search term to find a workflow board in the catalog.',
    };
  }
}

enum _WorkflowInspectorPanel { overview, limits, rules, source }

extension on _WorkflowInspectorPanel {
  String get sectionId {
    return switch (this) {
      _WorkflowInspectorPanel.overview => 'workflow-inspector-overview',
      _WorkflowInspectorPanel.limits => 'workflow-inspector-limits',
      _WorkflowInspectorPanel.rules => 'workflow-inspector-rules',
      _WorkflowInspectorPanel.source => 'workflow-inspector-source',
    };
  }

  String get label {
    return switch (this) {
      _WorkflowInspectorPanel.overview => 'Overview',
      _WorkflowInspectorPanel.limits => 'Limits',
      _WorkflowInspectorPanel.rules => 'Policy',
      _WorkflowInspectorPanel.source => 'Source',
    };
  }

  IconData get icon {
    return switch (this) {
      _WorkflowInspectorPanel.overview => Icons.dashboard_customize_outlined,
      _WorkflowInspectorPanel.limits => Icons.speed_rounded,
      _WorkflowInspectorPanel.rules => Icons.rule_folder_outlined,
      _WorkflowInspectorPanel.source => Icons.code_rounded,
    };
  }
}

enum _NodeInspectorPanel { basics, behavior, routing, data, checks, completion }

extension on _NodeInspectorPanel {
  String get sectionId {
    return switch (this) {
      _NodeInspectorPanel.basics => 'node-inspector-basics',
      _NodeInspectorPanel.behavior => 'node-inspector-behavior',
      _NodeInspectorPanel.routing => 'node-inspector-routing',
      _NodeInspectorPanel.data => 'node-inspector-data',
      _NodeInspectorPanel.checks => 'node-inspector-checks',
      _NodeInspectorPanel.completion => 'node-inspector-completion',
    };
  }

  String get label {
    return switch (this) {
      _NodeInspectorPanel.basics => 'General',
      _NodeInspectorPanel.behavior => 'Behavior',
      _NodeInspectorPanel.routing => 'Routing',
      _NodeInspectorPanel.data => 'Data',
      _NodeInspectorPanel.checks => 'Checks',
      _NodeInspectorPanel.completion => 'Completion',
    };
  }

  IconData get icon {
    return switch (this) {
      _NodeInspectorPanel.basics => Icons.tune_rounded,
      _NodeInspectorPanel.behavior => Icons.edit_note_rounded,
      _NodeInspectorPanel.routing => Icons.alt_route_rounded,
      _NodeInspectorPanel.data => Icons.input_rounded,
      _NodeInspectorPanel.checks => Icons.fact_check_outlined,
      _NodeInspectorPanel.completion => Icons.task_alt_rounded,
    };
  }
}

class _HarnessWorkflowsWorkspaceState extends State<HarnessWorkflowsWorkspace> {
  final TransformationController _canvasController = TransformationController();
  final Map<String, String?> _fieldErrors = <String, String?>{};

  Map<String, Object?> _catalogExtras = <String, Object?>{};
  List<_WorkflowDraft> _workflows = <_WorkflowDraft>[];
  final _WorkflowCollectionSection _collectionSection =
      _WorkflowCollectionSection.all;
  String _searchQuery = '';
  String? _selectedWorkflowKey;
  String? _selectedNodeKey;
  String _workflowInspectorSectionId =
      _WorkflowInspectorPanel.overview.sectionId;
  String _nodeInspectorSectionId = _NodeInspectorPanel.basics.sectionId;
  bool _showInspector = true;
  bool _showSourceDrawer = false;
  bool _pendingCanvasFit = true;
  Size _lastViewport = Size.zero;
  int _workflowCounter = 0;
  int _nodeCounter = 0;
  int _editorVersion = 0;
  String? _sourceApplyError;
  String? _catalogParseError;

  @override
  void initState() {
    super.initState();
    _loadDraftsFromSource();
  }

  @override
  void didUpdateWidget(covariant HarnessWorkflowsWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog.yaml != widget.catalog.yaml ||
        oldWidget.catalog.configPath != widget.catalog.configPath ||
        oldWidget.catalog.workflows.length != widget.catalog.workflows.length) {
      _loadDraftsFromSource(preserveSelection: true);
      _pendingCanvasFit = true;
    }
  }

  @override
  void dispose() {
    _canvasController.dispose();
    super.dispose();
  }

  void _loadDraftsFromSource({bool preserveSelection = false}) {
    final previousWorkflowName = preserveSelection
        ? _selectedWorkflow?.name
        : null;
    final previousNodeId = preserveSelection ? _selectedNode?.id : null;

    Map<String, Object?> extras = <String, Object?>{};
    List<_WorkflowDraft> drafts = <_WorkflowDraft>[];
    String? parseError;

    try {
      final document = _MiniYamlParser(widget.controller.text).parseDocument();
      if (document is! Map<String, Object?>) {
        throw const _MiniYamlException('Expected a map at the document root.');
      }
      extras = LinkedHashMap<String, Object?>.from(document)
        ..remove('workflows');
      final rawWorkflows =
          (document['workflows'] as List<Object?>? ?? const <Object?>[]);
      drafts = rawWorkflows
          .whereType<Map<String, Object?>>()
          .map(
            (Map<String, Object?> value) => _WorkflowDraft.fromYaml(
              localKey: _nextWorkflowLocalKey(),
              raw: value,
              nextNodeLocalKey: _nextNodeLocalKey,
            ),
          )
          .toList();
    } on _MiniYamlException catch (error) {
      parseError = error.message;
    } catch (error) {
      parseError = error.toString();
    }

    if (drafts.isEmpty) {
      extras = <String, Object?>{};
      drafts = widget.catalog.workflows
          .map(
            (HarnessWorkflowSummary workflow) => _WorkflowDraft.fromSummary(
              localKey: _nextWorkflowLocalKey(),
              summary: workflow,
              nextNodeLocalKey: _nextNodeLocalKey,
            ),
          )
          .toList();
    }

    setState(() {
      _catalogExtras = extras;
      _workflows = drafts;
      _catalogParseError = parseError;
      _sourceApplyError = null;
      _fieldErrors.clear();
      _editorVersion += 1;
      _selectedWorkflowKey = null;
      _selectedNodeKey = null;
      _restoreSelection(
        preferredWorkflowName: previousWorkflowName,
        preferredNodeId: previousNodeId,
      );
    });
    _syncControllerFromDrafts();
  }

  void _restoreSelection({
    String? preferredWorkflowName,
    String? preferredNodeId,
  }) {
    if (_workflows.isEmpty) {
      _selectedWorkflowKey = null;
      _selectedNodeKey = null;
      return;
    }
    final workflow = _workflows.firstWhere(
      (_WorkflowDraft candidate) => candidate.name == preferredWorkflowName,
      orElse: () => _workflows.first,
    );
    _selectedWorkflowKey = workflow.localKey;
    final node = workflow.nodes
        .where((node) => node.id == preferredNodeId)
        .firstOrNull;
    _selectedNodeKey = node?.localKey;
  }

  String _nextWorkflowLocalKey() => 'workflow_${_workflowCounter++}';

  String _nextNodeLocalKey() => 'node_${_nodeCounter++}';

  Map<_WorkflowCollectionSection, List<_WorkflowDraft>>
  get _workflowsBySection {
    return <_WorkflowCollectionSection, List<_WorkflowDraft>>{
      _WorkflowCollectionSection.all: _workflows,
    };
  }

  _WorkflowDraft? get _selectedWorkflow {
    final selectedKey = _selectedWorkflowKey;
    if (selectedKey == null) {
      return _workflows.isEmpty ? null : _workflows.first;
    }
    return _workflows
            .where((workflow) => workflow.localKey == selectedKey)
            .firstOrNull ??
        (_workflows.isEmpty ? null : _workflows.first);
  }

  _WorkflowNodeDraft? get _selectedNode {
    final workflow = _selectedWorkflow;
    final selectedNodeKey = _selectedNodeKey;
    if (workflow == null || selectedNodeKey == null) {
      return null;
    }
    return workflow.nodes
        .where((node) => node.localKey == selectedNodeKey)
        .firstOrNull;
  }

  double get _canvasScale => _canvasController.value.getMaxScaleOnAxis();

  void _selectWorkflow(_WorkflowDraft workflow) {
    setState(() {
      _selectedWorkflowKey = workflow.localKey;
      _selectedNodeKey = null;
      _showInspector = true;
      _pendingCanvasFit = true;
    });
  }

  void _selectNode(String? nodeLocalKey) {
    setState(() {
      _selectedNodeKey = nodeLocalKey;
      if (nodeLocalKey != null) {
        _showInspector = true;
      }
    });
  }

  void _handleInspectorSectionChanged(String sectionId) {
    final normalizedSectionId = sectionId.trim();
    setState(() {
      if (normalizedSectionId.startsWith('workflow-inspector-')) {
        _workflowInspectorSectionId = normalizedSectionId;
        if (_selectedNodeKey != null) {
          _selectedNodeKey = null;
        }
        return;
      }
      if (normalizedSectionId.startsWith('node-inspector-')) {
        _nodeInspectorSectionId = normalizedSectionId;
      }
    });
  }

  String _activeInspectorSectionId(_WorkflowNodeDraft? selectedNode) {
    if (selectedNode == null) {
      return _workflowInspectorSectionId;
    }
    final nodeSections = _nodeInspectorPanelsFor(selectedNode);
    if (nodeSections.any(
      (_NodeInspectorPanel panel) => panel.sectionId == _nodeInspectorSectionId,
    )) {
      return _nodeInspectorSectionId;
    }
    return nodeSections.first.sectionId;
  }

  List<_NodeInspectorPanel> _nodeInspectorPanelsFor(_WorkflowNodeDraft node) {
    final isFinish = node.kind == 'finish';
    final isGate = _normalizeWorkflowKind(node.kind) == 'check';
    return <_NodeInspectorPanel>[
      _NodeInspectorPanel.basics,
      _NodeInspectorPanel.behavior,
      if (!isFinish) _NodeInspectorPanel.routing,
      if (!isFinish) _NodeInspectorPanel.data,
      if (isGate) _NodeInspectorPanel.checks,
      if (!isFinish) _NodeInspectorPanel.completion,
    ];
  }

  void _handleViewportMeasured(Size viewport, _WorkflowGraphLayout layout) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      return;
    }
    if (_lastViewport == viewport && !_pendingCanvasFit) {
      return;
    }
    _lastViewport = viewport;
    if (_pendingCanvasFit) {
      _pendingCanvasFit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _fitCanvasToBounds(viewport, layout.contentBounds);
      });
    }
  }

  void _fitCanvasToBounds(Size viewport, Rect bounds) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      return;
    }
    final targetBounds = bounds.inflate(180);
    final scaleX = viewport.width / targetBounds.width;
    final scaleY = viewport.height / targetBounds.height;
    final scale = math.min(scaleX, scaleY).clamp(0.28, 1.15);
    final viewportCenter = Offset(viewport.width / 2, viewport.height / 2);
    final sceneCenter = targetBounds.center;
    _canvasController.value = _viewMatrix(
      viewportCenter: viewportCenter,
      sceneCenter: sceneCenter,
      scale: scale,
    );
  }

  void _zoomCanvas(double factor) {
    final viewport = _lastViewport;
    if (viewport.width <= 0 || viewport.height <= 0) {
      return;
    }
    final currentScale = _canvasScale;
    final nextScale = (currentScale * factor).clamp(0.18, 2.4);
    final viewportCenter = Offset(viewport.width / 2, viewport.height / 2);
    final inverse = Matrix4.inverted(_canvasController.value);
    final sceneCenter = MatrixUtils.transformPoint(inverse, viewportCenter);
    _canvasController.value = _viewMatrix(
      viewportCenter: viewportCenter,
      sceneCenter: sceneCenter,
      scale: nextScale,
    );
  }

  Matrix4 _viewMatrix({
    required Offset viewportCenter,
    required Offset sceneCenter,
    required double scale,
  }) {
    final matrix = Matrix4.diagonal3Values(scale, scale, 1);
    matrix.setTranslationRaw(
      viewportCenter.dx - (sceneCenter.dx * scale),
      viewportCenter.dy - (sceneCenter.dy * scale),
      0,
    );
    return matrix;
  }

  void _resetCanvas(_WorkflowGraphLayout layout) {
    _fitCanvasToBounds(_lastViewport, layout.contentBounds);
  }

  void _syncControllerFromDrafts() {
    final root = <String, Object?>{}
      ..addAll(_catalogExtras)
      ..['workflows'] = _workflows
          .map((_WorkflowDraft workflow) => workflow.toYamlMap())
          .toList();
    final yaml = _MiniYamlWriter.serialize(root);
    if (widget.controller.text == yaml) {
      return;
    }
    widget.controller.value = TextEditingValue(
      text: yaml,
      selection: TextSelection.collapsed(offset: yaml.length),
    );
  }

  void _updateWorkflow(void Function(_WorkflowDraft workflow) mutate) {
    final workflow = _selectedWorkflow;
    if (workflow == null) {
      return;
    }
    setState(() {
      mutate(workflow);
      _sourceApplyError = null;
      _syncControllerFromDrafts();
    });
  }

  void _updateNode(
    void Function(_WorkflowDraft workflow, _WorkflowNodeDraft node) mutate,
  ) {
    final workflow = _selectedWorkflow;
    final node = _selectedNode;
    if (workflow == null || node == null) {
      return;
    }
    setState(() {
      mutate(workflow, node);
      _sourceApplyError = null;
      _syncControllerFromDrafts();
    });
  }

  void _renameNode(
    _WorkflowDraft workflow,
    _WorkflowNodeDraft node,
    String nextId,
  ) {
    final normalized = _slugify(nextId);
    if (normalized.isEmpty || normalized == node.id) {
      return;
    }
    final collision = workflow.nodes.any(
      (_WorkflowNodeDraft candidate) =>
          candidate.localKey != node.localKey && candidate.id == normalized,
    );
    if (collision) {
      _fieldErrors[_fieldKey(node.localKey, 'id')] = 'Node ids must be unique.';
      return;
    }
    _fieldErrors[_fieldKey(node.localKey, 'id')] = null;
    final previous = node.id;
    node.id = normalized;
    if (workflow.startNode == previous) {
      workflow.startNode = normalized;
    }
    for (final candidate in workflow.nodes) {
      if (candidate.transitions.success == previous) {
        candidate.transitions.success = normalized;
      }
      if (candidate.transitions.failure == previous) {
        candidate.transitions.failure = normalized;
      }
      if (candidate.transitions.blocked == previous) {
        candidate.transitions.blocked = normalized;
      }
      candidate.requiresGates = candidate.requiresGates
          .map((String value) => value == previous ? normalized : value)
          .toList();
      candidate.includeNodeResults = candidate.includeNodeResults
          .map((String value) => value == previous ? normalized : value)
          .toList();
      candidate.inputMappings = candidate.inputMappings
          .map(
            (_WorkflowInputMappingDraft mapping) => mapping.fromNode == previous
                ? mapping.copyWith(fromNode: normalized)
                : mapping,
          )
          .toList();
      candidate.policyGateFactBindings = candidate.policyGateFactBindings
          .map(
            (_PolicyFactBindingDraft binding) => binding.node == previous
                ? binding.copyWith(node: normalized)
                : binding,
          )
          .toList();
      candidate.allowedRouteHints.updateAll(
        (String hint, String target) =>
            target == previous ? normalized : target,
      );
    }
  }

  void _addNode() {
    final workflow = _selectedWorkflow;
    if (workflow == null) {
      return;
    }
    final id = _nextNodeIdFor(workflow);
    final node = _WorkflowNodeDraft(
      localKey: _nextNodeLocalKey(),
      id: id,
      kind: 'task',
      uses: '',
    );
    setState(() {
      workflow.nodes.add(node);
      if (workflow.startNode.isEmpty) {
        workflow.startNode = node.id;
      }
      _selectedNodeKey = node.localKey;
      _showInspector = true;
      _pendingCanvasFit = true;
      _sourceApplyError = null;
      _syncControllerFromDrafts();
    });
  }

  void _deleteSelectedNode() {
    final workflow = _selectedWorkflow;
    final node = _selectedNode;
    if (workflow == null || node == null) {
      return;
    }
    setState(() {
      workflow.nodes.removeWhere(
        (_WorkflowNodeDraft candidate) => candidate.localKey == node.localKey,
      );
      for (final candidate in workflow.nodes) {
        if (candidate.transitions.success == node.id) {
          candidate.transitions.success = '';
        }
        if (candidate.transitions.failure == node.id) {
          candidate.transitions.failure = '';
        }
        if (candidate.transitions.blocked == node.id) {
          candidate.transitions.blocked = '';
        }
        candidate.requiresGates.removeWhere((String value) => value == node.id);
        candidate.includeNodeResults.removeWhere(
          (String value) => value == node.id,
        );
        candidate.inputMappings.removeWhere(
          (_WorkflowInputMappingDraft mapping) => mapping.fromNode == node.id,
        );
        candidate.policyGateFactBindings.removeWhere(
          (_PolicyFactBindingDraft binding) => binding.node == node.id,
        );
        candidate.allowedRouteHints.removeWhere(
          (String hint, String target) => target == node.id,
        );
      }
      if (workflow.startNode == node.id) {
        workflow.startNode = workflow.nodes.isEmpty
            ? ''
            : workflow.nodes.first.id;
      }
      _selectedNodeKey = null;
      _sourceApplyError = null;
      _syncControllerFromDrafts();
    });
  }

  void _applySource() {
    try {
      final document = _MiniYamlParser(widget.controller.text).parseDocument();
      if (document is! Map<String, Object?>) {
        throw const _MiniYamlException('Expected a map at the document root.');
      }
      final previousWorkflowName = _selectedWorkflow?.name;
      final previousNodeId = _selectedNode?.id;
      final extras = LinkedHashMap<String, Object?>.from(document)
        ..remove('workflows');
      final rawWorkflows =
          (document['workflows'] as List<Object?>? ?? const <Object?>[])
              .whereType<Map<String, Object?>>()
              .toList();
      if (rawWorkflows.isEmpty) {
        throw const _MiniYamlException(
          'No workflows were found under `workflows:`.',
        );
      }
      setState(() {
        _catalogExtras = extras;
        _workflows = rawWorkflows
            .map(
              (Map<String, Object?> value) => _WorkflowDraft.fromYaml(
                localKey: _nextWorkflowLocalKey(),
                raw: value,
                nextNodeLocalKey: _nextNodeLocalKey,
              ),
            )
            .toList();
        _sourceApplyError = null;
        _catalogParseError = null;
        _fieldErrors.clear();
        _editorVersion += 1;
        _restoreSelection(
          preferredWorkflowName: previousWorkflowName,
          preferredNodeId: previousNodeId,
        );
      });
      _syncControllerFromDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workflow source applied to the canvas.'),
          ),
        );
      }
    } on _MiniYamlException catch (error) {
      setState(() => _sourceApplyError = error.message);
    } catch (error) {
      setState(() => _sourceApplyError = error.toString());
    }
  }

  String _fieldKey(String ownerKey, String field) =>
      '$ownerKey|$field|$_editorVersion';

  void _updateFieldError(String fieldKey, String? error) {
    setState(() {
      _fieldErrors[fieldKey] = error;
    });
  }

  String? _fieldError(String fieldKey) => _fieldErrors[fieldKey];

  List<_WorkflowRuleSetDraft> _sharedRuleSetDrafts() {
    return ((_catalogExtras['rule_sets'] as List<Object?>?) ??
            const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(_WorkflowRuleSetDraft.fromYaml)
        .toList(growable: false);
  }

  List<_WorkflowRuleDraft> _sharedRuleDrafts() {
    return ((_catalogExtras['rules'] as List<Object?>?) ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(_WorkflowRuleDraft.fromYaml)
        .toList(growable: false);
  }

  List<String> _sharedRuleSetOptions({String currentValue = ''}) {
    final options = LinkedHashSet<String>.from(
      _sharedRuleSetDrafts()
          .map((_WorkflowRuleSetDraft value) => value.name)
          .where((String value) => value.trim().isNotEmpty),
    );
    if (currentValue.trim().isNotEmpty) {
      options.add(currentValue.trim());
    }
    return options.toList(growable: false);
  }

  List<String> _referencedSharedRuleSets(_WorkflowDraft workflow) {
    final names = LinkedHashSet<String>.from(
      workflow.nodes
          .map((_WorkflowNodeDraft node) => node.policyGateRuleSet.trim())
          .where((String value) => value.isNotEmpty),
    );
    return names.toList(growable: false);
  }

  String _nextFactBindingNameFor(_WorkflowNodeDraft node) {
    final existing = node.policyGateFactBindings
        .map((_PolicyFactBindingDraft value) => value.name)
        .where((String value) => value.trim().isNotEmpty)
        .toSet();
    for (int index = 1; ; index++) {
      final candidate = 'fact_$index';
      if (!existing.contains(candidate)) {
        return candidate;
      }
    }
  }

  String _nextRouteHintNameFor(_WorkflowNodeDraft node) {
    final existing = node.allowedRouteHints.keys
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    for (int index = 1; ; index++) {
      final candidate = 'route_$index';
      if (!existing.contains(candidate)) {
        return candidate;
      }
    }
  }

  void _addPolicyFactBinding() {
    final node = _selectedNode;
    if (node == null) {
      return;
    }
    _updateNode((_WorkflowDraft _, _WorkflowNodeDraft targetNode) {
      targetNode.policyGateFactBindings = <_PolicyFactBindingDraft>[
        ...targetNode.policyGateFactBindings,
        _PolicyFactBindingDraft(
          name: _nextFactBindingNameFor(node),
          source: 'input',
          node: '',
          path: '',
          required: false,
        ),
      ];
    });
  }

  void _updatePolicyFactBinding(int index, _PolicyFactBindingDraft binding) {
    _updateNode((_WorkflowDraft _, _WorkflowNodeDraft targetNode) {
      if (index < 0 || index >= targetNode.policyGateFactBindings.length) {
        return;
      }
      final next = targetNode.policyGateFactBindings.toList(growable: true);
      next[index] = binding;
      targetNode.policyGateFactBindings = next;
    });
  }

  void _deletePolicyFactBinding(int index) {
    _updateNode((_WorkflowDraft _, _WorkflowNodeDraft targetNode) {
      if (index < 0 || index >= targetNode.policyGateFactBindings.length) {
        return;
      }
      final next = targetNode.policyGateFactBindings.toList(growable: true)
        ..removeAt(index);
      targetNode.policyGateFactBindings = next;
    });
  }

  void _addAllowedRouteHint() {
    final workflow = _selectedWorkflow;
    final node = _selectedNode;
    if (workflow == null || node == null) {
      return;
    }
    final targetOptions = _transitionOptionsFor(
      _nodeOptions(workflow),
      node.id,
      '',
    );
    _updateNode((_WorkflowDraft _, _WorkflowNodeDraft targetNode) {
      targetNode.allowedRouteHints = LinkedHashMap<String, String>.from(
        targetNode.allowedRouteHints,
      )..[_nextRouteHintNameFor(node)] = targetOptions.firstOrNull ?? '';
    });
  }

  void _updateAllowedRouteHint(int index, {String? hint, String? target}) {
    _updateNode((_WorkflowDraft _, _WorkflowNodeDraft targetNode) {
      final entries = targetNode.allowedRouteHints.entries.toList(
        growable: true,
      );
      if (index < 0 || index >= entries.length) {
        return;
      }
      final current = entries[index];
      entries[index] = MapEntry(hint ?? current.key, target ?? current.value);
      targetNode.allowedRouteHints = LinkedHashMap<String, String>.fromEntries(
        entries,
      );
    });
  }

  void _deleteAllowedRouteHint(int index) {
    _updateNode((_WorkflowDraft _, _WorkflowNodeDraft targetNode) {
      final entries = targetNode.allowedRouteHints.entries.toList(
        growable: true,
      );
      if (index < 0 || index >= entries.length) {
        return;
      }
      entries.removeAt(index);
      targetNode.allowedRouteHints = LinkedHashMap<String, String>.fromEntries(
        entries,
      );
    });
  }

  List<String> _nodeOptions(_WorkflowDraft workflow) =>
      workflow.nodes.map((_WorkflowNodeDraft node) => node.id).toList();

  @override
  Widget build(BuildContext context) {
    final selectedWorkflow = _selectedWorkflow;
    if (selectedWorkflow == null) {
      return const EmptyState(
        title: 'No workflows',
        body:
            'Workflow definitions will appear here after the harness workflow config loads them.',
      );
    }

    final layout = _WorkflowGraphLayout.fromWorkflow(selectedWorkflow);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final stacked = constraints.maxWidth < 1180;
        final collectionPane = _WorkflowCollectionPane(
          workflowsBySection: _workflowsBySection,
          initialSectionId: _collectionSection.sectionId,
          searchQuery: _searchQuery,
          selectedWorkflowKey: _selectedWorkflowKey,
          onSearchChanged: (String value) {
            setState(() => _searchQuery = value);
          },
          onSelectWorkflow: _selectWorkflow,
        );

        final canvasPane = _WorkflowCanvasPane(
          workflow: selectedWorkflow,
          layout: layout,
          selectedNodeKey: _selectedNodeKey,
          controller: _canvasController,
          scaleLabel: '${(_canvasScale * 100).round()}%',
          onSelectNode: _selectNode,
          onClearNodeSelection: () => _selectNode(null),
          onViewportMeasured: _handleViewportMeasured,
          onToggleSource: () {
            setState(() => _showSourceDrawer = !_showSourceDrawer);
          },
          onToggleInspector: () {
            setState(() => _showInspector = !_showInspector);
          },
          onZoomIn: () => _zoomCanvas(1.18),
          onZoomOut: () => _zoomCanvas(1 / 1.18),
          onFitCanvas: () => _resetCanvas(layout),
          sourceDrawerOpen: _showSourceDrawer,
          inspectorVisible: _showInspector,
          viewportSize: _lastViewport,
        );

        final inspectorPane = _buildInspectorPane(selectedWorkflow);

        return Column(
          children: [
            Expanded(
              child: ConfigWorkspaceThreePaneShell(
                stacked: stacked,
                collectionPane: collectionPane,
                editorPane: canvasPane,
                detailPane: inspectorPane,
                showDetailPane: _showInspector,
                collectionFlex: 28,
                editorFlex: 46,
                detailFlex: 26,
                stackedCollectionFlex: 30,
                stackedEditorFlex: 40,
                stackedDetailFlex: 30,
              ),
            ),
            const SizedBox(height: 16),
            _WorkflowSourceDrawer(
              open: _showSourceDrawer,
              controller: widget.controller,
              validation: widget.validation,
              parseError: _sourceApplyError ?? _catalogParseError,
              onApplySource: _applySource,
              onClose: () {
                setState(() => _showSourceDrawer = false);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInspectorPane(_WorkflowDraft workflow) {
    final selectedNode = _selectedNode;
    return AppSidePanel(
      side: AppSidePanelSide.right,
      initialSectionId: _activeInspectorSectionId(selectedNode),
      searchHintText: selectedNode == null
          ? 'Filter workflow settings...'
          : 'Filter step settings...',
      onSectionChanged: _handleInspectorSectionChanged,
      headerPadding: const EdgeInsets.fromLTRB(18, 18, 14, 0),
      controlsPadding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      bodyPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      sections: selectedNode == null
          ? _buildWorkflowInspectorSections(workflow)
          : _buildNodeInspectorSections(workflow, selectedNode),
    );
  }

  List<AppSidePanelSection> _buildWorkflowInspectorSections(
    _WorkflowDraft workflow,
  ) {
    return _WorkflowInspectorPanel.values
        .map((_WorkflowInspectorPanel panel) {
          return AppSidePanelSection(
            id: panel.sectionId,
            label: panel.label,
            icon: panel.icon,
            quickActionsBuilder: (BuildContext context, String searchQuery) {
              return FilledButton.icon(
                onPressed: _addNode,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Add step'),
              );
            },
            builder: (BuildContext context, String searchQuery) {
              return _buildWorkflowInspectorSectionContent(
                workflow,
                panel,
                searchQuery,
              );
            },
          );
        })
        .toList(growable: false);
  }

  List<AppSidePanelSection> _buildNodeInspectorSections(
    _WorkflowDraft workflow,
    _WorkflowNodeDraft node,
  ) {
    final panels = _nodeInspectorPanelsFor(node);

    return panels
        .map((_NodeInspectorPanel panel) {
          return AppSidePanelSection(
            id: panel.sectionId,
            label: panel.label,
            icon: panel.icon,
            quickActionsBuilder: (BuildContext context, String searchQuery) {
              return FilledButton.tonalIcon(
                onPressed: _deleteSelectedNode,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove step'),
              );
            },
            builder: (BuildContext context, String searchQuery) {
              return _buildNodeInspectorSectionContent(
                workflow,
                node,
                panel,
                searchQuery,
              );
            },
          );
        })
        .toList(growable: false);
  }

  Widget _buildWorkflowInspectorSectionContent(
    _WorkflowDraft workflow,
    _WorkflowInspectorPanel panel,
    String searchQuery,
  ) {
    final workflowKey = workflow.localKey;
    final nodeIds = _nodeOptions(workflow);

    switch (panel) {
      case _WorkflowInspectorPanel.overview:
        return _buildInspectorPanelContent(
          summaryCard: _buildWorkflowInspectorSummaryCard(workflow),
          searchQuery: searchQuery,
          emptyTitle: 'No matching workflow basics',
          emptyBody:
              'Try a different search term to find workflow naming and entry controls.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Workflow setup',
              searchTerms: const <String>[
                'workflow name',
                'start node',
                'entry point',
                'steps',
              ],
              child: _InspectorSection(
                title: 'Workflow',
                child: Column(
                  children: [
                    _InspectorTextField(
                      key: ValueKey(_fieldKey(workflowKey, 'workflow_name')),
                      label: 'Workflow name',
                      initialValue: workflow.name,
                      onChanged: (String value) {
                        _updateWorkflow((_WorkflowDraft target) {
                          target.name = _slugify(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorDropdownField(
                      key: ValueKey(_fieldKey(workflowKey, 'start_node')),
                      label: 'Start step',
                      value: workflow.startNode.isEmpty
                          ? null
                          : workflow.startNode,
                      includeBlank: true,
                      blankLabel: 'No start step',
                      options: nodeIds,
                      onChanged: (String? value) {
                        _updateWorkflow((_WorkflowDraft target) {
                          target.startNode = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorInlineFacts(
                      entries: <MapEntry<String, String>>[
                        MapEntry('Steps', '${workflow.nodes.length}'),
                        MapEntry(
                          'Checks',
                          '${workflow.nodes.where((node) => _normalizeWorkflowKind(node.kind) == 'check').length}',
                        ),
                        MapEntry(
                          'Finish',
                          '${workflow.nodes.where((node) => node.kind == 'finish').length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case _WorkflowInspectorPanel.limits:
        return _buildInspectorPanelContent(
          summaryCard: _buildWorkflowInspectorSummaryCard(workflow),
          searchQuery: searchQuery,
          emptyTitle: 'No matching workflow limits',
          emptyBody:
              'Try a different search term to find retry and transition limits.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Workflow limits',
              searchTerms: const <String>[
                'max visits per step',
                'max transitions',
                'duplicate result cap',
              ],
              child: _InspectorSection(
                title: 'Limits',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InspectorNumberField(
                            key: ValueKey(
                              _fieldKey(workflowKey, 'max_visits_per_node'),
                            ),
                            label: 'Max visits / step',
                            initialValue: _intText(workflow.maxVisitsPerNode),
                            onChanged: (int value) {
                              _updateWorkflow((_WorkflowDraft target) {
                                target.maxVisitsPerNode = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InspectorNumberField(
                            key: ValueKey(
                              _fieldKey(workflowKey, 'max_total_transitions'),
                            ),
                            label: 'Max transitions',
                            initialValue: _intText(
                              workflow.maxTotalTransitions,
                            ),
                            onChanged: (int value) {
                              _updateWorkflow((_WorkflowDraft target) {
                                target.maxTotalTransitions = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InspectorNumberField(
                      key: ValueKey(
                        _fieldKey(workflowKey, 'duplicate_result_cap'),
                      ),
                      label: 'Duplicate result cap',
                      initialValue: _intText(workflow.duplicateResultCap),
                      onChanged: (int value) {
                        _updateWorkflow((_WorkflowDraft target) {
                          target.duplicateResultCap = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case _WorkflowInspectorPanel.rules:
        final sharedRules = _sharedRuleDrafts();
        final sharedRuleSets = _sharedRuleSetDrafts();
        final referencedRuleSets = _referencedSharedRuleSets(workflow);
        return _buildInspectorPanelContent(
          summaryCard: _buildWorkflowInspectorSummaryCard(workflow),
          searchQuery: searchQuery,
          emptyTitle: 'No matching workflow policy',
          emptyBody:
              'Try a different search term to find shared rule references or policy guidance.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Shared rules',
              searchTerms: const <String>[
                'shared rules',
                'rules',
                'policy',
                'fact bindings',
                'route hints',
              ],
              child: _InspectorSection(
                title: 'Shared rules',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InfoPanel(
                      title: 'How grules fit',
                      body:
                          'Shared GRL rules are authored once from Harness > Rules. Rule Sets compose those rules and define the default evaluation behavior. Workflow gates then reference a Rule Set and provide the workflow-specific fact bindings, route hints, and any per-gate overrides.',
                    ),
                    if (sharedRules.isEmpty && sharedRuleSets.isEmpty) ...[
                      const SizedBox(height: 12),
                      const InfoPanel(
                        title: 'No shared policy items yet',
                        body:
                            'Create shared rules and rule sets from the dedicated Rules screen, then reference a rule set from any workflow gate that needs deterministic policy evaluation.',
                      ),
                    ],
                    if (sharedRules.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _InspectorListCard(
                        title: 'Available rules',
                        subtitle:
                            'These are the atomic GRL files that rule sets can compose.',
                        tone: infoColor,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sharedRules
                            .map(
                              (_WorkflowRuleDraft value) => StatusPill(
                                label: value.name,
                                color: infoColor,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (sharedRuleSets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _InspectorListCard(
                        title: 'Available rule sets',
                        subtitle:
                            'These are the executable Rule Sets that workflow gates can reference.',
                        tone: successColor,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sharedRuleSets
                            .map(
                              (_WorkflowRuleSetDraft value) => StatusPill(
                                label: value.name,
                                color: successColor,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (referencedRuleSets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _InspectorListCard(
                        title: 'This workflow references',
                        subtitle:
                            'These rule sets are currently selected by gate steps in this workflow.',
                        tone: successColor,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: referencedRuleSets
                            .map(
                              (String value) =>
                                  StatusPill(label: value, color: infoColor),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (referencedRuleSets.isEmpty &&
                        sharedRuleSets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const InfoPanel(
                        title: 'No rule sets attached yet',
                        body:
                            'Select a shared rule set from any check step in this workflow when you want deterministic policy evaluation.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      case _WorkflowInspectorPanel.source:
        return _buildInspectorPanelContent(
          summaryCard: _buildWorkflowInspectorSummaryCard(workflow),
          searchQuery: searchQuery,
          emptyTitle: 'No matching source tools',
          emptyBody:
              'Try a different search term to find YAML and validation controls.',
          blocks: <_InspectorPanelBlock>[
            if (widget.validation != null)
              _InspectorPanelBlock(
                title: 'Validation',
                searchTerms: const <String>['validation', 'catalog', 'issues'],
                child: _WorkflowValidationSummaryCard(
                  report: widget.validation!,
                ),
              ),
            _InspectorPanelBlock(
              title: 'Source',
              searchTerms: const <String>[
                'yaml',
                'source',
                'config path',
                'editor',
              ],
              child: _InspectorActionCard(
                title: 'Workflow source',
                body:
                    'Open the YAML drawer when you need to adjust fields that are easier to edit directly in source.',
                actionLabel: 'Open source',
                icon: Icons.code_rounded,
                onTap: () {
                  setState(() => _showSourceDrawer = true);
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _buildNodeInspectorSectionContent(
    _WorkflowDraft workflow,
    _WorkflowNodeDraft node,
    _NodeInspectorPanel panel,
    String searchQuery,
  ) {
    final nodeKey = node.localKey;
    final isFinish = node.kind == 'finish';
    final isGate = _normalizeWorkflowKind(node.kind) == 'check';
    final nodeOptions = _nodeOptions(workflow);
    final successOptions = _transitionOptionsFor(
      nodeOptions,
      node.id,
      node.transitions.success,
    );
    final failureOptions = _transitionOptionsFor(
      nodeOptions,
      node.id,
      node.transitions.failure,
    );
    final blockedOptions = _transitionOptionsFor(
      nodeOptions,
      node.id,
      node.transitions.blocked,
    );
    final hasSelfLoop =
        node.transitions.success == node.id ||
        node.transitions.failure == node.id ||
        node.transitions.blocked == node.id;
    final hasStructuredInputs = node.withValues.values.any(
      (Object? value) =>
          value is Map<String, Object?> || value is List<Object?>,
    );
    final runTargetOptions = <String>{
      ...widget.runTargetOptions,
      if (node.uses.trim().isNotEmpty) node.uses.trim(),
    }.toList(growable: false);
    final kindOptions = <String>{
      'task',
      'check',
      'finish',
      if (node.kind.trim().isNotEmpty) node.kind,
    }.toList();

    switch (panel) {
      case _NodeInspectorPanel.basics:
        return _buildInspectorPanelContent(
          summaryCard: _buildNodeInspectorSummaryCard(workflow, node),
          searchQuery: searchQuery,
          emptyTitle: 'No matching step basics',
          emptyBody:
              'Try a different search term to find step identity and authoring controls.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Step setup',
              searchTerms: const <String>[
                'step id',
                'step type',
                'runs',
                'start step',
              ],
              child: _InspectorSection(
                title: 'Step',
                child: Column(
                  children: [
                    _InspectorTextField(
                      key: ValueKey(_fieldKey(nodeKey, 'id')),
                      label: 'Step id',
                      initialValue: node.id,
                      errorText: _fieldError(_fieldKey(nodeKey, 'id')),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft targetWorkflow,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          _renameNode(targetWorkflow, targetNode, value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorDropdownField(
                      key: ValueKey(_fieldKey(nodeKey, 'kind')),
                      label: 'Step type',
                      value: node.kind.isEmpty ? null : node.kind,
                      options: kindOptions,
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.kind = (value ?? '').trim();
                        });
                      },
                    ),
                    if (!isFinish) ...[
                      const SizedBox(height: 12),
                      _InspectorDropdownField(
                        key: ValueKey(_fieldKey(nodeKey, 'uses')),
                        label: 'Runs',
                        value: node.uses.isEmpty ? null : node.uses,
                        options: runTargetOptions,
                        includeBlank: true,
                        blankLabel: 'No run target',
                        helperText:
                            'Configured agents and tools. Existing custom values stay available here too.',
                        onChanged: (String? value) {
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.uses = (value ?? '').trim();
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    _InspectorToggleTile(
                      title: 'Start step',
                      value: workflow.startNode == node.id,
                      subtitle: 'Use this step as the workflow entry point.',
                      onChanged: (bool value) {
                        _updateWorkflow((_WorkflowDraft target) {
                          target.startNode = value ? node.id : '';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case _NodeInspectorPanel.behavior:
        return _buildInspectorPanelContent(
          summaryCard: _buildNodeInspectorSummaryCard(workflow, node),
          searchQuery: searchQuery,
          emptyTitle: isFinish
              ? 'No matching finish behavior'
              : 'No matching step behavior',
          emptyBody: isFinish
              ? 'Try a different search term to find finish result controls.'
              : 'Try a different search term to find optional prompt behavior.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: isFinish ? 'Finish result' : 'Optional prompt behavior',
              searchTerms: isFinish
                  ? const <String>['finish', 'result', 'summary']
                  : const <String>[
                      'instructions',
                      'prompt',
                      'what should this step do',
                      'optional',
                      'agent only',
                      'tool step',
                    ],
              child: isFinish
                  ? _InspectorSection(
                      title: 'Finish',
                      child: _InspectorMultilineField(
                        key: ValueKey(_fieldKey(nodeKey, 'finish_summary')),
                        label: 'Summary',
                        hintText:
                            'Optional final summary for the workflow result',
                        initialValue: _withTextValue(node, 'summary'),
                        onChanged: (String value) {
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            _setWithTextValue(targetNode, 'summary', value);
                          });
                        },
                      ),
                    )
                  : _InspectorSection(
                      title: 'Prompt overlay',
                      child: _InspectorMultilineField(
                        key: ValueKey(_fieldKey(nodeKey, 'prompt')),
                        label: 'Optional instructions',
                        hintText:
                            'One instruction per line for agent-driven steps',
                        helperText:
                            'Leave this empty for tool-only steps. These instructions only apply when the step run is prompt-driven.',
                        initialValue: node.promptInstructions.join('\n'),
                        onChanged: (String value) {
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.promptInstructions = _splitLines(value);
                          });
                        },
                      ),
                    ),
            ),
          ],
        );
      case _NodeInspectorPanel.routing:
        return _buildInspectorPanelContent(
          summaryCard: _buildNodeInspectorSummaryCard(workflow, node),
          searchQuery: searchQuery,
          emptyTitle: 'No matching routing controls',
          emptyBody: 'Try a different search term to find transition settings.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Next steps',
              searchTerms: const <String>[
                'success',
                'failure',
                'blocked',
                'transitions',
                'routing',
              ],
              child: _InspectorSection(
                title: 'Next',
                child: Column(
                  children: [
                    _InspectorDropdownField(
                      key: ValueKey(_fieldKey(nodeKey, 'success')),
                      label: 'On success',
                      includeBlank: true,
                      blankLabel: 'No transition',
                      value: node.transitions.success.isEmpty
                          ? null
                          : node.transitions.success,
                      options: successOptions,
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.transitions.success = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorDropdownField(
                      key: ValueKey(_fieldKey(nodeKey, 'failure')),
                      label: 'On failure',
                      includeBlank: true,
                      blankLabel: 'No transition',
                      value: node.transitions.failure.isEmpty
                          ? null
                          : node.transitions.failure,
                      options: failureOptions,
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.transitions.failure = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorDropdownField(
                      key: ValueKey(_fieldKey(nodeKey, 'blocked')),
                      label: 'On blocked',
                      includeBlank: true,
                      blankLabel: 'No transition',
                      value: node.transitions.blocked.isEmpty
                          ? null
                          : node.transitions.blocked,
                      options: blockedOptions,
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.transitions.blocked = value ?? '';
                        });
                      },
                    ),
                    if (hasSelfLoop) ...[
                      const SizedBox(height: 12),
                      const InfoPanel(
                        title: 'Self-loop detected',
                        body:
                            'Existing capped retry loops stay visible here, but this editor avoids offering the current step as a new transition target by default.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      case _NodeInspectorPanel.data:
        return _buildInspectorPanelContent(
          summaryCard: _buildNodeInspectorSummaryCard(workflow, node),
          searchQuery: searchQuery,
          emptyTitle: 'No matching data controls',
          emptyBody:
              'Try a different search term to find payload, contract, or mapping settings.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Step inputs',
              searchTerms: const <String>['inputs', 'payload', 'with values'],
              child: _InspectorSection(
                title: 'Inputs',
                child: _InspectorYamlEditor(
                  key: ValueKey(_fieldKey(nodeKey, 'with')),
                  label: 'Inputs',
                  helperText: hasStructuredInputs
                      ? 'This step has structured inputs. Editing here preserves the full shape.'
                      : 'The stable payload this step always receives.',
                  initialValue: _MiniYamlWriter.serialize(node.withValues),
                  errorText: _fieldError(_fieldKey(nodeKey, 'with')),
                  onChanged: (String value) {
                    try {
                      final parsed = _parseYamlMapFragment(value);
                      _updateFieldError(_fieldKey(nodeKey, 'with'), null);
                      _updateNode((
                        _WorkflowDraft _,
                        _WorkflowNodeDraft targetNode,
                      ) {
                        targetNode.withValues = parsed;
                      });
                    } on _MiniYamlException catch (error) {
                      _updateFieldError(
                        _fieldKey(nodeKey, 'with'),
                        error.message,
                      );
                    }
                  },
                ),
              ),
            ),
            _InspectorPanelBlock(
              title: 'Contracts and mappings',
              searchTerms: const <String>[
                'required inputs',
                'optional inputs',
                'required outputs',
                'input mappings',
                'include node results',
                'check decision output',
              ],
              child: _InspectorSection(
                title: 'Data flow',
                child: Column(
                  children: [
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'required_input_keys')),
                      label: 'Required inputs',
                      hintText: 'One input key per line',
                      initialValue: node.requiredInputKeys.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.requiredInputKeys = _splitLines(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'optional_input_keys')),
                      label: 'Optional inputs',
                      hintText: 'One input key per line',
                      initialValue: node.optionalInputKeys.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.optionalInputKeys = _splitLines(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'required_data_keys')),
                      label: 'Required outputs',
                      hintText: 'One output key per line',
                      initialValue: node.requiredDataKeys.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.requiredDataKeys = _splitLines(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'include_node_results')),
                      label: 'Use output from steps',
                      hintText: 'One source step id per line',
                      initialValue: node.includeNodeResults.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.includeNodeResults = _splitLines(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorYamlEditor(
                      key: ValueKey(_fieldKey(nodeKey, 'input_mappings')),
                      label: 'Mapped inputs',
                      helperText:
                          'Map selected values from earlier step outputs into this step.',
                      initialValue: _MiniYamlWriter.serialize(
                        node.inputMappings
                            .map(
                              (_WorkflowInputMappingDraft mapping) =>
                                  mapping.toYamlMap(),
                            )
                            .toList(),
                      ),
                      errorText: _fieldError(
                        _fieldKey(nodeKey, 'input_mappings'),
                      ),
                      onChanged: (String value) {
                        try {
                          final parsed = _parseYamlListFragment(value);
                          final mappings = parsed
                              .whereType<Map<String, Object?>>()
                              .map(_WorkflowInputMappingDraft.fromYaml)
                              .toList();
                          _updateFieldError(
                            _fieldKey(nodeKey, 'input_mappings'),
                            null,
                          );
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.inputMappings = mappings;
                          });
                        } on _MiniYamlException catch (error) {
                          _updateFieldError(
                            _fieldKey(nodeKey, 'input_mappings'),
                            error.message,
                          );
                        }
                      },
                    ),
                    if (isGate || node.producesGateDecision) ...[
                      const SizedBox(height: 12),
                      _InspectorToggleTile(
                        title: 'Require check decision output',
                        value: node.producesGateDecision,
                        subtitle:
                            'Use this only when this step must emit check decision data in its output contract.',
                        onChanged: (bool value) {
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.producesGateDecision = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      case _NodeInspectorPanel.checks:
        final ruleSetOptions = _sharedRuleSetOptions(
          currentValue: node.policyGateRuleSet,
        );
        return _buildInspectorPanelContent(
          summaryCard: _buildNodeInspectorSummaryCard(workflow, node),
          searchQuery: searchQuery,
          emptyTitle: 'No matching check controls',
          emptyBody:
              'Try a different search term to find check matching or deterministic rule settings.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Check result matching',
              searchTerms: const <String>[
                'pass statuses',
                'fail statuses',
                'pass exit codes',
                'fail exit codes',
                'retryable',
              ],
              child: _InspectorSection(
                title: 'Check result matching',
                child: Column(
                  children: [
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'gate_pass_statuses')),
                      label: 'Pass statuses',
                      hintText: 'One status per line',
                      initialValue: node.gatePassStatuses.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.gatePassStatuses = _splitLines(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'gate_fail_statuses')),
                      label: 'Fail statuses',
                      hintText: 'One status per line',
                      initialValue: node.gateFailStatuses.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.gateFailStatuses = _splitLines(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'gate_pass_exit_codes')),
                      label: 'Pass exit codes',
                      hintText: 'One integer per line',
                      initialValue: node.gatePassExitCodes.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.gatePassExitCodes = _splitInts(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'gate_fail_exit_codes')),
                      label: 'Fail exit codes',
                      hintText: 'One integer per line',
                      initialValue: node.gateFailExitCodes.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.gateFailExitCodes = _splitInts(value);
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _InspectorToggleTile(
                      title: 'Treat retryable as fail',
                      value: node.treatRetryableAsFail,
                      subtitle:
                          'Promote retryable results into failed check outcomes.',
                      onChanged: (bool value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.treatRetryableAsFail = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            _InspectorPanelBlock(
              title: 'Deterministic rules',
              searchTerms: const <String>[
                'rule set',
                'fact bindings',
                'route hints',
                'session rule files',
                'evaluation error',
                'merge findings',
              ],
              child: _InspectorSection(
                title: 'Deterministic rules',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const InfoPanel(
                      title: 'Gate contract',
                      body:
                          'Gate steps reuse named Rule Sets from Harness > Rules. Rule Sets define the default evaluation settings; this gate can override them when this workflow needs a different policy posture.',
                    ),
                    const SizedBox(height: 12),
                    _InspectorToggleTile(
                      title: 'Enabled',
                      value: node.policyGateEnabled,
                      subtitle:
                          'Evaluate rules after the raw check result comes back.',
                      onChanged: (bool value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateEnabled = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _InspectorDropdownField(
                      key: ValueKey(_fieldKey(nodeKey, 'policy_gate_rule_set')),
                      label: 'Rule Set',
                      value: node.policyGateRuleSet.isEmpty
                          ? null
                          : node.policyGateRuleSet,
                      includeBlank: true,
                      blankLabel: 'Session rule files only',
                      options: ruleSetOptions,
                      helperText:
                          'Select a shared rule set from the Rules screen, or leave this blank and load per-session GRL files instead.',
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateRuleSet = (value ?? '').trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InspectorNumberField(
                            key: ValueKey(
                              _fieldKey(nodeKey, 'policy_gate_max_cycle'),
                            ),
                            label: 'Max cycle override',
                            initialValue: _intText(node.policyGateMaxCycle),
                            helperText:
                                'Leave at 0 to use the Rule Set default.',
                            onChanged: (int value) {
                              _updateNode((
                                _WorkflowDraft _,
                                _WorkflowNodeDraft targetNode,
                              ) {
                                targetNode.policyGateMaxCycle = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InspectorDropdownField(
                            key: ValueKey(
                              _fieldKey(nodeKey, 'policy_gate_fail_closed'),
                            ),
                            label: 'Fail closed',
                            value: _nullableBoolChoice(node.policyGateFailClosed),
                            includeBlank: true,
                            blankLabel: 'Rule Set default',
                            options: const <String>['enabled', 'disabled'],
                            onChanged: (String? value) {
                              _updateNode((
                                _WorkflowDraft _,
                                _WorkflowNodeDraft targetNode,
                              ) {
                                targetNode.policyGateFailClosed =
                                    _nullableBoolChoiceValue(value);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InspectorDropdownField(
                      key: ValueKey(
                        _fieldKey(
                          nodeKey,
                          'policy_gate_return_error_on_failed_rule_evaluation',
                        ),
                      ),
                      label: 'Return evaluation errors',
                      value: _nullableBoolChoice(
                        node.policyGateReturnEvalErrors,
                      ),
                      includeBlank: true,
                      blankLabel: 'Rule Set default',
                      options: const <String>['enabled', 'disabled'],
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateReturnEvalErrors =
                              _nullableBoolChoiceValue(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorDropdownField(
                      key: ValueKey(_fieldKey(nodeKey, 'policy_gate_on_error')),
                      label: 'On evaluation error',
                      value: node.policyGateOnEvaluationError.isEmpty
                          ? null
                          : node.policyGateOnEvaluationError,
                      includeBlank: true,
                      blankLabel: 'Fail (default)',
                      options: const <String>['fail', 'blocked'],
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateOnEvaluationError = (value ?? '')
                              .trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorDropdownField(
                      key: ValueKey(
                        _fieldKey(nodeKey, 'policy_gate_merge_findings'),
                      ),
                      label: 'Merge findings',
                      value: node.policyGateMergeFindings.isEmpty
                          ? null
                          : node.policyGateMergeFindings,
                      includeBlank: true,
                      blankLabel: 'Append (default)',
                      options: const <String>['append', 'replace'],
                      onChanged: (String? value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateMergeFindings = (value ?? '')
                              .trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(
                        _fieldKey(nodeKey, 'policy_gate_session_rule_files'),
                      ),
                      label: 'Session rule files',
                      hintText: 'One file pattern per line',
                      initialValue: node.policyGateSessionRuleFiles.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateSessionRuleFiles = _splitLines(
                            value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    const _InspectorListCard(
                      title: 'Available fact surfaces',
                      subtitle:
                          'Built-ins: Session, Workflow, Node, Input, and PolicyDecision. Add fact bindings when a reusable rule needs a stable named value such as a prior summary or an input key.',
                      tone: infoColor,
                    ),
                    const SizedBox(height: 12),
                    if (node.policyGateFactBindings.isEmpty)
                      const InfoPanel(
                        title: 'No fact bindings yet',
                        body:
                            'Bind only the facts this Rule Set depends on. That keeps the policy reusable between workflows.',
                      ),
                    if (node.policyGateFactBindings.isNotEmpty) ...[
                      for (
                        int index = 0;
                        index < node.policyGateFactBindings.length;
                        index++
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index == node.policyGateFactBindings.length - 1
                                ? 0
                                : 10,
                          ),
                          child: _buildPolicyFactBindingEditor(
                            workflow: workflow,
                            node: node,
                            nodeKey: nodeKey,
                            index: index,
                            binding: node.policyGateFactBindings[index],
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _addPolicyFactBinding,
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('Add fact binding'),
                    ),
                    const SizedBox(height: 12),
                    if (node.allowedRouteHints.isEmpty)
                      const InfoPanel(
                        title: 'No route hints yet',
                        body:
                            'Allowlist route hints only when rules may redirect the workflow to a known next step.',
                      ),
                    if (node.allowedRouteHints.isNotEmpty) ...[
                      for (
                        int index = 0;
                        index < node.allowedRouteHints.length;
                        index++
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == node.allowedRouteHints.length - 1
                                ? 0
                                : 10,
                          ),
                          child: _buildAllowedRouteHintEditor(
                            workflow: workflow,
                            node: node,
                            nodeKey: nodeKey,
                            index: index,
                            entry: node.allowedRouteHints.entries.elementAt(
                              index,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _addAllowedRouteHint,
                      icon: const Icon(Icons.alt_route_rounded),
                      label: const Text('Add route hint'),
                    ),
                    const SizedBox(height: 10),
                    _InspectorToggleTile(
                      title: 'Override raw check status',
                      value: node.policyGateOverrideGateStatus,
                      subtitle:
                          'Allow rules output to replace the raw check result.',
                      onChanged: (bool value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateOverrideGateStatus = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case _NodeInspectorPanel.completion:
        return _buildInspectorPanelContent(
          summaryCard: _buildNodeInspectorSummaryCard(workflow, node),
          searchQuery: searchQuery,
          emptyTitle: 'No matching completion controls',
          emptyBody:
              'Try a different search term to find limits, safety, or completion requirements.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Limits',
              searchTerms: const <String>[
                'max visits',
                'max failures',
                'retry',
              ],
              child: _InspectorSection(
                title: 'Limits',
                child: Row(
                  children: [
                    Expanded(
                      child: _InspectorNumberField(
                        key: ValueKey(_fieldKey(nodeKey, 'max_visits')),
                        label: 'Max visits',
                        initialValue: _intText(node.maxVisits),
                        onChanged: (int value) {
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.maxVisits = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InspectorNumberField(
                        key: ValueKey(_fieldKey(nodeKey, 'max_failures')),
                        label: 'Max failures',
                        initialValue: _intText(node.maxFailures),
                        onChanged: (int value) {
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.maxFailures = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _InspectorPanelBlock(
              title: 'Safety',
              searchTerms: const <String>[
                'write step',
                'implementation',
                'requires checks',
                'must pass checks',
              ],
              child: _InspectorSection(
                title: 'Safety',
                child: Column(
                  children: [
                    _InspectorToggleTile(
                      title: 'Write step',
                      value: node.implementation,
                      subtitle:
                          'Mark this as an implementation step that should stay behind checks.',
                      onChanged: (bool value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.implementation = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'requires_gates')),
                      label: 'Must pass checks from',
                      hintText: 'One check step id per line',
                      initialValue: node.requiresGates.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.requiresGates = _splitLines(value);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            _InspectorPanelBlock(
              title: 'Done means',
              searchTerms: const <String>[
                'required changed files',
                'required tool calls',
                'completion contract',
              ],
              child: _InspectorSection(
                title: 'Done means',
                child: Column(
                  children: [
                    _InspectorMultilineField(
                      key: ValueKey(
                        _fieldKey(nodeKey, 'required_changed_files'),
                      ),
                      label: 'Required changed files',
                      hintText: 'One path or glob per line',
                      initialValue: node.requiredChangedFiles.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.requiredChangedFiles = _splitLines(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorMultilineField(
                      key: ValueKey(_fieldKey(nodeKey, 'required_tool_calls')),
                      label: 'Required tool calls',
                      hintText: 'One tool id per line',
                      initialValue: node.requiredToolCalls.join('\n'),
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.requiredToolCalls = _splitLines(value);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildWorkflowInspectorSummaryCard(_WorkflowDraft workflow) {
    final referencedRuleSets = _referencedSharedRuleSets(workflow);
    return _buildInspectorSummaryCard(
      title: workflow.name,
      subtitle: _joinInline(<String>[
        workflow.startNode.isEmpty
            ? 'No start step configured'
            : 'Start ${workflow.startNode}',
        '${workflow.nodes.length} steps',
        if (referencedRuleSets.isNotEmpty)
          '${referencedRuleSets.length} shared rule${referencedRuleSets.length == 1 ? '' : 's'}',
      ]),
      footer: <Widget>[
        StatusPill(
          label:
              '${workflow.nodes.length} step${workflow.nodes.length == 1 ? '' : 's'}',
          color: infoColor,
        ),
        if (referencedRuleSets.isNotEmpty)
          StatusPill(
            label:
                '${referencedRuleSets.length} shared rule${referencedRuleSets.length == 1 ? '' : 's'}',
            color: successColor,
          ),
      ],
    );
  }

  Widget _buildNodeInspectorSummaryCard(
    _WorkflowDraft workflow,
    _WorkflowNodeDraft node,
  ) {
    final isCheck = _normalizeWorkflowKind(node.kind) == 'check';
    return _buildInspectorSummaryCard(
      title: node.id,
      subtitle: node.kind == 'finish'
          ? 'Final step'
          : (node.uses.isEmpty
                ? 'No target configured yet.'
                : 'Runs ${node.uses}'),
      footer: <Widget>[
        StatusPill(
          label: node.kind.isEmpty ? 'step' : node.kind,
          color: isCheck ? warningColor : infoColor,
        ),
        if (workflow.startNode == node.id)
          const StatusPill(label: 'start', color: accentColor),
        if (node.implementation)
          const StatusPill(label: 'write step', color: dangerColor),
      ],
    );
  }

  Widget _buildPolicyFactBindingEditor({
    required _WorkflowDraft workflow,
    required _WorkflowNodeDraft node,
    required String nodeKey,
    required int index,
    required _PolicyFactBindingDraft binding,
  }) {
    final nodeOptions = LinkedHashSet<String>.from(
      _nodeOptions(workflow).where((String value) => value.trim().isNotEmpty),
    );
    if (binding.node.trim().isNotEmpty) {
      nodeOptions.add(binding.node.trim());
    }
    final showNodeTarget = binding.source.trim() == 'node_result';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: infoColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  binding.name.isEmpty ? 'Fact binding' : binding.name,
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove fact binding',
                onPressed: () => _deletePolicyFactBinding(index),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InspectorTextField(
            key: ValueKey(_fieldKey(nodeKey, 'binding_${index}_name')),
            label: 'Fact name',
            initialValue: binding.name,
            helperText:
                'This becomes a named fact in GRL, for example `PlanInput.String()`.',
            onChanged: (String value) {
              _updatePolicyFactBinding(index, binding.copyWith(name: value));
            },
          ),
          const SizedBox(height: 12),
          _InspectorDropdownField(
            key: ValueKey(_fieldKey(nodeKey, 'binding_${index}_source')),
            label: 'Source',
            value: binding.source.isEmpty ? null : binding.source,
            includeBlank: true,
            blankLabel: 'Select source',
            options: const <String>[
              'session',
              'workflow',
              'node',
              'input',
              'outputs',
              'node_result',
            ],
            helperText:
                'Choose which stable snapshot the reusable rule should read from.',
            onChanged: (String? value) {
              _updatePolicyFactBinding(
                index,
                binding.copyWith(
                  source: value ?? '',
                  node: value == 'node_result' ? binding.node : '',
                ),
              );
            },
          ),
          if (showNodeTarget) ...[
            const SizedBox(height: 12),
            _InspectorDropdownField(
              key: ValueKey(_fieldKey(nodeKey, 'binding_${index}_node')),
              label: 'Source step',
              value: binding.node.isEmpty ? null : binding.node,
              includeBlank: true,
              blankLabel: 'Select step',
              options: nodeOptions.toList(growable: false),
              onChanged: (String? value) {
                _updatePolicyFactBinding(
                  index,
                  binding.copyWith(node: value ?? ''),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          _InspectorTextField(
            key: ValueKey(_fieldKey(nodeKey, 'binding_${index}_path')),
            label: 'Path',
            initialValue: binding.path,
            helperText:
                'Examples: `summary`, `outputs.changed_files`, or leave blank to bind the full snapshot.',
            onChanged: (String value) {
              _updatePolicyFactBinding(index, binding.copyWith(path: value));
            },
          ),
          const SizedBox(height: 10),
          _InspectorToggleTile(
            title: 'Required',
            value: binding.required,
            subtitle:
                'Mark this when rule evaluation should fail if the fact cannot be resolved.',
            onChanged: (bool value) {
              _updatePolicyFactBinding(
                index,
                binding.copyWith(required: value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAllowedRouteHintEditor({
    required _WorkflowDraft workflow,
    required _WorkflowNodeDraft node,
    required String nodeKey,
    required int index,
    required MapEntry<String, String> entry,
  }) {
    final targetOptions = LinkedHashSet<String>.from(
      _transitionOptionsFor(_nodeOptions(workflow), node.id, entry.value),
    );
    if (entry.value.trim().isNotEmpty) {
      targetOptions.add(entry.value.trim());
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.key.isEmpty ? 'Route hint' : entry.key,
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove route hint',
                onPressed: () => _deleteAllowedRouteHint(index),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InspectorTextField(
            key: ValueKey(_fieldKey(nodeKey, 'route_hint_${index}_name')),
            label: 'Hint name',
            initialValue: entry.key,
            helperText: 'Rules set this through `PolicyDecision.RouteHint`.',
            onChanged: (String value) {
              _updateAllowedRouteHint(index, hint: value.trim());
            },
          ),
          const SizedBox(height: 12),
          _InspectorDropdownField(
            key: ValueKey(_fieldKey(nodeKey, 'route_hint_${index}_target')),
            label: 'Target step',
            value: entry.value.isEmpty ? null : entry.value,
            includeBlank: true,
            blankLabel: 'Select step',
            options: targetOptions.toList(growable: false),
            helperText:
                'Only these steps may be reached when a rule emits this route hint.',
            onChanged: (String? value) {
              _updateAllowedRouteHint(index, target: value ?? '');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorSummaryCard({
    required String title,
    required String subtitle,
    List<Widget> footer = const <Widget>[],
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim().isEmpty ? 'Untitled' : title,
            style: const TextStyle(
              color: textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(color: textMutedColor, height: 1.45),
            ),
          ],
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: footer),
          ],
        ],
      ),
    );
  }

  Widget _buildInspectorPanelContent({
    required Widget summaryCard,
    required String searchQuery,
    required List<_InspectorPanelBlock> blocks,
    required String emptyTitle,
    required String emptyBody,
  }) {
    final visibleBlocks = blocks
        .where(
          (_InspectorPanelBlock block) =>
              searchQuery.trim().isEmpty ||
              AppFuzzySearch.matches(searchQuery, <String>[
                block.title,
                ...block.searchTerms,
              ]),
        )
        .toList(growable: false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summaryCard,
          const SizedBox(height: 14),
          if (visibleBlocks.isEmpty)
            EmptyState(title: emptyTitle, body: emptyBody)
          else
            for (int index = 0; index < visibleBlocks.length; index++) ...[
              visibleBlocks[index].child,
              if (index < visibleBlocks.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  String _nextNodeIdFor(_WorkflowDraft workflow) {
    var index = workflow.nodes.length + 1;
    while (true) {
      final candidate = 'node_$index';
      final exists = workflow.nodes.any(
        (_WorkflowNodeDraft node) => node.id == candidate,
      );
      if (!exists) {
        return candidate;
      }
      index += 1;
    }
  }
}

class _InspectorPanelBlock {
  const _InspectorPanelBlock({
    required this.title,
    required this.child,
    this.searchTerms = const <String>[],
  });

  final String title;
  final List<String> searchTerms;
  final Widget child;
}

class _WorkflowCollectionPane extends StatelessWidget {
  const _WorkflowCollectionPane({
    required this.workflowsBySection,
    required this.initialSectionId,
    required this.searchQuery,
    required this.selectedWorkflowKey,
    required this.onSearchChanged,
    required this.onSelectWorkflow,
  });

  final Map<_WorkflowCollectionSection, List<_WorkflowDraft>>
  workflowsBySection;
  final String initialSectionId;
  final String searchQuery;
  final String? selectedWorkflowKey;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_WorkflowDraft> onSelectWorkflow;

  String _titleForWorkflow(_WorkflowDraft workflow) {
    final trimmed = workflow.name.trim();
    return trimmed.isEmpty ? 'Untitled workflow' : trimmed;
  }

  String _subtitleForWorkflow(_WorkflowDraft workflow) {
    return _joinInline(<String>[
      workflow.startNode.isEmpty
          ? 'No start node configured'
          : 'Start ${workflow.startNode}',
      if (workflow.maxTotalTransitions > 0)
        '${workflow.maxTotalTransitions} hop cap',
    ]);
  }

  List<Widget> _footerForWorkflow(_WorkflowDraft workflow) {
    final gateCount = workflow.nodes
        .where(
          (_WorkflowNodeDraft node) =>
              _normalizeWorkflowKind(node.kind) == 'check',
        )
        .length;
    final implementationCount = workflow.nodes
        .where((_WorkflowNodeDraft node) => node.implementation)
        .length;
    final referencedRuleSets = LinkedHashSet<String>.from(
      workflow.nodes
          .map((_WorkflowNodeDraft node) => node.policyGateRuleSet.trim())
          .where((String value) => value.isNotEmpty),
    );
    final footer = <Widget>[
      StatusPill(
        label:
            '${workflow.nodes.length} step${workflow.nodes.length == 1 ? '' : 's'}',
        color: infoColor,
      ),
    ];
    if (referencedRuleSets.isNotEmpty) {
      footer.add(
        StatusPill(
          label:
              '${referencedRuleSets.length} shared rule${referencedRuleSets.length == 1 ? '' : 's'}',
          color: successColor,
        ),
      );
    }
    if (gateCount > 0) {
      footer.add(StatusPill(label: '$gateCount checks', color: warningColor));
    }
    if (implementationCount > 0) {
      footer.add(
        StatusPill(
          label:
              '$implementationCount implementation${implementationCount == 1 ? '' : 's'}',
          color: accentColor,
        ),
      );
    }
    return footer;
  }

  @override
  Widget build(BuildContext context) {
    return AppDenseSidePanel<_WorkflowDraft>(
      initialSectionId: initialSectionId,
      initialSearchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      selectedEntryId: selectedWorkflowKey,
      entryId: (_WorkflowDraft workflow) => workflow.localKey,
      onSelectEntry: onSelectWorkflow,
      searchHintText: 'Search workflows and steps...',
      emptyTitle: 'No workflow panels',
      emptyBody: 'Workflow sections will appear here once the catalog loads.',
      sections: _WorkflowCollectionSection.values
          .map((_WorkflowCollectionSection section) {
            final workflows =
                workflowsBySection[section] ?? const <_WorkflowDraft>[];
            return AppDenseSidePanelSection<_WorkflowDraft>(
              id: section.sectionId,
              label: section.panelLabel,
              icon: section.panelIcon,
              entries: workflows,
              searchFields: (_WorkflowDraft workflow) => <String>[
                workflow.name,
                workflow.startNode,
                ...workflow.nodes.expand((_WorkflowNodeDraft node) {
                  return <String>[
                    node.id,
                    node.kind,
                    node.uses,
                    node.policyGateRuleSet,
                    ...node.requiredInputKeys,
                    ...node.requiredDataKeys,
                    ...node.requiresGates,
                    ...node.includeNodeResults,
                    ...node.requiredChangedFiles,
                    ...node.requiredToolCalls,
                  ];
                }),
              ],
              emptyTitle: section.emptyTitle,
              emptyBody: section.emptyBody,
              rowBuilder:
                  (
                    BuildContext context,
                    _WorkflowDraft workflow,
                    bool selected,
                    VoidCallback onTap,
                  ) {
                    return AppDenseSidePanelRow(
                      title: _titleForWorkflow(workflow),
                      subtitle: _subtitleForWorkflow(workflow),
                      selected: selected,
                      onTap: onTap,
                      footer: _footerForWorkflow(workflow),
                    );
                  },
            );
          })
          .toList(growable: false),
    );
  }
}

class _WorkflowCanvasPane extends StatelessWidget {
  const _WorkflowCanvasPane({
    required this.workflow,
    required this.layout,
    required this.selectedNodeKey,
    required this.controller,
    required this.scaleLabel,
    required this.onSelectNode,
    required this.onClearNodeSelection,
    required this.onViewportMeasured,
    required this.onToggleSource,
    required this.onToggleInspector,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitCanvas,
    required this.sourceDrawerOpen,
    required this.inspectorVisible,
    required this.viewportSize,
  });

  final _WorkflowDraft workflow;
  final _WorkflowGraphLayout layout;
  final String? selectedNodeKey;
  final TransformationController controller;
  final String scaleLabel;
  final ValueChanged<String?> onSelectNode;
  final VoidCallback onClearNodeSelection;
  final void Function(Size viewport, _WorkflowGraphLayout layout)
  onViewportMeasured;
  final VoidCallback onToggleSource;
  final VoidCallback onToggleInspector;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitCanvas;
  final bool sourceDrawerOpen;
  final bool inspectorVisible;
  final Size viewportSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkflowCanvasToolbar(
            workflow: workflow,
            scaleLabel: scaleLabel,
            sourceDrawerOpen: sourceDrawerOpen,
            inspectorVisible: inspectorVisible,
            onToggleSource: onToggleSource,
            onToggleInspector: onToggleInspector,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onFitCanvas: onFitCanvas,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor.withValues(alpha: 0.9)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xE6111824), Color(0xE20B121C)],
                ),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final viewport = constraints.biggest;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onViewportMeasured(viewport, layout);
                  });
                  if (workflow.nodes.isEmpty) {
                    return const Center(
                      child: EmptyState(
                        title: 'No steps',
                        body:
                            'Use the workflow panel to add the first step to this workflow.',
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          key: const ValueKey<String>(
                            'workflow-canvas-viewport',
                          ),
                          behavior: HitTestBehavior.translucent,
                          onTap: onClearNodeSelection,
                          child: InteractiveViewer(
                            transformationController: controller,
                            boundaryMargin: const EdgeInsets.all(1400),
                            constrained: false,
                            minScale: 0.18,
                            maxScale: 2.4,
                            child: SizedBox(
                              width: layout.boardSize.width,
                              height: layout.boardSize.height,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: onClearNodeSelection,
                                      child: CustomPaint(
                                        painter: _WorkflowBoardPainter(
                                          layout: layout,
                                          selectedNodeKey: selectedNodeKey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final placement in layout.placements)
                                    Positioned(
                                      left: placement.rect.left,
                                      top: placement.rect.top,
                                      child: _WorkflowCanvasNodeCard(
                                        node: placement.node,
                                        selected:
                                            placement.node.localKey ==
                                            selectedNodeKey,
                                        startNodeId: workflow.startNode,
                                        onTap: () => onSelectNode(
                                          placement.node.localKey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 16,
                        top: 16,
                        child: _WorkflowStageLegend(),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: _WorkflowMiniMap(
                          layout: layout,
                          controller: controller,
                          viewportSize: viewportSize,
                          selectedNodeKey: selectedNodeKey,
                        ),
                      ),
                      const Positioned(
                        right: 16,
                        top: 16,
                        child: _WorkflowStageHint(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowCanvasToolbar extends StatelessWidget {
  const _WorkflowCanvasToolbar({
    required this.workflow,
    required this.scaleLabel,
    required this.sourceDrawerOpen,
    required this.inspectorVisible,
    required this.onToggleSource,
    required this.onToggleInspector,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitCanvas,
  });

  final _WorkflowDraft workflow;
  final String scaleLabel;
  final bool sourceDrawerOpen;
  final bool inspectorVisible;
  final VoidCallback onToggleSource;
  final VoidCallback onToggleInspector;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitCanvas;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 14,
      spacing: 18,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workflow.name,
                style: const TextStyle(
                  color: textPrimaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _joinInline(<String>[
                  workflow.startNode.isEmpty
                      ? 'No start node configured'
                      : 'Start ${workflow.startNode}',
                  '${workflow.nodes.length} steps',
                  if (workflow.maxVisitsPerNode > 0)
                    '${workflow.maxVisitsPerNode} max visits',
                  if (workflow.maxTotalTransitions > 0)
                    '${workflow.maxTotalTransitions} transition cap',
                ]),
                style: const TextStyle(color: textMutedColor),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CanvasToolbarButton(
              icon: Icons.fit_screen_rounded,
              label: 'Fit',
              onTap: onFitCanvas,
            ),
            _CanvasToolbarButton(
              icon: Icons.remove_rounded,
              label: 'Zoom out',
              onTap: onZoomOut,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: panelAltColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                scaleLabel,
                style: const TextStyle(
                  color: textPrimaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _CanvasToolbarButton(
              icon: Icons.add_rounded,
              label: 'Zoom in',
              onTap: onZoomIn,
            ),
            _CanvasToolbarButton(
              icon: sourceDrawerOpen
                  ? Icons.code_off_rounded
                  : Icons.code_rounded,
              label: sourceDrawerOpen ? 'Hide source' : 'Source',
              onTap: onToggleSource,
            ),
            _CanvasToolbarButton(
              icon: inspectorVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              label: inspectorVisible ? 'Hide inspector' : 'Show inspector',
              onTap: onToggleInspector,
            ),
          ],
        ),
      ],
    );
  }
}

class _CanvasToolbarButton extends StatelessWidget {
  const _CanvasToolbarButton({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: panelAltColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textMutedColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: textPrimaryColor,
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

class _WorkflowCanvasNodeCard extends StatelessWidget {
  const _WorkflowCanvasNodeCard({
    required this.node,
    required this.selected,
    required this.startNodeId,
    required this.onTap,
  });

  final _WorkflowNodeDraft node;
  final bool selected;
  final String startNodeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (node.requiredInputKeys.isNotEmpty)
        '${node.requiredInputKeys.length} required input${node.requiredInputKeys.length == 1 ? '' : 's'}',
      if (node.requiredDataKeys.isNotEmpty)
        '${node.requiredDataKeys.length} required output${node.requiredDataKeys.length == 1 ? '' : 's'}',
      if (node.inputMappings.isNotEmpty)
        '${node.inputMappings.length} mapping${node.inputMappings.length == 1 ? '' : 's'}',
      if (node.policyGateEnabled) 'rules',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _WorkflowGraphLayout.nodeSize.width,
          height: _WorkflowGraphLayout.nodeSize.height,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: selected ? panelRaisedColor : const Color(0xEE172232),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? accentColor
                  : borderColor.withValues(alpha: 0.92),
              width: selected ? 1.8 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected ? accentColor : Colors.black).withValues(
                  alpha: selected ? 0.18 : 0.24,
                ),
                blurRadius: selected ? 26 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      node.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (node.id == startNodeId)
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusPill(
                    label: node.kind.isEmpty ? 'node' : node.kind,
                    color: _nodeKindColor(node.kind),
                  ),
                  if (node.id == startNodeId)
                    const StatusPill(label: 'start', color: accentColor),
                  if (node.implementation)
                    const StatusPill(label: 'implementation', color: infoColor),
                  if (node.policyGateEnabled)
                    const StatusPill(label: 'policy', color: warningColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                node.uses.isEmpty
                    ? 'No target configured'
                    : 'Runs ${node.uses}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: textMutedColor, height: 1.45),
              ),
              const Spacer(),
              Text(
                details.isEmpty
                    ? 'Select to edit this step.'
                    : details.join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textSubtleColor,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowStageLegend extends StatelessWidget {
  const _WorkflowStageLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xB6111A25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.85)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: const [
          _WorkflowLegendPill(label: 'success', color: successColor),
          _WorkflowLegendPill(label: 'failure', color: dangerColor),
          _WorkflowLegendPill(label: 'blocked', color: warningColor),
        ],
      ),
    );
  }
}

class _WorkflowLegendPill extends StatelessWidget {
  const _WorkflowLegendPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: textMutedColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WorkflowStageHint extends StatelessWidget {
  const _WorkflowStageHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xB6111A25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.85)),
      ),
      child: const Text(
        'Pan to explore. Scroll or use toolbar zoom.',
        style: TextStyle(
          color: textMutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WorkflowMiniMap extends StatelessWidget {
  const _WorkflowMiniMap({
    required this.layout,
    required this.controller,
    required this.viewportSize,
    required this.selectedNodeKey,
  });

  final _WorkflowGraphLayout layout;
  final TransformationController controller;
  final Size viewportSize;
  final String? selectedNodeKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 188,
      height: 128,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xB6111A25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: 0.88)),
      ),
      child: CustomPaint(
        painter: _WorkflowMiniMapPainter(
          layout: layout,
          controller: controller,
          viewportSize: viewportSize,
          selectedNodeKey: selectedNodeKey,
        ),
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textPrimaryColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _InspectorTextField extends StatelessWidget {
  const _InspectorTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.errorText,
    this.helperText,
  });

  final String label;
  final String initialValue;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      style: const TextStyle(color: textPrimaryColor),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        helperText: helperText,
      ),
    );
  }
}

class _InspectorNumberField extends StatelessWidget {
  const _InspectorNumberField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final String initialValue;
  final ValueChanged<int> onChanged;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      onChanged: (String value) => onChanged(_parseInt(value)),
      style: const TextStyle(color: textPrimaryColor),
      decoration: InputDecoration(labelText: label, helperText: helperText),
    );
  }
}

class _InspectorDropdownField extends StatelessWidget {
  const _InspectorDropdownField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.includeBlank = false,
    this.blankLabel = 'None',
    this.helperText,
  });

  final String label;
  final List<String> options;
  final String? value;
  final bool includeBlank;
  final String blankLabel;
  final String? helperText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final distinctOptions = LinkedHashSet<String>.from(
      options.where((String value) => value.trim().isNotEmpty),
    ).toList();
    final currentValue = value != null && distinctOptions.contains(value)
        ? value
        : null;
    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      onChanged: onChanged,
      dropdownColor: panelAltColor,
      iconEnabledColor: textMutedColor,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      items: <DropdownMenuItem<String>>[
        if (includeBlank)
          DropdownMenuItem<String>(value: null, child: Text(blankLabel)),
        ...distinctOptions.map(
          (String option) => DropdownMenuItem<String>(
            value: option,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}

class _InspectorMultilineField extends StatelessWidget {
  const _InspectorMultilineField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.helperText,
  });

  final String label;
  final String initialValue;
  final String? hintText;
  final String? helperText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: null,
      minLines: 3,
      style: const TextStyle(color: textPrimaryColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        alignLabelWithHint: true,
      ),
    );
  }
}

class _InspectorYamlEditor extends StatelessWidget {
  const _InspectorYamlEditor({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.helperText,
    this.errorText,
  });

  final String label;
  final String initialValue;
  final String? helperText;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: null,
      minLines: 6,
      style: const TextStyle(
        color: textPrimaryColor,
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.45,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        alignLabelWithHint: true,
      ),
    );
  }
}

class _InspectorToggleTile extends StatelessWidget {
  const _InspectorToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final bool value;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: textMutedColor, height: 1.35),
              ),
      ),
    );
  }
}

class _InspectorActionCard extends StatelessWidget {
  const _InspectorActionCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String body;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: textMutedColor, height: 1.45),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _InspectorInlineFacts extends StatelessWidget {
  const _InspectorInlineFacts({required this.entries});

  final List<MapEntry<String, String>> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: panelAltColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor.withValues(alpha: 0.86)),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.key}: ',
                    style: const TextStyle(
                      color: textMutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: entry.value,
                    style: const TextStyle(
                      color: textPrimaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InspectorListCard extends StatelessWidget {
  const _InspectorListCard({
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  final String title;
  final String subtitle;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Unnamed entry' : title,
            style: TextStyle(color: tone, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle.trim().isEmpty
                ? 'No additional detail recorded.'
                : subtitle,
            style: const TextStyle(color: textMutedColor, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _WorkflowValidationSummaryCard extends StatelessWidget {
  const _WorkflowValidationSummaryCard({required this.report});

  final HarnessConfigValidationReport report;

  @override
  Widget build(BuildContext context) {
    final valid = report.status.toLowerCase() == 'ok';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelAltColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: valid ? successColor : dangerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: valid ? 'valid catalog' : 'validation issues',
            color: valid ? successColor : dangerColor,
          ),
          const SizedBox(height: 10),
          Text(
            report.summary.isEmpty
                ? 'Validation results will appear here after running the harness checks.'
                : report.summary,
            style: const TextStyle(color: textMutedColor, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _WorkflowSourceDrawer extends StatelessWidget {
  const _WorkflowSourceDrawer({
    required this.open,
    required this.controller,
    required this.validation,
    required this.parseError,
    required this.onApplySource,
    required this.onClose,
  });

  final bool open;
  final TextEditingController controller;
  final HarnessConfigValidationReport? validation;
  final String? parseError;
  final VoidCallback onApplySource;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState: open
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: Container(
        width: double.infinity,
        height: 380,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Workflow Catalog Source',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onApplySource,
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: const Text('Apply source'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Edit the full workflow catalog YAML here. Click Apply source to rebuild the board from manual YAML changes.',
              style: TextStyle(color: textMutedColor),
            ),
            if (parseError != null && parseError!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dangerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: dangerColor.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  parseError!,
                  style: const TextStyle(color: textPrimaryColor, height: 1.45),
                ),
              ),
            ],
            if (validation != null) ...[
              const SizedBox(height: 14),
              _WorkflowValidationSummaryCard(report: validation!),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: controller,
                expands: true,
                maxLines: null,
                minLines: null,
                style: const TextStyle(
                  color: textPrimaryColor,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.45,
                ),
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'Catalog YAML',
                ),
              ),
            ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }
}

class _WorkflowBoardPainter extends CustomPainter {
  _WorkflowBoardPainter({required this.layout, required this.selectedNodeKey});

  final _WorkflowGraphLayout layout;
  final String? selectedNodeKey;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    for (final edge in layout.edges) {
      final source = layout.nodeRect(edge.sourceKey);
      final target = layout.nodeRect(edge.targetKey);
      if (source == null || target == null) {
        continue;
      }
      final emphasized =
          selectedNodeKey == null ||
          edge.sourceKey == selectedNodeKey ||
          edge.targetKey == selectedNodeKey;
      final color = edge.color.withValues(alpha: emphasized ? 0.92 : 0.28);
      final path = _edgePath(source, target);
      final paint = Paint()
        ..color = color
        ..strokeWidth = emphasized ? 2.6 : 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
      _paintArrowHead(canvas, path, color);
      _paintEdgeLabel(canvas, path, edge.label, edge.color);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final smallGrid = Paint()
      ..color = const Color(0x172F415E)
      ..strokeWidth = 1;
    final largeGrid = Paint()
      ..color = const Color(0x24405A80)
      ..strokeWidth = 1.2;

    for (double x = 0; x <= size.width; x += 32) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        x % 160 == 0 ? largeGrid : smallGrid,
      );
    }
    for (double y = 0; y <= size.height; y += 32) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        y % 160 == 0 ? largeGrid : smallGrid,
      );
    }
  }

  Path _edgePath(Rect source, Rect target) {
    if (target.center.dx > source.center.dx + 32) {
      final start = Offset(source.right, source.center.dy);
      final end = Offset(target.left, target.center.dy);
      final bendX = (start.dx + end.dx) / 2;
      return Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(bendX, start.dy)
        ..lineTo(bendX, end.dy)
        ..lineTo(end.dx, end.dy);
    }

    if (target.center.dx < source.center.dx - 32) {
      final start = Offset(source.left, source.center.dy);
      final end = Offset(target.right, target.center.dy);
      final bendX = math.min(start.dx, end.dx) - 130;
      return Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(bendX, start.dy)
        ..lineTo(bendX, end.dy)
        ..lineTo(end.dx, end.dy);
    }

    final start = Offset(source.center.dx, source.bottom);
    final end = Offset(target.center.dx, target.top);
    final bendY = (start.dy + end.dy) / 2;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(start.dx, bendY)
      ..lineTo(end.dx, bendY)
      ..lineTo(end.dx, end.dy);
  }

  void _paintArrowHead(Canvas canvas, Path path, Color color) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) {
      return;
    }
    final metric = metrics.last;
    final tangent = metric.getTangentForOffset(metric.length);
    if (tangent == null) {
      return;
    }
    const arrowLength = 10.0;
    const arrowWidth = 6.0;
    final direction = tangent.vector / tangent.vector.distance;
    final normal = Offset(-direction.dy, direction.dx);
    final tip = tangent.position;
    final base = tip - (direction * arrowLength);
    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        base.dx + (normal.dx * arrowWidth),
        base.dy + (normal.dy * arrowWidth),
      )
      ..lineTo(
        base.dx - (normal.dx * arrowWidth),
        base.dy - (normal.dy * arrowWidth),
      )
      ..close();
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintEdgeLabel(Canvas canvas, Path path, String label, Color color) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) {
      return;
    }
    final metric = metrics.first;
    final tangent = metric.getTangentForOffset(metric.length * 0.5);
    if (tangent == null) {
      return;
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: tangent.position,
      width: textPainter.width + 16,
      height: textPainter.height + 8,
    );
    final background = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(999),
    );
    canvas.drawRRect(background, Paint()..color = const Color(0xE6111A25));
    canvas.drawRRect(
      background,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.28),
    );
    textPainter.paint(
      canvas,
      Offset(
        rect.left + ((rect.width - textPainter.width) / 2),
        rect.top + ((rect.height - textPainter.height) / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WorkflowBoardPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.selectedNodeKey != selectedNodeKey;
  }
}

class _WorkflowMiniMapPainter extends CustomPainter {
  _WorkflowMiniMapPainter({
    required this.layout,
    required this.controller,
    required this.viewportSize,
    required this.selectedNodeKey,
  });

  final _WorkflowGraphLayout layout;
  final TransformationController controller;
  final Size viewportSize;
  final String? selectedNodeKey;

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Offset.zero & layout.boardSize;
    final scale = math.min(
      size.width / boardRect.width,
      size.height / boardRect.height,
    );
    final translatedBoard = Rect.fromLTWH(
      (size.width - (boardRect.width * scale)) / 2,
      (size.height - (boardRect.height * scale)) / 2,
      boardRect.width * scale,
      boardRect.height * scale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(translatedBoard, const Radius.circular(12)),
      Paint()..color = const Color(0xFF0D1621),
    );

    for (final placement in layout.placements) {
      final normalized = Rect.fromLTWH(
        translatedBoard.left + (placement.rect.left * scale),
        translatedBoard.top + (placement.rect.top * scale),
        placement.rect.width * scale,
        placement.rect.height * scale,
      );
      final nodeColor = placement.node.localKey == selectedNodeKey
          ? accentColor
          : _nodeKindColor(placement.node.kind);
      canvas.drawRRect(
        RRect.fromRectAndRadius(normalized, const Radius.circular(4)),
        Paint()..color = nodeColor.withValues(alpha: 0.8),
      );
    }

    if (viewportSize.width > 0 && viewportSize.height > 0) {
      final inverse = Matrix4.inverted(controller.value);
      final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
      final bottomRight = MatrixUtils.transformPoint(
        inverse,
        Offset(viewportSize.width, viewportSize.height),
      );
      final viewportRect = Rect.fromPoints(topLeft, bottomRight);
      final normalizedViewport = Rect.fromLTWH(
        translatedBoard.left + (viewportRect.left * scale),
        translatedBoard.top + (viewportRect.top * scale),
        viewportRect.width * scale,
        viewportRect.height * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(normalizedViewport, const Radius.circular(6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = accentColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(normalizedViewport, const Radius.circular(6)),
        Paint()..color = accentColor.withValues(alpha: 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WorkflowMiniMapPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.controller.value != controller.value ||
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.selectedNodeKey != selectedNodeKey;
  }
}

class _WorkflowGraphLayout {
  _WorkflowGraphLayout({
    required this.placements,
    required this.edges,
    required this.contentBounds,
    required this.boardSize,
  });

  static const Size nodeSize = Size(296, 200);
  static const double _columnGap = 176;
  static const double _rowGap = 112;
  static const double _paddingX = 260;
  static const double _paddingY = 220;

  final List<_WorkflowNodePlacement> placements;
  final List<_WorkflowEdge> edges;
  final Rect contentBounds;
  final Size boardSize;

  static _WorkflowGraphLayout fromWorkflow(_WorkflowDraft workflow) {
    final nodesById = <String, _WorkflowNodeDraft>{
      for (final node in workflow.nodes) node.id: node,
    };
    final visitOrder = <String, int>{};
    final queue = <String>[];
    if (nodesById.containsKey(workflow.startNode)) {
      queue.add(workflow.startNode);
    }
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visitOrder.containsKey(current)) {
        continue;
      }
      visitOrder[current] = visitOrder.length;
      final node = nodesById[current];
      if (node == null) {
        continue;
      }
      for (final edge in node.transitions.targets()) {
        if (edge.value.isNotEmpty) {
          queue.add(edge.value);
        }
      }
      for (final target in node.allowedRouteHints.values) {
        if (target.isNotEmpty) {
          queue.add(target);
        }
      }
    }
    for (final node in workflow.nodes) {
      visitOrder.putIfAbsent(node.id, () => visitOrder.length);
    }

    final depths = <String, int>{};
    if (nodesById.containsKey(workflow.startNode)) {
      final depthQueue = <String>[workflow.startNode];
      depths[workflow.startNode] = 0;
      while (depthQueue.isNotEmpty) {
        final current = depthQueue.removeAt(0);
        final currentDepth = depths[current] ?? 0;
        final node = nodesById[current];
        if (node == null) {
          continue;
        }
        final targets = <String>[
          ...node.transitions.targets().map(
            (MapEntry<String, String> entry) => entry.value,
          ),
          ...node.allowedRouteHints.values,
        ];
        for (final target in targets) {
          if (!nodesById.containsKey(target) || depths.containsKey(target)) {
            continue;
          }
          depths[target] = currentDepth + 1;
          depthQueue.add(target);
        }
      }
    }

    final maxDepth = depths.values.isEmpty ? 0 : depths.values.reduce(math.max);
    for (final node in workflow.nodes) {
      depths.putIfAbsent(node.id, () => maxDepth + 1);
    }

    final columns = <int, List<_WorkflowNodeDraft>>{};
    for (final node in workflow.nodes) {
      columns
          .putIfAbsent(depths[node.id] ?? 0, () => <_WorkflowNodeDraft>[])
          .add(node);
    }
    for (final entry in columns.entries) {
      entry.value.sort((_WorkflowNodeDraft left, _WorkflowNodeDraft right) {
        final leftOrder = visitOrder[left.id] ?? 0;
        final rightOrder = visitOrder[right.id] ?? 0;
        if (leftOrder != rightOrder) {
          return leftOrder.compareTo(rightOrder);
        }
        return left.id.compareTo(right.id);
      });
    }

    final maxRows = columns.values.fold<int>(
      0,
      (int total, List<_WorkflowNodeDraft> column) =>
          math.max(total, column.length),
    );
    final columnCount = columns.keys.isEmpty ? 1 : columns.keys.length;
    final boardWidth = math.max(
      2400,
      (_paddingX * 2) +
          (columnCount * nodeSize.width) +
          ((math.max(0, columnCount - 1)) * _columnGap),
    );
    final boardHeight = math.max(
      1800,
      (_paddingY * 2) +
          (maxRows * nodeSize.height) +
          ((math.max(0, maxRows - 1)) * _rowGap),
    );

    final placements = <_WorkflowNodePlacement>[];
    for (final depth in columns.keys.toList()..sort()) {
      final column = columns[depth]!;
      final columnHeight =
          (column.length * nodeSize.height) +
          (math.max(0, column.length - 1) * _rowGap);
      final startY = (boardHeight - columnHeight) / 2;
      final x = _paddingX + (depth * (nodeSize.width + _columnGap));
      for (int index = 0; index < column.length; index++) {
        final y = startY + (index * (nodeSize.height + _rowGap));
        placements.add(
          _WorkflowNodePlacement(
            node: column[index],
            rect: Rect.fromLTWH(x, y, nodeSize.width, nodeSize.height),
          ),
        );
      }
    }

    final placementById = <String, _WorkflowNodePlacement>{
      for (final placement in placements) placement.node.id: placement,
    };
    final edges = <_WorkflowEdge>[];
    for (final node in workflow.nodes) {
      for (final target in node.transitions.targets()) {
        final targetPlacement = placementById[target.value];
        if (targetPlacement != null) {
          edges.add(
            _WorkflowEdge(
              sourceKey: node.localKey,
              targetKey: targetPlacement.node.localKey,
              label: target.key,
              color: _edgeColor(target.key),
            ),
          );
        }
      }
      for (final hint in node.allowedRouteHints.entries) {
        final targetPlacement = placementById[hint.value];
        if (targetPlacement != null) {
          edges.add(
            _WorkflowEdge(
              sourceKey: node.localKey,
              targetKey: targetPlacement.node.localKey,
              label: hint.key,
              color: accentColor,
            ),
          );
        }
      }
    }

    Rect bounds = placements.isEmpty ? Rect.zero : placements.first.rect;
    for (final placement in placements.skip(1)) {
      bounds = bounds.expandToInclude(placement.rect);
    }

    return _WorkflowGraphLayout(
      placements: placements,
      edges: edges,
      contentBounds: placements.isEmpty
          ? Rect.fromLTWH(0, 0, boardWidth.toDouble(), boardHeight.toDouble())
          : bounds,
      boardSize: Size(boardWidth.toDouble(), boardHeight.toDouble()),
    );
  }

  Rect? nodeRect(String nodeKey) {
    for (final placement in placements) {
      if (placement.node.localKey == nodeKey) {
        return placement.rect;
      }
    }
    return null;
  }
}

class _WorkflowNodePlacement {
  const _WorkflowNodePlacement({required this.node, required this.rect});

  final _WorkflowNodeDraft node;
  final Rect rect;
}

class _WorkflowEdge {
  const _WorkflowEdge({
    required this.sourceKey,
    required this.targetKey,
    required this.label,
    required this.color,
  });

  final String sourceKey;
  final String targetKey;
  final String label;
  final Color color;
}

class _WorkflowDraft {
  _WorkflowDraft({
    required this.localKey,
    required this.name,
    required this.startNode,
    required this.maxVisitsPerNode,
    required this.maxTotalTransitions,
    required this.duplicateResultCap,
    required this.nodes,
    required this.extraFields,
  });

  factory _WorkflowDraft.fromYaml({
    required String localKey,
    required Map<String, Object?> raw,
    required String Function() nextNodeLocalKey,
  }) {
    final map = LinkedHashMap<String, Object?>.from(raw);
    final nodes = ((map['nodes'] as List<Object?>?) ?? const <Object?>[])
        .whereType<Map<String, Object?>>()
        .map(
          (Map<String, Object?> value) => _WorkflowNodeDraft.fromYaml(
            localKey: nextNodeLocalKey(),
            raw: value,
          ),
        )
        .toList();
    return _WorkflowDraft(
      localKey: localKey,
      name: _stringValue(map.remove('name')),
      startNode: _stringValue(map.remove('start_node')),
      maxVisitsPerNode: _intValue(map.remove('max_visits_per_node')),
      maxTotalTransitions: _intValue(map.remove('max_total_transitions')),
      duplicateResultCap: _intValue(map.remove('duplicate_result_cap')),
      nodes: nodes,
      extraFields: map..remove('rule_sets'),
    );
  }

  factory _WorkflowDraft.fromSummary({
    required String localKey,
    required HarnessWorkflowSummary summary,
    required String Function() nextNodeLocalKey,
  }) {
    return _WorkflowDraft(
      localKey: localKey,
      name: summary.name,
      startNode: summary.startNode,
      maxVisitsPerNode: summary.maxVisitsPerNode,
      maxTotalTransitions: summary.maxTotalTransitions,
      duplicateResultCap: summary.duplicateResultCap,
      nodes: summary.nodes
          .map(
            (HarnessWorkflowNodeSummary node) => _WorkflowNodeDraft.fromSummary(
              localKey: nextNodeLocalKey(),
              summary: node,
            ),
          )
          .toList(),
      extraFields: <String, Object?>{},
    );
  }

  final String localKey;
  String name;
  String startNode;
  int maxVisitsPerNode;
  int maxTotalTransitions;
  int duplicateResultCap;
  List<_WorkflowNodeDraft> nodes;
  Map<String, Object?> extraFields;

  Map<String, Object?> toYamlMap() {
    final map = <String, Object?>{}
      ..['name'] = name
      ..['start_node'] = startNode
      ..addAll(extraFields);
    if (maxVisitsPerNode > 0) {
      map['max_visits_per_node'] = maxVisitsPerNode;
    } else {
      map.remove('max_visits_per_node');
    }
    if (maxTotalTransitions > 0) {
      map['max_total_transitions'] = maxTotalTransitions;
    } else {
      map.remove('max_total_transitions');
    }
    if (duplicateResultCap > 0) {
      map['duplicate_result_cap'] = duplicateResultCap;
    } else {
      map.remove('duplicate_result_cap');
    }
    map['nodes'] = nodes
        .map((_WorkflowNodeDraft node) => node.toYamlMap())
        .toList();
    return map;
  }
}

class _WorkflowNodeDraft {
  _WorkflowNodeDraft({
    required this.localKey,
    required this.id,
    required this.kind,
    required this.uses,
    Map<String, Object?>? withValues,
    List<String>? requiredInputKeys,
    List<String>? optionalInputKeys,
    List<String>? requiredDataKeys,
    this.producesGateDecision = false,
    _WorkflowTransitionsDraft? transitions,
    this.maxVisits = 0,
    this.maxFailures = 0,
    this.implementation = false,
    List<String>? requiresGates,
    List<String>? includeNodeResults,
    List<_WorkflowInputMappingDraft>? inputMappings,
    List<String>? promptInstructions,
    List<String>? gatePassStatuses,
    List<String>? gateFailStatuses,
    List<int>? gatePassExitCodes,
    List<int>? gateFailExitCodes,
    this.treatRetryableAsFail = false,
    this.policyGateEnabled = false,
    this.policyGateRuleSet = '',
    List<String>? policyGateSessionRuleFiles,
    this.policyGateMaxCycle = 0,
    this.policyGateReturnEvalErrors,
    this.policyGateFailClosed,
    List<_PolicyFactBindingDraft>? policyGateFactBindings,
    Map<String, String>? allowedRouteHints,
    this.policyGateOnEvaluationError = '',
    this.policyGateMergeFindings = '',
    this.policyGateOverrideGateStatus = false,
    List<String>? requiredChangedFiles,
    List<String>? requiredToolCalls,
    Map<String, Object?>? extraFields,
  }) : withValues = withValues ?? <String, Object?>{},
       requiredInputKeys = requiredInputKeys ?? <String>[],
       optionalInputKeys = optionalInputKeys ?? <String>[],
       requiredDataKeys = requiredDataKeys ?? <String>[],
       transitions = transitions ?? _WorkflowTransitionsDraft(),
       requiresGates = requiresGates ?? <String>[],
       includeNodeResults = includeNodeResults ?? <String>[],
       inputMappings = inputMappings ?? <_WorkflowInputMappingDraft>[],
       promptInstructions = promptInstructions ?? <String>[],
       gatePassStatuses = gatePassStatuses ?? <String>[],
       gateFailStatuses = gateFailStatuses ?? <String>[],
       gatePassExitCodes = gatePassExitCodes ?? <int>[],
       gateFailExitCodes = gateFailExitCodes ?? <int>[],
       policyGateSessionRuleFiles = policyGateSessionRuleFiles ?? <String>[],
       policyGateFactBindings =
           policyGateFactBindings ?? <_PolicyFactBindingDraft>[],
       allowedRouteHints = allowedRouteHints ?? <String, String>{},
       requiredChangedFiles = requiredChangedFiles ?? <String>[],
       requiredToolCalls = requiredToolCalls ?? <String>[],
       extraFields = extraFields ?? <String, Object?>{};

  factory _WorkflowNodeDraft.fromYaml({
    required String localKey,
    required Map<String, Object?> raw,
  }) {
    final map = LinkedHashMap<String, Object?>.from(raw);
    final withValues = LinkedHashMap<String, Object?>.from(
      (map.remove('with') as Map<String, Object?>?) ?? <String, Object?>{},
    );
    final inputContract = LinkedHashMap<String, Object?>.from(
      (map.remove('input_contract') as Map<String, Object?>?) ??
          <String, Object?>{},
    );
    final outputContract = LinkedHashMap<String, Object?>.from(
      (map.remove('output_contract') as Map<String, Object?>?) ??
          <String, Object?>{},
    );
    final transitions = LinkedHashMap<String, Object?>.from(
      (map.remove('transitions') as Map<String, Object?>?) ??
          <String, Object?>{},
    );
    final prompt = LinkedHashMap<String, Object?>.from(
      (map.remove('prompt') as Map<String, Object?>?) ?? <String, Object?>{},
    );
    final checkPolicy = LinkedHashMap<String, Object?>.from(
      (map.remove('check_policy') as Map<String, Object?>?) ??
          (map.remove('gate_policy') as Map<String, Object?>?) ??
          <String, Object?>{},
    );
    final policyGate = LinkedHashMap<String, Object?>.from(
      (map.remove('rules') as Map<String, Object?>?) ??
          (map.remove('policy_check') as Map<String, Object?>?) ??
          (map.remove('policy_gate') as Map<String, Object?>?) ??
          <String, Object?>{},
    );
    final completion = LinkedHashMap<String, Object?>.from(
      (map.remove('completion_contract') as Map<String, Object?>?) ??
          <String, Object?>{},
    );
    final inputMappings =
        ((map.remove('input_mappings') as List<Object?>?) ?? const <Object?>[])
            .whereType<Map<String, Object?>>()
            .map(_WorkflowInputMappingDraft.fromYaml)
            .toList();

    final runsValue = _stringValue(map.remove('runs'));
    final legacyUsesValue = _stringValue(map.remove('uses'));
    final requiresChecksValue = _stringList(map.remove('requires_checks'));
    final legacyRequiresGatesValue = _stringList(map.remove('requires_gates'));

    return _WorkflowNodeDraft(
      localKey: localKey,
      id: _stringValue(map.remove('id')),
      kind: _normalizeWorkflowKind(_stringValue(map.remove('kind'))),
      uses: runsValue.isNotEmpty ? runsValue : legacyUsesValue,
      withValues: withValues,
      requiredInputKeys: _stringList(inputContract.remove('required_keys')),
      optionalInputKeys: _stringList(inputContract.remove('optional_keys')),
      requiredDataKeys: _stringList(
        outputContract.remove('required_data_keys'),
      ),
      producesGateDecision:
          _boolValue(outputContract.remove('produces_check_decision'))
          ? true
          : _boolValue(outputContract.remove('produces_gate_decision')),
      transitions: _WorkflowTransitionsDraft.fromYaml(transitions),
      maxVisits: _intValue(map.remove('max_visits')),
      maxFailures: _intValue(map.remove('max_failures')),
      implementation: _boolValue(map.remove('implementation')),
      requiresGates: requiresChecksValue.isNotEmpty
          ? requiresChecksValue
          : legacyRequiresGatesValue,
      includeNodeResults: _stringList(map.remove('include_node_results')),
      inputMappings: inputMappings,
      promptInstructions: _stringList(prompt.remove('instructions')),
      gatePassStatuses: _stringList(checkPolicy.remove('pass_statuses')),
      gateFailStatuses: _stringList(checkPolicy.remove('fail_statuses')),
      gatePassExitCodes: _intList(checkPolicy.remove('pass_exit_codes')),
      gateFailExitCodes: _intList(checkPolicy.remove('fail_exit_codes')),
      treatRetryableAsFail: _boolValue(
        checkPolicy.remove('treat_retryable_as_fail'),
      ),
      policyGateEnabled: _boolValue(policyGate.remove('enabled')),
      policyGateRuleSet: _stringValue(policyGate.remove('rule_set')),
      policyGateSessionRuleFiles: _stringList(
        policyGate.remove('session_rule_files'),
      ),
      policyGateMaxCycle: _intValue(policyGate.remove('max_cycle')),
      policyGateReturnEvalErrors: _nullableBoolValue(
        policyGate.remove('return_error_on_failed_rule_evaluation'),
      ),
      policyGateFailClosed: _nullableBoolValue(policyGate.remove('fail_closed')),
      policyGateFactBindings:
          ((policyGate.remove('fact_bindings') as List<Object?>?) ??
                  const <Object?>[])
              .whereType<Map<String, Object?>>()
              .map(_PolicyFactBindingDraft.fromYaml)
              .toList(),
      allowedRouteHints: _stringMap(policyGate.remove('allowed_route_hints')),
      policyGateOnEvaluationError: _stringValue(
        policyGate.remove('on_evaluation_error'),
      ),
      policyGateMergeFindings: _stringValue(
        policyGate.remove('merge_findings'),
      ),
      policyGateOverrideGateStatus: _boolValue(
        policyGate.remove('override_gate_status'),
      ),
      requiredChangedFiles: _stringList(
        completion.remove('required_changed_files'),
      ),
      requiredToolCalls: _stringList(completion.remove('required_tool_calls')),
      extraFields: map,
    );
  }

  factory _WorkflowNodeDraft.fromSummary({
    required String localKey,
    required HarnessWorkflowNodeSummary summary,
  }) {
    return _WorkflowNodeDraft(
      localKey: localKey,
      id: summary.id,
      kind: _normalizeWorkflowKind(summary.kind),
      uses: summary.uses,
      withValues: <String, Object?>{
        for (final key in summary.withKeys) key: '',
      },
      requiredInputKeys: summary.requiredInputKeys,
      optionalInputKeys: summary.optionalInputKeys,
      requiredDataKeys: summary.requiredDataKeys,
      producesGateDecision: summary.producesGateDecision,
      transitions: _WorkflowTransitionsDraft(
        success: summary.transitions.success,
        failure: summary.transitions.failure,
        blocked: summary.transitions.blocked,
      ),
      maxVisits: summary.maxVisits,
      maxFailures: summary.maxFailures,
      implementation: summary.implementation,
      requiresGates: summary.requiresGates,
      includeNodeResults: summary.includeNodeResults,
      inputMappings: summary.inputMappings
          .map(
            (HarnessWorkflowInputMapSummary mapping) =>
                _WorkflowInputMappingDraft(
                  fromNode: mapping.fromNode,
                  outputKey: mapping.outputKey,
                  inputKey: mapping.inputKey,
                  required: mapping.required,
                  overwrite: mapping.overwrite,
                ),
          )
          .toList(),
      promptInstructions: const <String>[],
      gatePassStatuses: summary.gatePassStatuses,
      gateFailStatuses: summary.gateFailStatuses,
      gatePassExitCodes: summary.gatePassExitCodes,
      gateFailExitCodes: summary.gateFailExitCodes,
      treatRetryableAsFail: summary.treatRetryableAsFail,
      policyGateEnabled: summary.policyGateEnabled,
      policyGateRuleSet: summary.policyGateRuleSet,
      policyGateMaxCycle: summary.policyGateMaxCycle,
      policyGateReturnEvalErrors: summary.policyGateReturnEvalErrors,
      policyGateFailClosed: summary.policyGateFailClosed,
      policyGateFactBindings: const <_PolicyFactBindingDraft>[],
      allowedRouteHints: <String, String>{
        for (final hint in summary.policyGateRouteHints) hint: '',
      },
      policyGateOnEvaluationError: summary.policyGateOnEvalError,
      policyGateMergeFindings: summary.policyGateMergeFindings,
      policyGateOverrideGateStatus: summary.policyGateOverrideStatus,
      requiredChangedFiles: summary.requiredChangedFiles,
      requiredToolCalls: summary.requiredToolCalls,
    );
  }

  final String localKey;
  String id;
  String kind;
  String uses;
  Map<String, Object?> withValues;
  List<String> requiredInputKeys;
  List<String> optionalInputKeys;
  List<String> requiredDataKeys;
  bool producesGateDecision;
  _WorkflowTransitionsDraft transitions;
  int maxVisits;
  int maxFailures;
  bool implementation;
  List<String> requiresGates;
  List<String> includeNodeResults;
  List<_WorkflowInputMappingDraft> inputMappings;
  List<String> promptInstructions;
  List<String> gatePassStatuses;
  List<String> gateFailStatuses;
  List<int> gatePassExitCodes;
  List<int> gateFailExitCodes;
  bool treatRetryableAsFail;
  bool policyGateEnabled;
  String policyGateRuleSet;
  List<String> policyGateSessionRuleFiles;
  int policyGateMaxCycle;
  bool? policyGateReturnEvalErrors;
  bool? policyGateFailClosed;
  List<_PolicyFactBindingDraft> policyGateFactBindings;
  Map<String, String> allowedRouteHints;
  String policyGateOnEvaluationError;
  String policyGateMergeFindings;
  bool policyGateOverrideGateStatus;
  List<String> requiredChangedFiles;
  List<String> requiredToolCalls;
  Map<String, Object?> extraFields;

  Map<String, Object?> toYamlMap() {
    final map = <String, Object?>{}
      ..['id'] = id
      ..['kind'] = _normalizeWorkflowKind(kind)
      ..addAll(extraFields);
    if (uses.isNotEmpty) {
      map['runs'] = uses;
    } else {
      map.remove('runs');
    }
    if (withValues.isNotEmpty) {
      map['with'] = withValues;
    } else {
      map.remove('with');
    }
    final inputContract = <String, Object?>{};
    if (requiredInputKeys.isNotEmpty) {
      inputContract['required_keys'] = requiredInputKeys;
    }
    if (optionalInputKeys.isNotEmpty) {
      inputContract['optional_keys'] = optionalInputKeys;
    }
    if (inputContract.isNotEmpty) {
      map['input_contract'] = inputContract;
    } else {
      map.remove('input_contract');
    }
    final outputContract = <String, Object?>{};
    if (requiredDataKeys.isNotEmpty) {
      outputContract['required_data_keys'] = requiredDataKeys;
    }
    if (producesGateDecision) {
      outputContract['produces_check_decision'] = true;
    }
    if (outputContract.isNotEmpty) {
      map['output_contract'] = outputContract;
    } else {
      map.remove('output_contract');
    }
    final transitionMap = transitions.toYamlMap();
    if (transitionMap.isNotEmpty) {
      map['transitions'] = transitionMap;
    } else {
      map.remove('transitions');
    }
    if (maxVisits > 0) {
      map['max_visits'] = maxVisits;
    } else {
      map.remove('max_visits');
    }
    if (maxFailures > 0) {
      map['max_failures'] = maxFailures;
    } else {
      map.remove('max_failures');
    }
    if (implementation) {
      map['implementation'] = true;
    } else {
      map.remove('implementation');
    }
    if (requiresGates.isNotEmpty) {
      map['requires_checks'] = requiresGates;
    } else {
      map.remove('requires_checks');
    }
    if (includeNodeResults.isNotEmpty) {
      map['include_node_results'] = includeNodeResults;
    } else {
      map.remove('include_node_results');
    }
    if (inputMappings.isNotEmpty) {
      map['input_mappings'] = inputMappings
          .map((_WorkflowInputMappingDraft value) => value.toYamlMap())
          .toList();
    } else {
      map.remove('input_mappings');
    }
    if (promptInstructions.isNotEmpty) {
      map['prompt'] = <String, Object?>{'instructions': promptInstructions};
    } else {
      map.remove('prompt');
    }
    final gatePolicy = <String, Object?>{};
    if (gatePassStatuses.isNotEmpty) {
      gatePolicy['pass_statuses'] = gatePassStatuses;
    }
    if (gateFailStatuses.isNotEmpty) {
      gatePolicy['fail_statuses'] = gateFailStatuses;
    }
    if (gatePassExitCodes.isNotEmpty) {
      gatePolicy['pass_exit_codes'] = gatePassExitCodes;
    }
    if (gateFailExitCodes.isNotEmpty) {
      gatePolicy['fail_exit_codes'] = gateFailExitCodes;
    }
    if (treatRetryableAsFail) {
      gatePolicy['treat_retryable_as_fail'] = true;
    }
    if (gatePolicy.isNotEmpty) {
      map['check_policy'] = gatePolicy;
    } else {
      map.remove('check_policy');
    }
    final policyGate = <String, Object?>{};
    if (policyGateEnabled) {
      policyGate['enabled'] = true;
    }
    if (policyGateRuleSet.isNotEmpty) {
      policyGate['rule_set'] = policyGateRuleSet;
    }
    if (policyGateSessionRuleFiles.isNotEmpty) {
      policyGate['session_rule_files'] = policyGateSessionRuleFiles;
    }
    if (policyGateMaxCycle > 0) {
      policyGate['max_cycle'] = policyGateMaxCycle;
    }
    if (policyGateReturnEvalErrors != null) {
      policyGate['return_error_on_failed_rule_evaluation'] =
          policyGateReturnEvalErrors;
    }
    if (policyGateFailClosed != null) {
      policyGate['fail_closed'] = policyGateFailClosed;
    }
    if (policyGateFactBindings.isNotEmpty) {
      policyGate['fact_bindings'] = policyGateFactBindings
          .map((_PolicyFactBindingDraft value) => value.toYamlMap())
          .toList();
    }
    if (allowedRouteHints.isNotEmpty) {
      policyGate['allowed_route_hints'] = allowedRouteHints;
    }
    if (policyGateOnEvaluationError.isNotEmpty) {
      policyGate['on_evaluation_error'] = policyGateOnEvaluationError;
    }
    if (policyGateMergeFindings.isNotEmpty) {
      policyGate['merge_findings'] = policyGateMergeFindings;
    }
    if (policyGateOverrideGateStatus) {
      policyGate['override_gate_status'] = true;
    }
    if (policyGate.isNotEmpty) {
      map['rules'] = policyGate;
    } else {
      map.remove('rules');
    }
    final completion = <String, Object?>{};
    if (requiredChangedFiles.isNotEmpty) {
      completion['required_changed_files'] = requiredChangedFiles;
    }
    if (requiredToolCalls.isNotEmpty) {
      completion['required_tool_calls'] = requiredToolCalls;
    }
    if (completion.isNotEmpty) {
      map['completion_contract'] = completion;
    } else {
      map.remove('completion_contract');
    }
    return map;
  }
}

class _WorkflowRuleDraft {
  _WorkflowRuleDraft({
    required this.name,
    this.file = '',
    Map<String, Object?>? extraFields,
  }) : extraFields = extraFields ?? <String, Object?>{};

  factory _WorkflowRuleDraft.fromYaml(Map<String, Object?> raw) {
    final map = LinkedHashMap<String, Object?>.from(raw);
    return _WorkflowRuleDraft(
      name: _stringValue(map.remove('name')),
      file: _stringValue(map.remove('file')),
      extraFields: map,
    );
  }

  String name;
  String file;
  Map<String, Object?> extraFields;

  Map<String, Object?> toYamlMap() {
    final map = <String, Object?>{}..addAll(extraFields);
    if (name.isNotEmpty) {
      map['name'] = name;
    } else {
      map.remove('name');
    }
    if (file.isNotEmpty) {
      map['file'] = file;
    } else {
      map.remove('file');
    }
    return map;
  }
}

class _WorkflowRuleSetDraft {
  _WorkflowRuleSetDraft({
    required this.name,
    List<String>? rules,
    this.maxCycle = 0,
    this.returnErrorOnFailedRuleEvaluation,
    this.failClosed,
    Map<String, Object?>? extraFields,
  }) : rules = rules ?? <String>[],
       extraFields = extraFields ?? <String, Object?>{};

  factory _WorkflowRuleSetDraft.fromYaml(Map<String, Object?> raw) {
    final map = LinkedHashMap<String, Object?>.from(raw);
    return _WorkflowRuleSetDraft(
      name: _stringValue(map.remove('name')),
      rules: _stringList(map.remove('rules')),
      maxCycle: _intValue(map.remove('max_cycle')),
      returnErrorOnFailedRuleEvaluation: _nullableBoolValue(
        map.remove('return_error_on_failed_rule_evaluation'),
      ),
      failClosed: _nullableBoolValue(map.remove('fail_closed')),
      extraFields: map,
    );
  }

  String name;
  List<String> rules;
  int maxCycle;
  bool? returnErrorOnFailedRuleEvaluation;
  bool? failClosed;
  Map<String, Object?> extraFields;

  Map<String, Object?> toYamlMap() {
    final map = <String, Object?>{}..addAll(extraFields);
    if (name.isNotEmpty) {
      map['name'] = name;
    } else {
      map.remove('name');
    }
    if (rules.isNotEmpty) {
      map['rules'] = rules;
    } else {
      map.remove('rules');
    }
    if (maxCycle > 0) {
      map['max_cycle'] = maxCycle;
    } else {
      map.remove('max_cycle');
    }
    if (returnErrorOnFailedRuleEvaluation != null) {
      map['return_error_on_failed_rule_evaluation'] =
          returnErrorOnFailedRuleEvaluation;
    } else {
      map.remove('return_error_on_failed_rule_evaluation');
    }
    if (failClosed != null) {
      map['fail_closed'] = failClosed;
    } else {
      map.remove('fail_closed');
    }
    return map;
  }
}

class _WorkflowTransitionsDraft {
  _WorkflowTransitionsDraft({
    this.success = '',
    this.failure = '',
    this.blocked = '',
  });

  factory _WorkflowTransitionsDraft.fromYaml(Map<String, Object?> map) {
    return _WorkflowTransitionsDraft(
      success: _stringValue(map['success']),
      failure: _stringValue(map['failure']),
      blocked: _stringValue(map['blocked']),
    );
  }

  String success;
  String failure;
  String blocked;

  Map<String, Object?> toYamlMap() {
    final map = <String, Object?>{};
    if (success.isNotEmpty) {
      map['success'] = success;
    }
    if (failure.isNotEmpty) {
      map['failure'] = failure;
    }
    if (blocked.isNotEmpty) {
      map['blocked'] = blocked;
    }
    return map;
  }

  List<MapEntry<String, String>> targets() {
    return <MapEntry<String, String>>[
      if (success.isNotEmpty) MapEntry<String, String>('success', success),
      if (failure.isNotEmpty) MapEntry<String, String>('failure', failure),
      if (blocked.isNotEmpty) MapEntry<String, String>('blocked', blocked),
    ];
  }
}

class _WorkflowInputMappingDraft {
  const _WorkflowInputMappingDraft({
    required this.fromNode,
    required this.outputKey,
    required this.inputKey,
    required this.required,
    required this.overwrite,
  });

  factory _WorkflowInputMappingDraft.fromYaml(Map<String, Object?> map) {
    return _WorkflowInputMappingDraft(
      fromNode: _stringValue(map['from_node']),
      outputKey: _stringValue(map['output_key']),
      inputKey: _stringValue(map['input_key']),
      required: _boolValue(map['required']),
      overwrite: _boolValue(map['overwrite']),
    );
  }

  final String fromNode;
  final String outputKey;
  final String inputKey;
  final bool required;
  final bool overwrite;

  _WorkflowInputMappingDraft copyWith({
    String? fromNode,
    String? outputKey,
    String? inputKey,
    bool? required,
    bool? overwrite,
  }) {
    return _WorkflowInputMappingDraft(
      fromNode: fromNode ?? this.fromNode,
      outputKey: outputKey ?? this.outputKey,
      inputKey: inputKey ?? this.inputKey,
      required: required ?? this.required,
      overwrite: overwrite ?? this.overwrite,
    );
  }

  Map<String, Object?> toYamlMap() {
    return <String, Object?>{
      if (fromNode.isNotEmpty) 'from_node': fromNode,
      if (outputKey.isNotEmpty) 'output_key': outputKey,
      if (inputKey.isNotEmpty) 'input_key': inputKey,
      if (required) 'required': true,
      if (overwrite) 'overwrite': true,
    };
  }
}

class _PolicyFactBindingDraft {
  _PolicyFactBindingDraft({
    required this.name,
    required this.source,
    required this.node,
    required this.path,
    required this.required,
    Map<String, Object?>? extraFields,
  }) : extraFields = extraFields ?? <String, Object?>{};

  factory _PolicyFactBindingDraft.fromYaml(Map<String, Object?> map) {
    final mutable = LinkedHashMap<String, Object?>.from(map);
    return _PolicyFactBindingDraft(
      name: _stringValue(mutable.remove('name')),
      source: _stringValue(mutable.remove('source')),
      node: _stringValue(mutable.remove('node')),
      path: _stringValue(mutable.remove('path')),
      required: _boolValue(mutable.remove('required')),
      extraFields: mutable,
    );
  }

  final String name;
  final String source;
  final String node;
  final String path;
  final bool required;
  final Map<String, Object?> extraFields;

  _PolicyFactBindingDraft copyWith({
    String? name,
    String? source,
    String? node,
    String? path,
    bool? required,
    Map<String, Object?>? extraFields,
  }) {
    return _PolicyFactBindingDraft(
      name: name ?? this.name,
      source: source ?? this.source,
      node: node ?? this.node,
      path: path ?? this.path,
      required: required ?? this.required,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  Map<String, Object?> toYamlMap() {
    return <String, Object?>{
      ...extraFields,
      if (name.isNotEmpty) 'name': name,
      if (source.isNotEmpty) 'source': source,
      if (node.isNotEmpty) 'node': node,
      if (path.isNotEmpty) 'path': path,
      if (required) 'required': true,
    };
  }
}

class _MiniYamlParser {
  _MiniYamlParser(String source)
    : _lines = source.split('\n').asMap().entries.map((
        MapEntry<int, String> entry,
      ) {
        final raw = entry.value.replaceAll('\r', '');
        return _MiniYamlLine(
          number: entry.key + 1,
          raw: raw,
          indent: raw.length - raw.trimLeft().length,
        );
      }).toList();

  final List<_MiniYamlLine> _lines;
  int _index = 0;

  Object? parseDocument() {
    final line = _peekMeaningful();
    if (line == null) {
      return <String, Object?>{};
    }
    return _parseBlock(line.indent);
  }

  Object? _parseBlock(int indent) {
    final line = _peekMeaningful();
    if (line == null) {
      return null;
    }
    final content = _cleanLine(line.raw.substring(line.indent));
    if (content.startsWith('- ')) {
      return _parseList(indent);
    }
    return _parseMap(indent);
  }

  Map<String, Object?> _parseMap(int indent) {
    final map = <String, Object?>{};
    while (true) {
      final line = _peekMeaningful();
      if (line == null || line.indent < indent) {
        break;
      }
      if (line.indent > indent) {
        throw _MiniYamlException(
          'Unexpected indentation at line ${line.number}.',
        );
      }
      final content = _cleanLine(line.raw.substring(line.indent));
      if (content.startsWith('- ')) {
        break;
      }
      final colonIndex = _topLevelColonIndex(content);
      if (colonIndex < 0) {
        throw _MiniYamlException(
          'Expected `key: value` at line ${line.number}.',
        );
      }
      final key = content.substring(0, colonIndex).trim();
      final remainder = content.substring(colonIndex + 1).trim();
      _index += 1;
      map[key] = _parseValueAfterKey(
        parentIndent: indent,
        remainder: remainder,
      );
    }
    return map;
  }

  List<Object?> _parseList(int indent) {
    final list = <Object?>[];
    while (true) {
      final line = _peekMeaningful();
      if (line == null || line.indent < indent) {
        break;
      }
      if (line.indent > indent) {
        throw _MiniYamlException(
          'Unexpected indentation at line ${line.number}.',
        );
      }
      final content = _cleanLine(line.raw.substring(line.indent));
      if (!content.startsWith('- ')) {
        break;
      }
      final remainder = content.substring(2).trim();
      _index += 1;
      if (remainder.isEmpty) {
        final next = _peekMeaningful();
        if (next != null && next.indent > indent) {
          list.add(_parseBlock(next.indent));
        } else {
          list.add(null);
        }
        continue;
      }
      if (_looksLikeMapEntry(remainder)) {
        final colonIndex = _topLevelColonIndex(remainder);
        final key = remainder.substring(0, colonIndex).trim();
        final tail = remainder.substring(colonIndex + 1).trim();
        final map = <String, Object?>{};
        map[key] = _parseValueAfterKey(
          parentIndent: indent + 2,
          remainder: tail,
        );
        while (true) {
          final next = _peekMeaningful();
          if (next == null || next.indent < indent + 2) {
            break;
          }
          if (next.indent == indent &&
              _cleanLine(next.raw.substring(next.indent)).startsWith('- ')) {
            break;
          }
          if (next.indent != indent + 2) {
            throw _MiniYamlException(
              'Unexpected indentation at line ${next.number}.',
            );
          }
          final nextContent = _cleanLine(next.raw.substring(next.indent));
          final nextColon = _topLevelColonIndex(nextContent);
          if (nextColon < 0) {
            throw _MiniYamlException(
              'Expected `key: value` at line ${next.number}.',
            );
          }
          final nextKey = nextContent.substring(0, nextColon).trim();
          final nextRemainder = nextContent.substring(nextColon + 1).trim();
          _index += 1;
          map[nextKey] = _parseValueAfterKey(
            parentIndent: indent + 2,
            remainder: nextRemainder,
          );
        }
        list.add(map);
        continue;
      }
      list.add(_parseScalar(remainder));
    }
    return list;
  }

  Object? _parseValueAfterKey({
    required int parentIndent,
    required String remainder,
  }) {
    if (remainder == '|') {
      return _parseBlockScalar(parentIndent);
    }
    if (remainder.isNotEmpty) {
      return _parseScalar(remainder);
    }
    final next = _peekMeaningful();
    if (next != null && next.indent > parentIndent) {
      return _parseBlock(next.indent);
    }
    return null;
  }

  String _parseBlockScalar(int parentIndent) {
    final lines = <String>[];
    int? blockIndent;
    while (_index < _lines.length) {
      final line = _lines[_index];
      if (blockIndent == null) {
        if (line.raw.trim().isEmpty) {
          lines.add('');
          _index += 1;
          continue;
        }
        if (line.indent <= parentIndent) {
          break;
        }
        blockIndent = line.indent;
      }
      if (line.raw.trim().isNotEmpty && line.indent < blockIndent) {
        break;
      }
      if (line.raw.trim().isEmpty) {
        lines.add('');
      } else if (line.raw.length >= blockIndent) {
        lines.add(line.raw.substring(blockIndent));
      } else {
        lines.add('');
      }
      _index += 1;
    }
    return lines.join('\n');
  }

  Object? _parseScalar(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed == '[]') {
      return <Object?>[];
    }
    if (trimmed == '{}') {
      return <String, Object?>{};
    }
    if (trimmed == 'true') {
      return true;
    }
    if (trimmed == 'false') {
      return false;
    }
    if (trimmed == 'null') {
      return null;
    }
    final intValue = int.tryParse(trimmed);
    if (intValue != null) {
      return intValue;
    }
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      return _parseInlineList(trimmed);
    }
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      return _unquote(trimmed);
    }
    return trimmed;
  }

  List<Object?> _parseInlineList(String text) {
    final inner = text.substring(1, text.length - 1).trim();
    if (inner.isEmpty) {
      return <Object?>[];
    }
    final items = <Object?>[];
    final buffer = StringBuffer();
    String? quote;
    for (int index = 0; index < inner.length; index++) {
      final char = inner[index];
      if ((char == '"' || char == "'") &&
          (index == 0 || inner[index - 1] != '\\')) {
        if (quote == null) {
          quote = char;
        } else if (quote == char) {
          quote = null;
        }
        buffer.write(char);
        continue;
      }
      if (char == ',' && quote == null) {
        items.add(_parseScalar(buffer.toString()));
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    if (buffer.isNotEmpty) {
      items.add(_parseScalar(buffer.toString()));
    }
    return items;
  }

  _MiniYamlLine? _peekMeaningful() {
    while (_index < _lines.length) {
      final line = _lines[_index];
      final cleaned = _cleanLine(line.raw.trimLeft());
      if (cleaned.isEmpty) {
        _index += 1;
        continue;
      }
      return line;
    }
    return null;
  }
}

class _MiniYamlLine {
  const _MiniYamlLine({
    required this.number,
    required this.raw,
    required this.indent,
  });

  final int number;
  final String raw;
  final int indent;
}

class _MiniYamlWriter {
  static String serialize(Object? value) {
    final lines = <String>[];
    _writeValue(lines, value, 0);
    return lines.join('\n').trimRight();
  }

  static void _writeValue(List<String> lines, Object? value, int indent) {
    if (value is Map<String, Object?>) {
      if (value.isEmpty) {
        lines.add('${_spaces(indent)}{}');
        return;
      }
      for (final entry in value.entries) {
        _writeMapEntry(lines, indent, entry.key, entry.value);
      }
      return;
    }
    if (value is List<Object?>) {
      if (value.isEmpty) {
        lines.add('${_spaces(indent)}[]');
        return;
      }
      for (final item in value) {
        _writeListEntry(lines, indent, item);
      }
      return;
    }
    lines.add('${_spaces(indent)}${_renderScalar(value)}');
  }

  static void _writeMapEntry(
    List<String> lines,
    int indent,
    String key,
    Object? value,
  ) {
    final prefix = '${_spaces(indent)}$key:';
    if (_isInlineScalar(value)) {
      lines.add('$prefix ${_renderScalar(value)}');
      return;
    }
    if (value is String && value.contains('\n')) {
      lines.add('$prefix |');
      for (final line in value.split('\n')) {
        lines.add('${_spaces(indent + 2)}$line');
      }
      return;
    }
    if (value is Map<String, Object?> && value.isEmpty) {
      lines.add('$prefix {}');
      return;
    }
    if (value is List<Object?> && value.isEmpty) {
      lines.add('$prefix []');
      return;
    }
    lines.add(prefix);
    _writeValue(lines, value, indent + 2);
  }

  static void _writeListEntry(List<String> lines, int indent, Object? value) {
    final prefix = '${_spaces(indent)}-';
    if (_isInlineScalar(value)) {
      lines.add('$prefix ${_renderScalar(value)}');
      return;
    }
    if (value is String && value.contains('\n')) {
      lines.add('$prefix |');
      for (final line in value.split('\n')) {
        lines.add('${_spaces(indent + 2)}$line');
      }
      return;
    }
    if (value is Map<String, Object?> && value.isNotEmpty) {
      final entries = value.entries.toList();
      _writeMapEntry(lines, indent, entries.first.key, entries.first.value);
      final firstLine = lines.removeLast();
      lines.add(
        firstLine.replaceFirst(
          '${_spaces(indent)}${entries.first.key}:',
          '$prefix ${entries.first.key}:',
        ),
      );
      for (final entry in entries.skip(1)) {
        _writeMapEntry(lines, indent + 2, entry.key, entry.value);
      }
      return;
    }
    if (value is Map<String, Object?> && value.isEmpty) {
      lines.add('$prefix {}');
      return;
    }
    if (value is List<Object?> && value.isEmpty) {
      lines.add('$prefix []');
      return;
    }
    lines.add(prefix);
    _writeValue(lines, value, indent + 2);
  }
}

class _MiniYamlException implements Exception {
  const _MiniYamlException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _parseYamlMapFragment(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return <String, Object?>{};
  }
  final document = _MiniYamlParser(trimmed).parseDocument();
  if (document is! Map<String, Object?>) {
    throw const _MiniYamlException('Expected a YAML map.');
  }
  return document;
}

List<Object?> _parseYamlListFragment(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return <Object?>[];
  }
  final document = _MiniYamlParser(trimmed).parseDocument();
  if (document is! List<Object?>) {
    throw const _MiniYamlException('Expected a YAML list.');
  }
  return document;
}

String _cleanLine(String value) {
  final buffer = StringBuffer();
  String? quote;
  for (int index = 0; index < value.length; index++) {
    final char = value[index];
    if ((char == '"' || char == "'") &&
        (index == 0 || value[index - 1] != '\\')) {
      if (quote == null) {
        quote = char;
      } else if (quote == char) {
        quote = null;
      }
      buffer.write(char);
      continue;
    }
    if (char == '#' && quote == null) {
      break;
    }
    buffer.write(char);
  }
  return buffer.toString().trimRight();
}

int _topLevelColonIndex(String text) {
  String? quote;
  for (int index = 0; index < text.length; index++) {
    final char = text[index];
    if ((char == '"' || char == "'") &&
        (index == 0 || text[index - 1] != '\\')) {
      if (quote == null) {
        quote = char;
      } else if (quote == char) {
        quote = null;
      }
      continue;
    }
    if (char == ':' && quote == null) {
      return index;
    }
  }
  return -1;
}

bool _looksLikeMapEntry(String text) => _topLevelColonIndex(text) > 0;

String _unquote(String value) {
  final quote = value.substring(0, 1);
  final inner = value.substring(1, value.length - 1);
  if (quote == '"') {
    return inner
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\\', r'\');
  }
  return inner.replaceAll(r"\'", "'");
}

bool _isInlineScalar(Object? value) =>
    value == null ||
    value is bool ||
    value is num ||
    (value is String && !value.contains('\n'));

String _renderScalar(Object? value) {
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

String _spaces(int count) => ' ' * count;

String _joinInline(List<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' • ');
}

String _withTextValue(_WorkflowNodeDraft node, String key) {
  final value = node.withValues[key];
  return value is String ? value : '';
}

void _setWithTextValue(_WorkflowNodeDraft node, String key, String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    node.withValues.remove(key);
    return;
  }
  node.withValues[key] = trimmed;
}

List<String> _splitLines(String value) {
  return value
      .split(RegExp(r'[\n,]'))
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}

List<int> _splitInts(String value) {
  return value
      .split(RegExp(r'[\n,]'))
      .map((String item) => int.tryParse(item.trim()))
      .whereType<int>()
      .toList();
}

List<String> _transitionOptionsFor(
  List<String> nodeIds,
  String currentNodeId,
  String currentTarget,
) {
  final options = nodeIds.where((String id) => id != currentNodeId).toList();
  if (currentTarget.isNotEmpty && currentTarget == currentNodeId) {
    options.add(currentTarget);
  }
  return LinkedHashSet<String>.from(options).toList();
}

String _slugify(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toLowerCase();
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

int _parseInt(String value) => int.tryParse(value.trim()) ?? 0;

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  return value?.toString().trim().toLowerCase() == 'true';
}

bool? _nullableBoolValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  final normalized = value.toString().trim().toLowerCase();
  switch (normalized) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      return null;
  }
}

String? _nullableBoolChoice(bool? value) {
  if (value == null) {
    return null;
  }
  return value ? 'enabled' : 'disabled';
}

bool? _nullableBoolChoiceValue(String? value) {
  switch (value?.trim()) {
    case 'enabled':
      return true;
    case 'disabled':
      return false;
    default:
      return null;
  }
}

List<String> _stringList(Object? value) {
  return (value as List<Object?>? ?? const <Object?>[])
      .map((Object? value) => _stringValue(value))
      .where((String value) => value.isNotEmpty)
      .toList();
}

List<int> _intList(Object? value) {
  return (value as List<Object?>? ?? const <Object?>[])
      .map((Object? value) => _intValue(value))
      .where((int value) => value != 0)
      .toList();
}

Map<String, String> _stringMap(Object? value) {
  return LinkedHashMap<String, String>.from(
    (value as Map<String, Object?>? ?? const <String, Object?>{}).map(
      (String key, Object? value) => MapEntry(key.trim(), _stringValue(value)),
    ),
  )..removeWhere((String key, String value) => key.isEmpty || value.isEmpty);
}

String _intText(int value) => value == 0 ? '' : '$value';

String _normalizeWorkflowKind(String kind) {
  final normalized = kind.trim().toLowerCase();
  if (normalized == 'gate') {
    return 'check';
  }
  return normalized;
}

Color _nodeKindColor(String kind) {
  switch (_normalizeWorkflowKind(kind)) {
    case 'check':
      return warningColor;
    case 'finish':
      return successColor;
    default:
      return infoColor;
  }
}

Color _edgeColor(String label) {
  switch (label) {
    case 'success':
      return successColor;
    case 'blocked':
      return warningColor;
    case 'failure':
    default:
      return dangerColor;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
