/// Implements the first-class task workspace panels.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/theme.dart';
import '../domain/models.dart';
import 'panels/panels.dart';

const List<String> _taskStatuses = <String>[
  'open',
  'waiting',
  'blocked',
  'done',
  'canceled',
];

const List<String> _activeTaskStatuses = <String>['open', 'waiting', 'blocked'];

const List<String> _taskPriorities = <String>[
  'urgent',
  'high',
  'normal',
  'low',
];

/// TasksQueuePanel renders task navigation, queue, lists, review, and capture.
class TasksQueuePanel extends StatelessWidget {
  /// Creates a task queue panel.
  const TasksQueuePanel({super.key, required this.controller});

  /// Shared app controller.
  final AuroraAppController controller;

  /// Builds the left task command surface.
  @override
  Widget build(BuildContext context) {
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: 'Queue',
          icon: Icons.task_alt_outlined,
          builder: (query) =>
              _TasksQueueContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Lists',
          icon: Icons.checklist_outlined,
          builder: (query) =>
              _TaskListsContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Review',
          icon: Icons.rule_folder_outlined,
          builder: (query) =>
              _TaskReviewContent(controller: controller, query: query),
        ),
        SwitcherPanelArea(
          title: 'Capture',
          icon: Icons.add_task_outlined,
          builder: (query) =>
              _TaskCaptureContent(controller: controller, query: query),
        ),
      ],
    );
  }
}

/// TasksInspectorPanel renders the selected task or list editor.
class TasksInspectorPanel extends StatelessWidget {
  /// Creates a task inspector panel.
  const TasksInspectorPanel({super.key, required this.controller});

  /// Shared app controller.
  final AuroraAppController controller;

  /// Builds the right task inspector surface.
  @override
  Widget build(BuildContext context) {
    final task = controller.selectedTask;
    final list = controller.selectedTaskList;
    return ColoredBox(
      color: AuroraColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'TASK INSPECTOR',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AuroraColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Refresh tasks',
                  child: IconButton.outlined(
                    onPressed: controller.tasksBusy
                        ? null
                        : () => unawaited(controller.refreshTasksFromUi()),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AuroraColors.border),
          Expanded(
            child: task != null
                ? _TaskDetailEditor(controller: controller, task: task)
                : list != null
                ? _TaskListInspector(controller: controller, list: list)
                : const _TaskSelectionEmpty(),
          ),
        ],
      ),
    );
  }
}

class _TasksQueueContent extends StatelessWidget {
  const _TasksQueueContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds the filtered operational task queue.
  @override
  Widget build(BuildContext context) {
    final tasks = controller.filteredTasks.where((task) {
      return _matchesTask(task, query);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TaskStatusStrip(controller: controller),
          const SizedBox(height: 14),
          _TaskFilterBar(controller: controller),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _TaskMetricStrip(
                  tasks: controller.workspace.tasks,
                  lists: controller.taskLists,
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'New task',
                child: IconButton.filled(
                  onPressed: controller.tasksBusy
                      ? null
                      : () => unawaited(
                          _showTaskCreateDialog(context, controller),
                        ),
                  icon: const Icon(Icons.add),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            const _TaskEmptyBlock(label: 'No tasks match this view')
          else
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskQueueTile(
                  task: task,
                  selected: controller.selectedTask?.id == task.id,
                  onTap: () => controller.selectTask(task.id),
                  onComplete: task.done || task.status == 'canceled'
                      ? null
                      : () => unawaited(controller.completeTaskFromUi(task.id)),
                ),
              ),
        ],
      ),
    );
  }
}

class _TaskStatusStrip extends StatelessWidget {
  const _TaskStatusStrip({required this.controller});

  final AuroraAppController controller;

  /// Builds task service status and operation feedback.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (controller.tasksBusy)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(Icons.circle, size: 10, color: AuroraColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            controller.tasksMessage,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AuroraColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _TaskMetricStrip extends StatelessWidget {
  const _TaskMetricStrip({required this.tasks, required this.lists});

  final List<WorkspaceTask> tasks;
  final List<WorkspaceTaskList> lists;

  /// Builds compact queue counts.
  @override
  Widget build(BuildContext context) {
    final open = tasks.where((task) => task.active).length;
    final overdue = tasks.where((task) => task.overdue).length;
    final waiting = tasks.where((task) => task.status == 'waiting').length;
    final blocked = tasks.where((task) => task.status == 'blocked').length;
    final uncheckedItems = lists.fold<int>(
      0,
      (count, list) => count + list.items.where((item) => !item.checked).length,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _TaskBadge(label: '$open open'),
        _TaskBadge(label: '$overdue overdue'),
        _TaskBadge(label: '$waiting waiting'),
        _TaskBadge(label: '$blocked blocked'),
        _TaskBadge(label: '$uncheckedItems list items'),
      ],
    );
  }
}

class _TaskFilterBar extends StatelessWidget {
  const _TaskFilterBar({required this.controller});

  final AuroraAppController controller;

  /// Builds queue filter chips and refresh controls.
  @override
  Widget build(BuildContext context) {
    final filters = controller.taskFilters;
    return _TaskSectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ActionChip(
                      avatar: const Icon(Icons.playlist_play, size: 18),
                      label: const Text('Active'),
                      onPressed: () {
                        unawaited(
                          controller.applyTaskFilters(
                            filters.copyWith(
                              statuses: _activeTaskStatuses,
                              includeDone: true,
                            ),
                          ),
                        );
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.all_inbox, size: 18),
                      label: const Text('All'),
                      onPressed: () {
                        unawaited(
                          controller.applyTaskFilters(
                            filters.copyWith(
                              statuses: const <String>[],
                              includeDone: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Refresh tasks',
                child: IconButton.outlined(
                  onPressed: controller.tasksBusy
                      ? null
                      : () => unawaited(controller.refreshTasksFromUi()),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final status in _taskStatuses)
                FilterChip(
                  label: Text(_taskLabel(status)),
                  selected: filters.statuses.contains(status),
                  onSelected: (_) {
                    unawaited(
                      controller.applyTaskFilters(
                        filters.copyWith(
                          statuses: _toggleFilterValue(
                            filters.statuses,
                            status,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              FilterChip(
                label: const Text('Overdue'),
                selected: filters.overdueOnly,
                onSelected: (selected) {
                  unawaited(
                    controller.applyTaskFilters(
                      filters.copyWith(overdueOnly: selected),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final priority in _taskPriorities)
                FilterChip(
                  label: Text(_taskLabel(priority)),
                  selected: filters.priorities.contains(priority),
                  onSelected: (_) {
                    unawaited(
                      controller.applyTaskFilters(
                        filters.copyWith(
                          priorities: _toggleFilterValue(
                            filters.priorities,
                            priority,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              for (final topic in controller.taskTopics.take(8))
                FilterChip(
                  label: Text(topic),
                  selected: filters.topics.contains(topic),
                  onSelected: (_) {
                    unawaited(
                      controller.applyTaskFilters(
                        filters.copyWith(
                          topics: _toggleFilterValue(filters.topics, topic),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskQueueTile extends StatelessWidget {
  const _TaskQueueTile({
    required this.task,
    required this.selected,
    required this.onTap,
    required this.onComplete,
  });

  final WorkspaceTask task;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onComplete;

  /// Builds one selectable task row.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AuroraColors.greenSoft : const Color(0xfffffcf8),
          border: Border.all(
            color: selected ? AuroraColors.green : AuroraColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Checkbox(
              value: task.done,
              onChanged: onComplete == null ? null : (_) => onComplete!(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TaskPriorityBadge(priority: task.priority),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AuroraColors.muted),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _TaskBadge(label: _taskLabel(task.status)),
                      if (task.overdue) const _TaskBadge(label: 'Overdue'),
                      if (task.dueAt != null)
                        _TaskBadge(label: 'Due ${_formatTaskDate(task.dueAt)}'),
                      if (task.scheduledAt != null)
                        _TaskBadge(
                          label:
                              'Scheduled ${_formatTaskDate(task.scheduledAt)}',
                        ),
                      if (task.memoryLinks.isNotEmpty)
                        _TaskBadge(
                          label: '${task.memoryLinks.length} memories',
                        ),
                      if (task.sourceLabel.isNotEmpty)
                        _TaskBadge(label: task.sourceLabel),
                      for (final topic in task.topics.take(3))
                        _TaskBadge(label: topic),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskPriorityBadge extends StatelessWidget {
  const _TaskPriorityBadge({required this.priority});

  final String priority;

  /// Builds a priority badge with urgency-aware color.
  @override
  Widget build(BuildContext context) {
    final urgent = priority == 'urgent' || priority == 'high';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xffffefed) : AuroraColors.panel,
        border: Border.all(
          color: urgent ? AuroraColors.coral : AuroraColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _taskLabel(priority),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: urgent ? AuroraColors.coral : AuroraColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TaskListsContent extends StatelessWidget {
  const _TaskListsContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds named task lists and item previews.
  @override
  Widget build(BuildContext context) {
    final lists = controller.taskLists.where((list) {
      return _matchesTaskList(list, query);
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TaskStatusStrip(controller: controller),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${lists.length} lists',
                  style: const TextStyle(
                    color: AuroraColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Tooltip(
                message: 'New list',
                child: IconButton.filled(
                  onPressed: controller.tasksBusy
                      ? null
                      : () => unawaited(
                          _showListCreateDialog(context, controller),
                        ),
                  icon: const Icon(Icons.playlist_add),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (lists.isEmpty)
            const _TaskEmptyBlock(label: 'No named lists')
          else
            for (final list in lists)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskListTile(
                  list: list,
                  selected: controller.selectedTaskList?.id == list.id,
                  selectedItemId: controller.selectedTaskListItem?.id,
                  onTap: () => controller.selectTaskList(list.id),
                  onItemTap: (item) =>
                      controller.selectTaskList(list.id, itemId: item.id),
                  onCheckItem: (item, checked) => unawaited(
                    controller.checkTaskListItemFromUi(
                      itemId: item.id,
                      checked: checked,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _TaskListTile extends StatelessWidget {
  const _TaskListTile({
    required this.list,
    required this.selected,
    required this.selectedItemId,
    required this.onTap,
    required this.onItemTap,
    required this.onCheckItem,
  });

  final WorkspaceTaskList list;
  final bool selected;
  final String? selectedItemId;
  final VoidCallback onTap;
  final ValueChanged<TaskListItem> onItemTap;
  final void Function(TaskListItem item, bool checked) onCheckItem;

  /// Builds one selectable named-list row.
  @override
  Widget build(BuildContext context) {
    final unchecked = list.items.where((item) => !item.checked).length;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AuroraColors.greenSoft : const Color(0xfffffcf8),
          border: Border.all(
            color: selected ? AuroraColors.green : AuroraColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                _TaskBadge(label: '$unchecked open'),
              ],
            ),
            if (list.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                list.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AuroraColors.muted),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (list.sourceLabel.isNotEmpty)
                  _TaskBadge(label: list.sourceLabel),
                if (list.memoryLinks.isNotEmpty)
                  _TaskBadge(label: '${list.memoryLinks.length} memories'),
                for (final topic in list.topics.take(3))
                  _TaskBadge(label: topic),
              ],
            ),
            if (list.items.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              for (final item in list.items.take(4))
                _TaskListItemPreview(
                  item: item,
                  selected: selectedItemId == item.id,
                  onTap: () => onItemTap(item),
                  onChanged: (checked) => onCheckItem(item, checked),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskListItemPreview extends StatelessWidget {
  const _TaskListItemPreview({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  final TaskListItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  /// Builds a compact checklist item preview.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AuroraColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Checkbox(
              value: item.checked,
              onChanged: (value) => onChanged(value ?? false),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: item.checked ? AuroraColors.muted : AuroraColors.ink,
                  decoration: item.checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (item.dueAt != null)
              _TaskBadge(label: _formatTaskDate(item.dueAt)),
          ],
        ),
      ),
    );
  }
}

class _TaskReviewContent extends StatelessWidget {
  const _TaskReviewContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  /// Builds the task steward review queue.
  @override
  Widget build(BuildContext context) {
    final report = controller.taskReviewReport;
    final recommendations =
        report?.recommendations.where((recommendation) {
          return _matchesRecommendation(recommendation, query);
        }).toList() ??
        const <TaskReviewRecommendation>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TaskStatusStrip(controller: controller),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(controller.reviewTasksFromUi()),
            icon: const Icon(Icons.rule_folder_outlined),
            label: const Text('Run Review'),
          ),
          const SizedBox(height: 14),
          if (report == null)
            const _TaskEmptyBlock(label: 'No review has run yet')
          else ...<Widget>[
            _TaskSectionBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _TaskPanelLabel('Summary'),
                  const SizedBox(height: 10),
                  Text(report.summary),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _TaskBadge(label: '${report.reviewedTasks} tasks'),
                      _TaskBadge(label: '${report.reviewedLists} lists'),
                      _TaskBadge(
                        label: '${recommendations.length} recommendations',
                      ),
                      if (report.generatedAt != null)
                        _TaskBadge(
                          label: _formatTaskDateTime(report.generatedAt),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (recommendations.isEmpty)
              const _TaskEmptyBlock(label: 'No recommendations match')
            else
              for (final recommendation in recommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskRecommendationTile(
                    recommendation: recommendation,
                    onTap: () =>
                        _selectRecommendationTarget(controller, recommendation),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _TaskRecommendationTile extends StatelessWidget {
  const _TaskRecommendationTile({
    required this.recommendation,
    required this.onTap,
  });

  final TaskReviewRecommendation recommendation;
  final VoidCallback onTap;

  /// Builds one task review recommendation.
  @override
  Widget build(BuildContext context) {
    final high = recommendation.severity == 'high';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: high ? const Color(0xffffefed) : const Color(0xfffffcf8),
          border: Border.all(
            color: high ? AuroraColors.coral : AuroraColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  high ? Icons.priority_high : Icons.tips_and_updates_outlined,
                  color: high ? AuroraColors.coral : AuroraColors.green,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                _TaskBadge(label: recommendation.severity),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              recommendation.message,
              style: const TextStyle(color: AuroraColors.muted),
            ),
            if (recommendation.proposedAction.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(recommendation.proposedAction),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _TaskBadge(label: recommendation.kind),
                _TaskBadge(label: recommendation.targetType),
                if (recommendation.sourceLabel.isNotEmpty)
                  _TaskBadge(label: recommendation.sourceLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCaptureContent extends StatefulWidget {
  const _TaskCaptureContent({required this.controller, required this.query});

  final AuroraAppController controller;
  final String query;

  @override
  State<_TaskCaptureContent> createState() => _TaskCaptureContentState();
}

class _TaskCaptureContentState extends State<_TaskCaptureContent> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  final TextEditingController _dueAt = TextEditingController();
  final TextEditingController _scheduledAt = TextEditingController();
  String _status = 'open';
  String _priority = 'normal';
  bool _linkMemory = false;
  String _message = '';

  /// Cleans up capture form controllers.
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _topics.dispose();
    _dueAt.dispose();
    _scheduledAt.dispose();
    super.dispose();
  }

  /// Builds the quick task capture form.
  @override
  Widget build(BuildContext context) {
    final matches = widget.controller.workspace.tasks
        .where((task) {
          return _title.text.trim().isNotEmpty &&
              _matchesTask(task, '${_title.text} ${widget.query}');
        })
        .take(4);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TaskSectionBlock(
            child: Column(
              children: <Widget>[
                _TaskTextField(controller: _title, label: 'Title'),
                const SizedBox(height: 10),
                _TaskTextField(
                  controller: _description,
                  label: 'Description',
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TaskDropdown(
                        value: _status,
                        values: _taskStatuses,
                        tooltip: 'Status',
                        onChanged: (value) => setState(() => _status = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDropdown(
                        value: _priority,
                        values: _taskPriorities,
                        tooltip: 'Priority',
                        onChanged: (value) => setState(() => _priority = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TaskTextField(
                        controller: _dueAt,
                        label: 'Due date',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskTextField(
                        controller: _scheduledAt,
                        label: 'Scheduled date',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TaskTextField(controller: _topics, label: 'Topics'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Link selected memory'),
                  value: _linkMemory,
                  onChanged: widget.controller.selectedMemory == null
                      ? null
                      : (value) => setState(() => _linkMemory = value ?? false),
                ),
              ],
            ),
          ),
          if (_message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(_message, style: const TextStyle(color: AuroraColors.coral)),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.controller.tasksBusy ? null : _save,
            icon: const Icon(Icons.add_task),
            label: const Text('Create Task'),
          ),
          const SizedBox(height: 14),
          _TaskSectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TaskPanelLabel('Nearby Tasks'),
                const SizedBox(height: 10),
                if (matches.isEmpty)
                  const Text(
                    'No nearby tasks',
                    style: TextStyle(color: AuroraColors.muted),
                  )
                else
                  for (final task in matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TaskQueueTile(
                        task: task,
                        selected: widget.controller.selectedTask?.id == task.id,
                        onTap: () => widget.controller.selectTask(task.id),
                        onComplete: null,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Saves the captured task.
  Future<void> _save() async {
    final dueAt = _parseTaskDateInput(_dueAt.text);
    final scheduledAt = _parseTaskDateInput(_scheduledAt.text);
    if (_dueAt.text.trim().isNotEmpty && dueAt == null) {
      setState(() => _message = 'Due date could not be parsed');
      return;
    }
    if (_scheduledAt.text.trim().isNotEmpty && scheduledAt == null) {
      setState(() => _message = 'Scheduled date could not be parsed');
      return;
    }
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _message = 'Title is required');
      return;
    }
    await widget.controller.createTaskFromUi(
      title,
      description: _description.text.trim(),
      status: _status,
      priority: _priority,
      dueAt: dueAt,
      scheduledAt: scheduledAt,
      topics: _splitTaskList(_topics.text),
      linkSelectedMemory: _linkMemory,
    );
    if (!mounted) {
      return;
    }
    _title.clear();
    _description.clear();
    _topics.clear();
    _dueAt.clear();
    _scheduledAt.clear();
    setState(() {
      _message = '';
      _linkMemory = false;
    });
  }
}

class _TaskDetailEditor extends StatefulWidget {
  const _TaskDetailEditor({required this.controller, required this.task});

  final AuroraAppController controller;
  final WorkspaceTask task;

  @override
  State<_TaskDetailEditor> createState() => _TaskDetailEditorState();
}

class _TaskDetailEditorState extends State<_TaskDetailEditor> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  final TextEditingController _dueAt = TextEditingController();
  final TextEditingController _scheduledAt = TextEditingController();
  String _status = 'open';
  String _priority = 'normal';
  String _message = '';

  /// Initializes editor fields from the selected task.
  @override
  void initState() {
    super.initState();
    _syncFromTask();
  }

  /// Reloads editor fields when task selection changes.
  @override
  void didUpdateWidget(covariant _TaskDetailEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _syncFromTask();
    }
  }

  /// Cleans up editor controllers.
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _topics.dispose();
    _dueAt.dispose();
    _scheduledAt.dispose();
    super.dispose();
  }

  /// Builds the selected task editor.
  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final terminal = task.status == 'done' || task.status == 'canceled';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TaskStatusStrip(controller: widget.controller),
          const SizedBox(height: 14),
          _TaskSectionBlock(
            child: Column(
              children: <Widget>[
                _TaskTextField(controller: _title, label: 'Title'),
                const SizedBox(height: 10),
                _TaskTextField(
                  controller: _description,
                  label: 'Description',
                  maxLines: 5,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TaskDropdown(
                        value: _status,
                        values: _taskStatuses,
                        tooltip: 'Status',
                        onChanged: (value) => setState(() => _status = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDropdown(
                        value: _priority,
                        values: _taskPriorities,
                        tooltip: 'Priority',
                        onChanged: (value) => setState(() => _priority = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TaskTextField(
                        controller: _dueAt,
                        label: 'Due date',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskTextField(
                        controller: _scheduledAt,
                        label: 'Scheduled date',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TaskTextField(controller: _topics, label: 'Topics'),
              ],
            ),
          ),
          if (_message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(_message, style: const TextStyle(color: AuroraColors.coral)),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: widget.controller.tasksBusy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.tasksBusy || terminal
                    ? null
                    : () => unawaited(_complete()),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.tasksBusy || terminal
                    ? null
                    : () => unawaited(_cancel()),
                icon: const Icon(Icons.block_outlined),
                label: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                onPressed:
                    widget.controller.tasksBusy ||
                        widget.controller.selectedMemory == null
                    ? null
                    : () => unawaited(
                        widget.controller.linkSelectedMemoryToTaskFromUi(
                          task.id,
                        ),
                      ),
                icon: const Icon(Icons.link),
                label: const Text('Link Memory'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.tasksBusy
                    ? null
                    : () => unawaited(_delete()),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TaskMetadataBlock(task: task),
          const SizedBox(height: 14),
          _TaskMemoryLinksBlock(
            links: task.memoryLinks,
            onUnlink: (link) => unawaited(
              widget.controller.unlinkTaskMemoryFromUi(
                taskId: task.id,
                linkId: link.id,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Copies selected task data into text fields.
  void _syncFromTask() {
    _title.text = widget.task.title;
    _description.text = widget.task.description;
    _topics.text = widget.task.topics.join(', ');
    _dueAt.text = _formatTaskDateTime(widget.task.dueAt);
    _scheduledAt.text = _formatTaskDateTime(widget.task.scheduledAt);
    _status = widget.task.status;
    _priority = widget.task.priority;
    _message = '';
  }

  /// Saves editor changes to the task service.
  Future<void> _save() async {
    final dueAt = _parseTaskDateInput(_dueAt.text);
    final scheduledAt = _parseTaskDateInput(_scheduledAt.text);
    if (_dueAt.text.trim().isNotEmpty && dueAt == null) {
      setState(() => _message = 'Due date could not be parsed');
      return;
    }
    if (_scheduledAt.text.trim().isNotEmpty && scheduledAt == null) {
      setState(() => _message = 'Scheduled date could not be parsed');
      return;
    }
    if (_title.text.trim().isEmpty) {
      setState(() => _message = 'Title is required');
      return;
    }
    await widget.controller.updateTaskFromUi(
      taskId: widget.task.id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      status: _status,
      priority: _priority,
      dueAt: dueAt,
      clearDueAt: _dueAt.text.trim().isEmpty && widget.task.dueAt != null,
      scheduledAt: scheduledAt,
      clearScheduledAt:
          _scheduledAt.text.trim().isEmpty && widget.task.scheduledAt != null,
      topics: _splitTaskList(_topics.text),
    );
    if (mounted) {
      setState(() => _message = '');
    }
  }

  /// Completes the selected task after confirmation.
  Future<void> _complete() async {
    if (!await _confirmTaskWrite(context, 'Complete "${widget.task.title}"?')) {
      return;
    }
    await widget.controller.completeTaskFromUi(widget.task.id);
  }

  /// Cancels the selected task after confirmation.
  Future<void> _cancel() async {
    if (!await _confirmTaskWrite(context, 'Cancel "${widget.task.title}"?')) {
      return;
    }
    await widget.controller.cancelTaskFromUi(widget.task.id);
  }

  /// Deletes the selected task after confirmation.
  Future<void> _delete() async {
    if (!await _confirmTaskWrite(context, 'Delete "${widget.task.title}"?')) {
      return;
    }
    await widget.controller.deleteTaskFromUi(widget.task.id);
  }
}

class _TaskMetadataBlock extends StatelessWidget {
  const _TaskMetadataBlock({required this.task});

  final WorkspaceTask task;

  /// Builds task metadata details.
  @override
  Widget build(BuildContext context) {
    return _TaskSectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TaskPanelLabel('Metadata'),
          const SizedBox(height: 10),
          _TaskMetadataRow(label: 'Task id', value: task.id),
          _TaskMetadataRow(label: 'Source', value: task.sourceLabel),
          _TaskMetadataRow(
            label: 'Created',
            value: _formatTaskDateTime(task.createdAt),
          ),
          _TaskMetadataRow(
            label: 'Updated',
            value: _formatTaskDateTime(task.updatedAt),
          ),
          _TaskMetadataRow(
            label: 'Completed',
            value: _formatTaskDateTime(task.completedAt),
          ),
          _TaskMetadataRow(
            label: 'Canceled',
            value: _formatTaskDateTime(task.canceledAt),
          ),
        ],
      ),
    );
  }
}

class _TaskListInspector extends StatelessWidget {
  const _TaskListInspector({required this.controller, required this.list});

  final AuroraAppController controller;
  final WorkspaceTaskList list;

  /// Builds the named-list inspector.
  @override
  Widget build(BuildContext context) {
    final selectedItem = controller.selectedTaskListItem;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TaskStatusStrip(controller: controller),
          const SizedBox(height: 14),
          _TaskSectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        list.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    _TaskBadge(label: '${list.items.length} items'),
                  ],
                ),
                if (list.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    list.description,
                    style: const TextStyle(color: AuroraColors.muted),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (list.sourceLabel.isNotEmpty)
                      _TaskBadge(label: list.sourceLabel),
                    for (final topic in list.topics) _TaskBadge(label: topic),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: controller.tasksBusy
                    ? null
                    : () => unawaited(
                        _showListItemCreateDialog(context, controller, list),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
              OutlinedButton.icon(
                onPressed:
                    controller.tasksBusy || controller.selectedMemory == null
                    ? null
                    : () => unawaited(
                        controller.linkSelectedMemoryToTaskListFromUi(list.id),
                      ),
                icon: const Icon(Icons.link),
                label: const Text('Link Memory'),
              ),
              OutlinedButton.icon(
                onPressed: controller.tasksBusy
                    ? null
                    : () => unawaited(_deleteList(context)),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete List'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TaskMemoryLinksBlock(
            links: list.memoryLinks,
            onUnlink: (link) => unawaited(
              controller.unlinkTaskListMemoryFromUi(
                listId: list.id,
                linkId: link.id,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _TaskSectionBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TaskPanelLabel('Items'),
                const SizedBox(height: 10),
                if (list.items.isEmpty)
                  const Text(
                    'No list items',
                    style: TextStyle(color: AuroraColors.muted),
                  )
                else
                  for (final item in list.items)
                    _TaskListItemRow(
                      item: item,
                      selected: selectedItem?.id == item.id,
                      onTap: () =>
                          controller.selectTaskList(list.id, itemId: item.id),
                      onChanged: (checked) => unawaited(
                        controller.checkTaskListItemFromUi(
                          itemId: item.id,
                          checked: checked,
                        ),
                      ),
                    ),
              ],
            ),
          ),
          if (selectedItem != null) ...<Widget>[
            const SizedBox(height: 14),
            _TaskListItemEditor(
              controller: controller,
              list: list,
              item: selectedItem,
            ),
          ],
        ],
      ),
    );
  }

  /// Deletes the selected list after confirmation.
  Future<void> _deleteList(BuildContext context) async {
    if (!await _confirmTaskWrite(context, 'Delete list "${list.name}"?')) {
      return;
    }
    await controller.deleteTaskListFromUi(list.id);
  }
}

class _TaskListItemRow extends StatelessWidget {
  const _TaskListItemRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  final TaskListItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;

  /// Builds one full list item row.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AuroraColors.greenSoft : AuroraColors.surface,
          border: Border.all(
            color: selected ? AuroraColors.green : AuroraColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Checkbox(
              value: item.checked,
              onChanged: (value) => onChanged(value ?? false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  decoration: item.checked ? TextDecoration.lineThrough : null,
                  color: item.checked ? AuroraColors.muted : AuroraColors.ink,
                ),
              ),
            ),
            if (item.memoryLinks.isNotEmpty)
              _TaskBadge(label: '${item.memoryLinks.length} memories'),
            if (item.dueAt != null) ...<Widget>[
              const SizedBox(width: 6),
              _TaskBadge(label: _formatTaskDate(item.dueAt)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskListItemEditor extends StatefulWidget {
  const _TaskListItemEditor({
    required this.controller,
    required this.list,
    required this.item,
  });

  final AuroraAppController controller;
  final WorkspaceTaskList list;
  final TaskListItem item;

  @override
  State<_TaskListItemEditor> createState() => _TaskListItemEditorState();
}

class _TaskListItemEditorState extends State<_TaskListItemEditor> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _dueAt = TextEditingController();
  bool _checked = false;
  String _message = '';

  /// Initializes list item editor fields.
  @override
  void initState() {
    super.initState();
    _syncFromItem();
  }

  /// Reloads fields when item selection changes.
  @override
  void didUpdateWidget(covariant _TaskListItemEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _syncFromItem();
    }
  }

  /// Cleans up item editor controllers.
  @override
  void dispose() {
    _text.dispose();
    _dueAt.dispose();
    super.dispose();
  }

  /// Builds the selected list item editor.
  @override
  Widget build(BuildContext context) {
    return _TaskSectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TaskPanelLabel('Selected Item'),
          const SizedBox(height: 10),
          _TaskTextField(controller: _text, label: 'Item text'),
          const SizedBox(height: 10),
          _TaskTextField(controller: _dueAt, label: 'Due date'),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Checked'),
            value: _checked,
            onChanged: (value) => setState(() => _checked = value ?? false),
          ),
          if (_message.isNotEmpty)
            Text(_message, style: const TextStyle(color: AuroraColors.coral)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.icon(
                onPressed: widget.controller.tasksBusy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Item'),
              ),
              OutlinedButton.icon(
                onPressed:
                    widget.controller.tasksBusy ||
                        widget.controller.selectedMemory == null
                    ? null
                    : () => unawaited(
                        widget.controller
                            .linkSelectedMemoryToTaskListItemFromUi(
                              widget.item.id,
                            ),
                      ),
                icon: const Icon(Icons.link),
                label: const Text('Link Memory'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.tasksBusy
                    ? null
                    : () => unawaited(_delete()),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Item'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TaskMemoryLinksBlock(
            links: widget.item.memoryLinks,
            onUnlink: (link) => unawaited(
              widget.controller.unlinkTaskListItemMemoryFromUi(
                itemId: widget.item.id,
                linkId: link.id,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Copies selected item data into text fields.
  void _syncFromItem() {
    _text.text = widget.item.text;
    _dueAt.text = _formatTaskDateTime(widget.item.dueAt);
    _checked = widget.item.checked;
    _message = '';
  }

  /// Saves list item changes to the task service.
  Future<void> _save() async {
    final dueAt = _parseTaskDateInput(_dueAt.text);
    if (_dueAt.text.trim().isNotEmpty && dueAt == null) {
      setState(() => _message = 'Due date could not be parsed');
      return;
    }
    if (_text.text.trim().isEmpty) {
      setState(() => _message = 'Item text is required');
      return;
    }
    await widget.controller.updateTaskListItemFromUi(
      itemId: widget.item.id,
      text: _text.text.trim(),
      dueAt: dueAt,
      clearDueAt: _dueAt.text.trim().isEmpty && widget.item.dueAt != null,
      checked: _checked,
    );
    if (mounted) {
      setState(() => _message = '');
    }
  }

  /// Deletes the selected item after confirmation.
  Future<void> _delete() async {
    if (!await _confirmTaskWrite(context, 'Delete "${widget.item.text}"?')) {
      return;
    }
    await widget.controller.deleteTaskListItemFromUi(widget.item.id);
  }
}

class _TaskMemoryLinksBlock extends StatelessWidget {
  const _TaskMemoryLinksBlock({required this.links, required this.onUnlink});

  final List<TaskMemoryLink> links;
  final ValueChanged<TaskMemoryLink> onUnlink;

  /// Builds memory link rows for task objects.
  @override
  Widget build(BuildContext context) {
    return _TaskSectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TaskPanelLabel('Memory Links'),
          const SizedBox(height: 10),
          if (links.isEmpty)
            const Text(
              'No linked memory',
              style: TextStyle(color: AuroraColors.muted),
            )
          else
            for (final link in links)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            link.note.isEmpty ? link.relationship : link.note,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            link.memoryCatalogId.isEmpty
                                ? link.memoryEvidenceId
                                : link.memoryCatalogId,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AuroraColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TaskBadge(label: link.relationship),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Unlink memory',
                      child: IconButton.outlined(
                        onPressed: () => onUnlink(link),
                        icon: const Icon(Icons.link_off, size: 18),
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

class _TaskSectionBlock extends StatelessWidget {
  const _TaskSectionBlock({required this.child});

  final Widget child;

  /// Builds a compact bordered task work surface.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffffcf8),
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _TaskPanelLabel extends StatelessWidget {
  const _TaskPanelLabel(this.label);

  final String label;

  /// Builds an uppercase task panel label.
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AuroraColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.4,
      ),
    );
  }
}

class _TaskBadge extends StatelessWidget {
  const _TaskBadge({required this.label});

  final String label;

  /// Builds a dense task metadata badge.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AuroraColors.panel,
        border: Border.all(color: AuroraColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _taskLabel(label),
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AuroraColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TaskDropdown extends StatelessWidget {
  const _TaskDropdown({
    required this.value,
    required this.values,
    required this.tooltip,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final String tooltip;
  final ValueChanged<String> onChanged;

  /// Builds a compact dropdown for task controlled vocabulary.
  @override
  Widget build(BuildContext context) {
    final dropdownValue = values.contains(value) ? value : values.first;
    return Tooltip(
      message: tooltip,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AuroraColors.surface,
          border: Border.all(color: AuroraColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: dropdownValue,
            isDense: true,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, size: 18),
            items: <DropdownMenuItem<String>>[
              for (final item in values)
                DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    _taskLabel(item),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _TaskTextField extends StatelessWidget {
  const _TaskTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  /// Builds a compact task form field.
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: maxLines == 1 ? 1 : 3,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AuroraColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AuroraColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AuroraColors.border),
        ),
      ),
    );
  }
}

class _TaskMetadataRow extends StatelessWidget {
  const _TaskMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  /// Builds one key/value metadata row.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AuroraColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskEmptyBlock extends StatelessWidget {
  const _TaskEmptyBlock({required this.label});

  final String label;

  /// Builds a compact task empty state.
  @override
  Widget build(BuildContext context) {
    return _TaskSectionBlock(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(label, style: const TextStyle(color: AuroraColors.muted)),
        ),
      ),
    );
  }
}

class _TaskSelectionEmpty extends StatelessWidget {
  const _TaskSelectionEmpty();

  /// Builds the task inspector no-selection state.
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Select a task or list',
        style: TextStyle(color: AuroraColors.muted),
      ),
    );
  }
}

/// Shows the task creation dialog.
Future<void> _showTaskCreateDialog(
  BuildContext context,
  AuroraAppController controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _TaskCreateDialog(controller: controller);
    },
  );
}

class _TaskCreateDialog extends StatefulWidget {
  const _TaskCreateDialog({required this.controller});

  final AuroraAppController controller;

  @override
  State<_TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends State<_TaskCreateDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  String _priority = 'normal';
  bool _linkMemory = false;

  /// Cleans up dialog controllers.
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _topics.dispose();
    super.dispose();
  }

  /// Builds the task creation dialog.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Task'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TaskTextField(controller: _title, label: 'Title'),
            const SizedBox(height: 10),
            _TaskTextField(
              controller: _description,
              label: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            _TaskDropdown(
              value: _priority,
              values: _taskPriorities,
              tooltip: 'Priority',
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 10),
            _TaskTextField(controller: _topics, label: 'Topics'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Link selected memory'),
              value: _linkMemory,
              onChanged: widget.controller.selectedMemory == null
                  ? null
                  : (value) => setState(() => _linkMemory = value ?? false),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }

  /// Creates the dialog task.
  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }
    await widget.controller.createTaskFromUi(
      title,
      description: _description.text.trim(),
      priority: _priority,
      topics: _splitTaskList(_topics.text),
      linkSelectedMemory: _linkMemory,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Shows the named-list creation dialog.
Future<void> _showListCreateDialog(
  BuildContext context,
  AuroraAppController controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _ListCreateDialog(controller: controller);
    },
  );
}

class _ListCreateDialog extends StatefulWidget {
  const _ListCreateDialog({required this.controller});

  final AuroraAppController controller;

  @override
  State<_ListCreateDialog> createState() => _ListCreateDialogState();
}

class _ListCreateDialogState extends State<_ListCreateDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _topics = TextEditingController();
  bool _linkMemory = false;

  /// Cleans up dialog controllers.
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _topics.dispose();
    super.dispose();
  }

  /// Builds the named-list creation dialog.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create List'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TaskTextField(controller: _name, label: 'Name'),
            const SizedBox(height: 10),
            _TaskTextField(
              controller: _description,
              label: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            _TaskTextField(controller: _topics, label: 'Topics'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Link selected memory'),
              value: _linkMemory,
              onChanged: widget.controller.selectedMemory == null
                  ? null
                  : (value) => setState(() => _linkMemory = value ?? false),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }

  /// Creates the dialog list.
  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    await widget.controller.createTaskListFromUi(
      name: name,
      description: _description.text.trim(),
      topics: _splitTaskList(_topics.text),
      linkSelectedMemory: _linkMemory,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Shows the named-list item creation dialog.
Future<void> _showListItemCreateDialog(
  BuildContext context,
  AuroraAppController controller,
  WorkspaceTaskList list,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _ListItemCreateDialog(controller: controller, list: list);
    },
  );
}

class _ListItemCreateDialog extends StatefulWidget {
  const _ListItemCreateDialog({required this.controller, required this.list});

  final AuroraAppController controller;
  final WorkspaceTaskList list;

  @override
  State<_ListItemCreateDialog> createState() => _ListItemCreateDialogState();
}

class _ListItemCreateDialogState extends State<_ListItemCreateDialog> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _dueAt = TextEditingController();
  bool _linkMemory = false;
  String _message = '';

  /// Cleans up dialog controllers.
  @override
  void dispose() {
    _text.dispose();
    _dueAt.dispose();
    super.dispose();
  }

  /// Builds the list item creation dialog.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TaskTextField(controller: _text, label: 'Item text'),
            const SizedBox(height: 10),
            _TaskTextField(controller: _dueAt, label: 'Due date'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Link selected memory'),
              value: _linkMemory,
              onChanged: widget.controller.selectedMemory == null
                  ? null
                  : (value) => setState(() => _linkMemory = value ?? false),
            ),
            if (_message.isNotEmpty)
              Text(_message, style: const TextStyle(color: AuroraColors.coral)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _create, child: const Text('Add')),
      ],
    );
  }

  /// Creates the dialog item.
  Future<void> _create() async {
    final dueAt = _parseTaskDateInput(_dueAt.text);
    if (_dueAt.text.trim().isNotEmpty && dueAt == null) {
      setState(() => _message = 'Due date could not be parsed');
      return;
    }
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _message = 'Item text is required');
      return;
    }
    await widget.controller.addTaskListItemFromUi(
      listId: widget.list.id,
      text: text,
      dueAt: dueAt,
      linkSelectedMemory: _linkMemory,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Confirms a task write operation.
Future<bool> _confirmTaskWrite(BuildContext context, String message) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Confirm Change'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
  return approved ?? false;
}

/// Selects the target for a review recommendation.
void _selectRecommendationTarget(
  AuroraAppController controller,
  TaskReviewRecommendation recommendation,
) {
  if (recommendation.targetType == 'task') {
    controller.selectTask(recommendation.targetId);
    return;
  }
  if (recommendation.targetType == 'list') {
    controller.selectTaskList(recommendation.targetId);
    return;
  }
  if (recommendation.targetType == 'list_item') {
    for (final list in controller.taskLists) {
      if (list.items.any((item) => item.id == recommendation.targetId)) {
        controller.selectTaskList(list.id, itemId: recommendation.targetId);
        return;
      }
    }
  }
}

/// Returns whether a task matches a panel query.
bool _matchesTask(WorkspaceTask task, String query) {
  return _matchesText(
    '${task.title} ${task.description} ${task.status} ${task.priority} '
    '${task.sourceLabel} ${task.topics.join(' ')}',
    query,
  );
}

/// Returns whether a named list matches a panel query.
bool _matchesTaskList(WorkspaceTaskList list, String query) {
  return _matchesText(
    '${list.name} ${list.description} ${list.sourceLabel} '
    '${list.topics.join(' ')} ${list.items.map((item) => item.text).join(' ')}',
    query,
  );
}

/// Returns whether a review recommendation matches a panel query.
bool _matchesRecommendation(
  TaskReviewRecommendation recommendation,
  String query,
) {
  return _matchesText(
    '${recommendation.kind} ${recommendation.severity} '
    '${recommendation.targetType} ${recommendation.title} '
    '${recommendation.message} ${recommendation.proposedAction}',
    query,
  );
}

/// Returns whether text contains every query character in order.
bool _matchesText(String value, String query) {
  final normalizedValue = value.toLowerCase();
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return true;
  }
  var cursor = 0;
  for (final codeUnit in normalizedQuery.codeUnits) {
    cursor = normalizedValue.indexOf(String.fromCharCode(codeUnit), cursor);
    if (cursor == -1) {
      return false;
    }
    cursor++;
  }
  return true;
}

/// Toggles one filter value.
List<String> _toggleFilterValue(List<String> values, String value) {
  if (values.contains(value)) {
    return values.where((item) => item != value).toList();
  }
  return <String>[...values, value];
}

/// Splits comma-delimited task labels.
List<String> _splitTaskList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

/// Parses a human-entered task date.
DateTime? _parseTaskDateInput(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return null;
  }
  final direct = DateTime.tryParse(text);
  if (direct != null) {
    return direct;
  }
  final spaced = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (spaced != null) {
    return spaced;
  }
  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (dateOnly == null) {
    return null;
  }
  return DateTime(
    int.parse(dateOnly.group(1)!),
    int.parse(dateOnly.group(2)!),
    int.parse(dateOnly.group(3)!),
  );
}

/// Formats a nullable task date.
String _formatTaskDate(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Formats a nullable task timestamp.
String _formatTaskDateTime(DateTime? value) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// Converts controlled task vocabulary to readable labels.
String _taskLabel(String value) {
  if (value.isEmpty) {
    return '';
  }
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
