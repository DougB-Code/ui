import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ui/harness_config/harness_config_api.dart';
import 'package:ui/shared/side_panel.dart';
import 'package:ui/shared/ui.dart';
import 'package:ui/shared/workspace_shell.dart';

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
      _WorkflowInspectorPanel.rules => 'Rules',
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
  _WorkflowCollectionSection _collectionSection =
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
              configPath: widget.catalog.configPath,
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
        return _buildInspectorPanelContent(
          summaryCard: _buildWorkflowInspectorSummaryCard(workflow),
          searchQuery: searchQuery,
          emptyTitle: 'No matching workflow rules',
          emptyBody:
              'Try a different search term to find reusable rule set controls.',
          blocks: <_InspectorPanelBlock>[
            _InspectorPanelBlock(
              title: 'Reusable rules',
              searchTerms: const <String>[
                'rule sets',
                'embedded rules',
                'policy',
                'knowledge base',
              ],
              child: _InspectorSection(
                title: 'Reusable rules',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (workflow.rawRuleSets.isEmpty)
                      const InfoPanel(
                        title: 'No reusable rules yet',
                        body:
                            'Add shared rule set definitions here, or open the full source drawer when you need advanced shapes.',
                      ),
                    if (workflow.rawRuleSets.isNotEmpty) ...[
                      for (
                        int index = 0;
                        index < workflow.rawRuleSets.length;
                        index++
                      )
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == workflow.rawRuleSets.length - 1
                                ? 0
                                : 10,
                          ),
                          child: _InspectorListCard(
                            title: _stringValue(
                              (workflow.rawRuleSets[index]
                                  as Map<String, Object?>?)?['name'],
                            ),
                            subtitle: _joinMultiline(<String>[
                              _stringValue(
                                (workflow.rawRuleSets[index]
                                    as Map<String, Object?>?)?['source_kind'],
                              ),
                              _stringValue(
                                (workflow.rawRuleSets[index]
                                    as Map<String, Object?>?)?['base_path'],
                              ),
                            ]),
                            tone: successColor,
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    _InspectorYamlEditor(
                      key: ValueKey(_fieldKey(workflowKey, 'rule_sets')),
                      label: 'Rule sets',
                      helperText:
                          'Edit the workflow rule_sets list directly when you need full access to embedded rules or source metadata.',
                      initialValue: _MiniYamlWriter.serialize(
                        workflow.rawRuleSets,
                      ),
                      errorText: _fieldError(
                        _fieldKey(workflowKey, 'rule_sets'),
                      ),
                      onChanged: (String value) {
                        try {
                          final parsed = _parseYamlListFragment(value);
                          _updateFieldError(
                            _fieldKey(workflowKey, 'rule_sets'),
                            null,
                          );
                          _updateWorkflow((_WorkflowDraft target) {
                            target.rawRuleSets = parsed;
                          });
                        } on _MiniYamlException catch (error) {
                          _updateFieldError(
                            _fieldKey(workflowKey, 'rule_sets'),
                            error.message,
                          );
                        }
                      },
                    ),
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
    final runTargetOptions = LinkedHashSet<String>.from(<String>[
      ...widget.runTargetOptions,
      if (node.uses.trim().isNotEmpty) node.uses.trim(),
    ]).toList(growable: false);
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
                  children: [
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
                    _InspectorTextField(
                      key: ValueKey(_fieldKey(nodeKey, 'policy_gate_rule_set')),
                      label: 'Rule set',
                      initialValue: node.policyGateRuleSet,
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateRuleSet = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorTextField(
                      key: ValueKey(_fieldKey(nodeKey, 'policy_gate_on_error')),
                      label: 'On evaluation error',
                      initialValue: node.policyGateOnEvaluationError,
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateOnEvaluationError = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorTextField(
                      key: ValueKey(
                        _fieldKey(nodeKey, 'policy_gate_merge_findings'),
                      ),
                      label: 'Merge findings',
                      initialValue: node.policyGateMergeFindings,
                      onChanged: (String value) {
                        _updateNode((
                          _WorkflowDraft _,
                          _WorkflowNodeDraft targetNode,
                        ) {
                          targetNode.policyGateMergeFindings = value.trim();
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
                    _InspectorYamlEditor(
                      key: ValueKey(
                        _fieldKey(nodeKey, 'policy_gate_fact_bindings'),
                      ),
                      label: 'Fact bindings',
                      helperText:
                          'Expose selected workflow facts to the policy engine.',
                      initialValue: _MiniYamlWriter.serialize(
                        node.policyGateFactBindings
                            .map(
                              (_PolicyFactBindingDraft binding) =>
                                  binding.toYamlMap(),
                            )
                            .toList(),
                      ),
                      errorText: _fieldError(
                        _fieldKey(nodeKey, 'policy_gate_fact_bindings'),
                      ),
                      onChanged: (String value) {
                        try {
                          final parsed = _parseYamlListFragment(value);
                          final bindings = parsed
                              .whereType<Map<String, Object?>>()
                              .map(_PolicyFactBindingDraft.fromYaml)
                              .toList();
                          _updateFieldError(
                            _fieldKey(nodeKey, 'policy_gate_fact_bindings'),
                            null,
                          );
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.policyGateFactBindings = bindings;
                          });
                        } on _MiniYamlException catch (error) {
                          _updateFieldError(
                            _fieldKey(nodeKey, 'policy_gate_fact_bindings'),
                            error.message,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _InspectorYamlEditor(
                      key: ValueKey(
                        _fieldKey(nodeKey, 'policy_gate_allowed_route_hints'),
                      ),
                      label: 'Allowed route hints',
                      helperText:
                          'Allow named policy hints to redirect the workflow to known steps.',
                      initialValue: _MiniYamlWriter.serialize(
                        node.allowedRouteHints,
                      ),
                      errorText: _fieldError(
                        _fieldKey(nodeKey, 'policy_gate_allowed_route_hints'),
                      ),
                      onChanged: (String value) {
                        try {
                          final parsed = _parseYamlMapFragment(value);
                          _updateFieldError(
                            _fieldKey(
                              nodeKey,
                              'policy_gate_allowed_route_hints',
                            ),
                            null,
                          );
                          _updateNode((
                            _WorkflowDraft _,
                            _WorkflowNodeDraft targetNode,
                          ) {
                            targetNode.allowedRouteHints = parsed.map(
                              (String key, Object? value) =>
                                  MapEntry(key, _stringValue(value)),
                            );
                          });
                        } on _MiniYamlException catch (error) {
                          _updateFieldError(
                            _fieldKey(
                              nodeKey,
                              'policy_gate_allowed_route_hints',
                            ),
                            error.message,
                          );
                        }
                      },
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
    return _buildInspectorSummaryCard(
      title: workflow.name,
      subtitle: _joinInline(<String>[
        workflow.startNode.isEmpty
            ? 'No start step configured'
            : 'Start ${workflow.startNode}',
        '${workflow.nodes.length} steps',
        if (workflow.rawRuleSets.isNotEmpty)
          '${workflow.rawRuleSets.length} rule set${workflow.rawRuleSets.length == 1 ? '' : 's'}',
      ]),
      footer: <Widget>[
        StatusPill(
          label:
              '${workflow.nodes.length} step${workflow.nodes.length == 1 ? '' : 's'}',
          color: infoColor,
        ),
        if (workflow.rawRuleSets.isNotEmpty)
          StatusPill(
            label:
                '${workflow.rawRuleSets.length} rule set${workflow.rawRuleSets.length == 1 ? '' : 's'}',
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
    final footer = <Widget>[
      StatusPill(
        label:
            '${workflow.nodes.length} step${workflow.nodes.length == 1 ? '' : 's'}',
        color: infoColor,
      ),
    ];
    if (workflow.rawRuleSets.isNotEmpty) {
      footer.add(
        StatusPill(
          label:
              '${workflow.rawRuleSets.length} rule set${workflow.rawRuleSets.length == 1 ? '' : 's'}',
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
      searchHintText: 'Search workflows, steps, and rule sets...',
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
                    ...node.requiredInputKeys,
                    ...node.requiredDataKeys,
                    ...node.requiresGates,
                    ...node.includeNodeResults,
                    ...node.requiredChangedFiles,
                    ...node.requiredToolCalls,
                  ];
                }),
                ...workflow.rawRuleSets.map((Object? ruleSet) {
                  final map = ruleSet as Map<String, Object?>?;
                  return map?['name']?.toString() ?? '';
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
  });

  final String label;
  final String initialValue;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      style: const TextStyle(color: textPrimaryColor),
      decoration: InputDecoration(labelText: label, errorText: errorText),
    );
  }
}

class _InspectorNumberField extends StatelessWidget {
  const _InspectorNumberField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final String label;
  final String initialValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      onChanged: (String value) => onChanged(_parseInt(value)),
      style: const TextStyle(color: textPrimaryColor),
      decoration: InputDecoration(labelText: label),
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

class _InspectorDisclosureCard extends StatelessWidget {
  const _InspectorDisclosureCard({
    required this.expanded,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool expanded;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: panelAltColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                      style: const TextStyle(
                        color: textMutedColor,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: textMutedColor,
              ),
            ],
          ),
        ),
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
    required this.configPath,
    required this.parseError,
    required this.onApplySource,
    required this.onClose,
  });

  final bool open;
  final TextEditingController controller;
  final HarnessConfigValidationReport? validation;
  final String configPath;
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
            Text(
              configPath.isEmpty
                  ? 'Edit the full workflow catalog YAML here. Click Apply source to rebuild the board from manual YAML changes.'
                  : 'Config path: $configPath',
              style: const TextStyle(color: textMutedColor),
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
    required this.rawRuleSets,
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
      rawRuleSets:
          ((map.remove('rule_sets') as List<Object?>?) ?? const <Object?>[])
              .toList(),
      nodes: nodes,
      extraFields: map,
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
      rawRuleSets: summary.ruleSets.map((HarnessWorkflowRuleSetSummary value) {
        return <String, Object?>{
          'name': value.name,
          if (value.sourceKind.isNotEmpty) 'source_kind': value.sourceKind,
          if (value.basePath.isNotEmpty) 'base_path': value.basePath,
          if (value.knowledgeBaseName.isNotEmpty)
            'knowledge_base_name': value.knowledgeBaseName,
          if (value.knowledgeBaseVersion.isNotEmpty)
            'knowledge_base_version': value.knowledgeBaseVersion,
        };
      }).toList(),
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
  List<Object?> rawRuleSets;
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
    if (rawRuleSets.isNotEmpty) {
      map['rule_sets'] = rawRuleSets;
    } else {
      map.remove('rule_sets');
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
  const _PolicyFactBindingDraft({
    required this.name,
    required this.source,
    required this.node,
    required this.path,
    required this.required,
  });

  factory _PolicyFactBindingDraft.fromYaml(Map<String, Object?> map) {
    return _PolicyFactBindingDraft(
      name: _stringValue(map['name']),
      source: _stringValue(map['source']),
      node: _stringValue(map['node']),
      path: _stringValue(map['path']),
      required: _boolValue(map['required']),
    );
  }

  final String name;
  final String source;
  final String node;
  final String path;
  final bool required;

  _PolicyFactBindingDraft copyWith({
    String? name,
    String? source,
    String? node,
    String? path,
    bool? required,
  }) {
    return _PolicyFactBindingDraft(
      name: name ?? this.name,
      source: source ?? this.source,
      node: node ?? this.node,
      path: path ?? this.path,
      required: required ?? this.required,
    );
  }

  Map<String, Object?> toYamlMap() {
    return <String, Object?>{
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

String _joinMultiline(List<String> values) {
  return values
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join('\n');
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
