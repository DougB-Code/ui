/// Renders task graph projections inside the shared task command panel.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/theme.dart';
import '../domain/models.dart';
import 'panels/panels.dart';
import 'task_stream_axes.dart';
import 'task_stream_canvas.dart';

/// TaskConceptKind identifies one task projection workspace.
enum TaskConceptKind {
  /// Relationship-first spatial task map.
  constellation,

  /// Daily attention-flow task stream.
  stream,

  /// Priority landscape for planning.
  terrain,

  /// Commitment density map.
  weave,
}

/// TaskConceptProjectionPanel renders one projection without command-panel chrome.
class TaskConceptProjectionPanel extends StatelessWidget {
  /// Creates a task projection panel.
  const TaskConceptProjectionPanel({
    super.key,
    required this.controller,
    required this.kind,
  });

  /// Shared app controller.
  final AuroraAppController controller;

  /// Projection view to render.
  final TaskConceptKind kind;

  /// Builds the selected projection surface.
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AuroraColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: _buildView(),
      ),
    );
  }

  /// Builds the projection matching the current kind.
  Widget _buildView() {
    switch (kind) {
      case TaskConceptKind.constellation:
        return _TaskConstellationView(controller: controller);
      case TaskConceptKind.stream:
        return _TaskStreamView(controller: controller);
      case TaskConceptKind.terrain:
        return _PriorityTerrainView(controller: controller);
      case TaskConceptKind.weave:
        return _CommitmentWeaveView(controller: controller);
    }
  }
}

class _TaskStreamView extends StatefulWidget {
  const _TaskStreamView({required this.controller});

  final AuroraAppController controller;

  /// Creates state for stream axis selection.
  @override
  State<_TaskStreamView> createState() => _TaskStreamViewState();
}

class _TaskStreamViewState extends State<_TaskStreamView> {
  TaskStreamAxisDimension _columnAxis = TaskStreamAxisDimension.time;
  TaskStreamAxisDimension _rowAxis = TaskStreamAxisDimension.attention;

  /// Builds the attention-flow lane projection.
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final projection = controller.taskStreamProjection;
    final axisView = TaskStreamAxisProjector.project(
      projection,
      columnAxis: _columnAxis,
      rowAxis: _rowAxis,
    );
    if (axisView.lanes.every((lane) => lane.cards.isEmpty)) {
      return PanelEmptyBlock(
        label: _emptyProjectionLabel(
          controller,
          'No task stream projection yet',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProjectionToolbar(
          left: <Widget>[
            _TaskStreamAxisSelector(
              tooltip: 'Vertical axis',
              icon: Icons.swap_vert,
              value: _rowAxis,
              dimensions: TaskStreamAxisProjector.rowDimensions,
              onChanged: (dimension) {
                setState(() => _rowAxis = dimension);
              },
            ),
            _TaskStreamAxisSelector(
              tooltip: 'Horizontal axis',
              icon: Icons.swap_horiz,
              value: _columnAxis,
              dimensions: TaskStreamAxisProjector.columnDimensions,
              onChanged: (dimension) {
                setState(() => _columnAxis = dimension);
              },
            ),
          ],
          right: <Widget>[
            _ConceptBadge(label: '${_totalStreamCards(axisView.lanes)} active'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TaskStreamCanvas(
            lanes: axisView.lanes,
            links: projection.links,
            rowAxis: axisView.rowAxis,
            rowBucketsByTaskId: axisView.rowBucketsByTaskId,
            controller: controller,
          ),
        ),
      ],
    );
  }
}

class _TaskStreamAxisSelector extends StatelessWidget {
  const _TaskStreamAxisSelector({
    required this.tooltip,
    required this.icon,
    required this.value,
    required this.dimensions,
    required this.onChanged,
  });

  final String tooltip;
  final IconData icon;
  final TaskStreamAxisDimension value;
  final List<TaskStreamAxisDimension> dimensions;
  final ValueChanged<TaskStreamAxisDimension> onChanged;

  /// Builds one compact axis selector for a stream projection.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AuroraColors.panel,
          border: Border.all(color: AuroraColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: AuroraColors.green),
              const SizedBox(width: 6),
              DropdownButton<TaskStreamAxisDimension>(
                value: value,
                borderRadius: BorderRadius.circular(8),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                style: const TextStyle(
                  color: AuroraColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                items: <DropdownMenuItem<TaskStreamAxisDimension>>[
                  for (final dimension in dimensions)
                    DropdownMenuItem<TaskStreamAxisDimension>(
                      value: dimension,
                      child: Text(
                        TaskStreamAxisProjector.dimensionLabel(dimension),
                      ),
                    ),
                ],
                onChanged: (dimension) {
                  if (dimension != null) {
                    onChanged(dimension);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskConstellationView extends StatelessWidget {
  const _TaskConstellationView({required this.controller});

  final AuroraAppController controller;

  /// Builds the relationship-first constellation projection.
  @override
  Widget build(BuildContext context) {
    final projection = controller.taskConstellationProjection;
    if (projection.nodes.isEmpty) {
      return PanelEmptyBlock(
        label: _emptyProjectionLabel(
          controller,
          'No task constellation projection yet',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProjectionToolbar(
          left: const <Widget>[
            _ConceptBadge(label: 'All tasks'),
            _ConceptBadge(label: 'Active'),
          ],
          right: <Widget>[
            _ConceptBadge(label: '${projection.edges.length} relations'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PanelSectionBlock(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConstellationPainter(projection: projection),
                      ),
                    ),
                    for (final node in projection.nodes)
                      _PositionedConstellationNode(
                        node: node,
                        selected: controller.selectedTask?.id == node.taskId,
                        size: constraints.biggest,
                        onTap: () => controller.selectTask(node.taskId),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PositionedConstellationNode extends StatelessWidget {
  const _PositionedConstellationNode({
    required this.node,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final TaskConstellationNode node;
  final bool selected;
  final Size size;
  final VoidCallback onTap;

  /// Builds a constellation node at a normalized projection position.
  @override
  Widget build(BuildContext context) {
    final diameter = (56 + node.size * 92).clamp(56, 116).toDouble();
    return Positioned(
      left: (node.x * size.width - diameter / 2).clamp(
        0,
        size.width - diameter,
      ),
      top: (node.y * size.height - diameter / 2).clamp(
        0,
        size.height - diameter,
      ),
      width: diameter,
      height: diameter,
      child: Tooltip(
        message: node.explanation,
        child: InkWell(
          borderRadius: BorderRadius.circular(diameter / 2),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AuroraColors.greenSoft
                  : const Color(0xfffffcf8),
              border: Border.all(
                color: selected
                    ? AuroraColors.green
                    : _categoryColor(node.category),
                width: selected ? 2 : 1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  blurRadius: 16 * node.urgency,
                  color: _categoryColor(node.category).withValues(alpha: 0.24),
                ),
              ],
            ),
            child: Text(
              node.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityTerrainView extends StatelessWidget {
  const _PriorityTerrainView({required this.controller});

  final AuroraAppController controller;

  /// Builds the priority terrain projection.
  @override
  Widget build(BuildContext context) {
    final projection = controller.priorityTerrainProjection;
    if (projection.points.isEmpty) {
      return PanelEmptyBlock(
        label: _emptyProjectionLabel(
          controller,
          'No priority terrain projection yet',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProjectionToolbar(
          left: const <Widget>[
            _ConceptBadge(label: 'View: Focus'),
            _ConceptBadge(label: 'All areas'),
          ],
          right: <Widget>[
            _ConceptBadge(label: '${projection.points.length} tasks'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PanelSectionBlock(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(painter: const _TerrainPainter()),
                    ),
                    for (final point in projection.points)
                      _PositionedTerrainPoint(
                        point: point,
                        selected: controller.selectedTask?.id == point.taskId,
                        size: constraints.biggest,
                        onTap: () => controller.selectTask(point.taskId),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PositionedTerrainPoint extends StatelessWidget {
  const _PositionedTerrainPoint({
    required this.point,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final PriorityTerrainPoint point;
  final bool selected;
  final Size size;
  final VoidCallback onTap;

  /// Builds a terrain task marker at a normalized score position.
  @override
  Widget build(BuildContext context) {
    final width = (150 + point.effortScore * 64).clamp(150, 220).toDouble();
    final height = 70.0;
    final left = (point.x * (size.width - width))
        .clamp(0, size.width - width)
        .toDouble();
    final top = ((1 - point.y) * (size.height - height))
        .clamp(0, size.height - height)
        .toDouble();
    final color = _terrainColor(point);
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Tooltip(
        message: point.explanation,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? AuroraColors.greenSoft
                  : const Color(0xfffffcf8),
              border: Border.all(color: selected ? AuroraColors.green : color),
              borderRadius: BorderRadius.circular(8),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                  color: color.withValues(alpha: 0.15),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(
                    (point.elevation * 9 + 1).round().toString(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        point.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        point.dueAt == null
                            ? _taskLabel(point.priority)
                            : 'Due ${_formatShortDate(point.dueAt)}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _CommitmentWeaveView extends StatelessWidget {
  const _CommitmentWeaveView({required this.controller});

  final AuroraAppController controller;

  /// Builds the commitment density projection.
  @override
  Widget build(BuildContext context) {
    final projection = controller.commitmentWeaveProjection;
    if (projection.rows.isEmpty) {
      return PanelEmptyBlock(
        label: _emptyProjectionLabel(
          controller,
          'No commitment weave projection yet',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProjectionToolbar(
          left: const <Widget>[
            _ConceptBadge(label: 'Time: Next 2 Weeks'),
            _ConceptBadge(label: 'Status: Active'),
          ],
          right: <Widget>[
            _ConceptBadge(label: '${projection.items.length} commitments'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PanelSectionBlock(
            child: Column(
              children: <Widget>[
                _WeaveHeader(columns: projection.columns),
                const Divider(height: 1, color: AuroraColors.border),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      for (final row in projection.rows)
                        _WeaveRow(
                          row: row,
                          columns: projection.columns,
                          items: projection.items
                              .where((item) => item.rowId == row.id)
                              .toList(),
                          controller: controller,
                        ),
                    ],
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

class _WeaveHeader extends StatelessWidget {
  const _WeaveHeader({required this.columns});

  final List<CommitmentWeaveColumn> columns;

  /// Builds the weave time-column header.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 150,
            child: Text(
              'Domain',
              style: TextStyle(
                color: AuroraColors.muted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final column in columns)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    column.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  if (column.subtitle.isNotEmpty)
                    Text(
                      column.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AuroraColors.muted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeaveRow extends StatelessWidget {
  const _WeaveRow({
    required this.row,
    required this.columns,
    required this.items,
    required this.controller,
  });

  final CommitmentWeaveRow row;
  final List<CommitmentWeaveColumn> columns;
  final List<CommitmentWeaveItem> items;
  final AuroraAppController controller;

  /// Builds one commitment weave row.
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AuroraColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Row(
              children: <Widget>[
                _DensityDot(density: row.density, conflict: row.conflict),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          for (final column in columns)
            Expanded(
              child: _WeaveCell(
                items: items
                    .where((item) => item.columnId == column.id)
                    .toList(),
                controller: controller,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeaveCell extends StatelessWidget {
  const _WeaveCell({required this.items, required this.controller});

  final List<CommitmentWeaveItem> items;
  final AuroraAppController controller;

  /// Builds one weave row/column intersection.
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
        height: 12,
        decoration: BoxDecoration(
          color: AuroraColors.greenSoft.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final item in items)
            Tooltip(
              message: item.explanation,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => controller.selectTask(item.taskId),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.conflict
                        ? const Color(0xffffefed)
                        : const Color(0xfffffcf8),
                    border: Border.all(
                      color: item.conflict
                          ? AuroraColors.coral
                          : AuroraColors.border,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectionToolbar extends StatelessWidget {
  const _ProjectionToolbar({required this.left, required this.right});

  final List<Widget> left;
  final List<Widget> right;

  /// Builds compact filter/status controls above projection canvases.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: left)),
        const SizedBox(width: 12),
        Wrap(spacing: 8, runSpacing: 8, children: right),
      ],
    );
  }
}

class _ConceptBadge extends StatelessWidget {
  const _ConceptBadge({required this.label});

  final String label;

  /// Builds a small projection metadata badge.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AuroraColors.panel,
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AuroraColors.green,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DensityDot extends StatelessWidget {
  const _DensityDot({required this.density, required this.conflict});

  final double density;
  final bool conflict;

  /// Builds a density indicator for weave rows.
  @override
  Widget build(BuildContext context) {
    final color = conflict ? AuroraColors.coral : AuroraColors.green;
    return Container(
      width: 10 + density * 10,
      height: 10 + density * 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.24 + density * 0.5),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter({required this.projection});

  final TaskConstellationProjection projection;

  /// Paints orbital rings and relation edges.
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AuroraColors.border.withValues(alpha: 0.55);
    for (final radius in <double>[0.22, 0.34, 0.46]) {
      canvas.drawCircle(
        center,
        math.min(size.width, size.height) * radius,
        ringPaint,
      );
    }
    final nodes = <String, TaskConstellationNode>{
      for (final node in projection.nodes) node.taskId: node,
    };
    for (final edge in projection.edges) {
      final from = nodes[edge.fromTaskId];
      final to = nodes[edge.toTaskId];
      if (from == null || to == null) {
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + edge.confidence * 2
        ..color = _edgeColor(
          edge,
        ).withValues(alpha: 0.32 + edge.confidence * 0.32);
      canvas.drawLine(
        Offset(from.x * size.width, from.y * size.height),
        Offset(to.x * size.width, to.y * size.height),
        paint,
      );
    }
  }

  /// Reports whether this painter needs repainting.
  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) {
    return oldDelegate.projection != projection;
  }
}

class _TerrainPainter extends CustomPainter {
  const _TerrainPainter();

  /// Paints contour-like terrain bands.
  @override
  void paint(Canvas canvas, Size size) {
    final regions = <({Color color, Offset center, double radius})>[
      (
        color: AuroraColors.coral,
        center: Offset(size.width * 0.18, size.height * 0.18),
        radius: size.shortestSide * 0.32,
      ),
      (
        color: AuroraColors.green,
        center: Offset(size.width * 0.30, size.height * 0.72),
        radius: size.shortestSide * 0.34,
      ),
      (
        color: const Color(0xff7b6398),
        center: Offset(size.width * 0.82, size.height * 0.68),
        radius: size.shortestSide * 0.28,
      ),
    ];
    for (final region in regions) {
      for (var index = 0; index < 8; index++) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = region.color.withValues(alpha: 0.06 + index * 0.01);
        canvas.drawCircle(region.center, region.radius + index * 18, paint);
      }
    }
  }

  /// Reports whether this painter needs repainting.
  @override
  bool shouldRepaint(covariant _TerrainPainter oldDelegate) => false;
}

/// Returns the number of projected stream cards.
int _totalStreamCards(List<TaskStreamLane> lanes) {
  return lanes.fold<int>(0, (count, lane) => count + lane.cards.length);
}

/// Returns an empty-state label with projection loading detail when available.
String _emptyProjectionLabel(AuroraAppController controller, String fallback) {
  final message = controller.taskProjectionMessage.trim();
  if (message.isEmpty) {
    return fallback;
  }
  return message;
}

/// Returns a readable label for a backend task value.
String _taskLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

/// Formats a compact date.
String _formatShortDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  return '${local.month}/${local.day}';
}

/// Returns a color for a constellation category.
Color _categoryColor(String category) {
  final normalized = category.toLowerCase();
  if (normalized.contains('errand') || normalized.contains('shopping')) {
    return const Color(0xffd99a22);
  }
  if (normalized.contains('work')) {
    return AuroraColors.green;
  }
  if (normalized.contains('health')) {
    return const Color(0xff5f87b4);
  }
  if (normalized.contains('personal')) {
    return const Color(0xff7b6398);
  }
  return AuroraColors.border;
}

/// Returns a color for a constellation edge.
Color _edgeColor(TaskConstellationEdge edge) {
  if (edge.relationType == 'depends_on' || edge.relationType == 'blocks') {
    return AuroraColors.coral;
  }
  if (edge.source == 'explicit') {
    return AuroraColors.green;
  }
  return AuroraColors.muted;
}

/// Returns a color for a terrain point.
Color _terrainColor(PriorityTerrainPoint point) {
  if (point.riskScore > 0.65) {
    return const Color(0xff7b6398);
  }
  if (point.urgencyScore > 0.72) {
    return AuroraColors.coral;
  }
  if (point.valueScore > 0.62) {
    return AuroraColors.green;
  }
  return const Color(0xffd28b24);
}
