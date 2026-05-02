/// Implements the first-class task workspace panels.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/theme.dart';
import '../domain/models.dart';
import 'panels/panels.dart';
import 'task_concept_views.dart';

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

const List<String> _taskRelationTypes = <String>[
  'related_to',
  'depends_on',
  'blocks',
  'part_of',
  'same_context',
  'same_location',
  'same_person',
  'same_project',
  'same_source',
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
          title: 'Stream',
          icon: Icons.waves_outlined,
          builder: (query) => TaskConceptProjectionPanel(
            controller: controller,
            kind: TaskConceptKind.stream,
          ),
        ),
        SwitcherPanelArea(
          title: 'Terrain',
          icon: Icons.terrain_outlined,
          builder: (query) => TaskConceptProjectionPanel(
            controller: controller,
            kind: TaskConceptKind.terrain,
          ),
        ),
        SwitcherPanelArea(
          title: 'Constellation',
          icon: Icons.hub_outlined,
          builder: (query) => TaskConceptProjectionPanel(
            controller: controller,
            kind: TaskConceptKind.constellation,
          ),
        ),
        SwitcherPanelArea(
          title: 'Weave',
          icon: Icons.grid_on_outlined,
          builder: (query) => TaskConceptProjectionPanel(
            controller: controller,
            kind: TaskConceptKind.weave,
          ),
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
    return SwitcherPanel(
      areas: <SwitcherPanelArea>[
        SwitcherPanelArea(
          title: 'Task Inspector',
          icon: Icons.edit_note_outlined,
          builder: _buildInspectorArea,
        ),
        SwitcherPanelArea(
          title: 'Memory Links',
          icon: Icons.link_outlined,
          builder: _buildMemoryLinksArea,
        ),
      ],
    );
  }

  /// Builds the right-side inspector area for the selected task or list.
  Widget _buildInspectorArea(String query) {
    final task = controller.selectedTask;
    final list = controller.selectedTaskList;
    if (task != null) {
      return _TaskDetailEditor(controller: controller, task: task);
    }
    if (list != null) {
      return _TaskListInspector(controller: controller, list: list);
    }
    return const _TaskSelectionEmpty();
  }

  /// Builds the right-side memory-link area for the selected task or list.
  Widget _buildMemoryLinksArea(String query) {
    final task = controller.selectedTask;
    final list = controller.selectedTaskList;
    if (task != null) {
      return _TaskMemoryLinkPanel(
        controller: controller,
        task: task,
        query: query,
      );
    }
    if (list != null) {
      return _TaskListMemoryLinkPanel(
        controller: controller,
        list: list,
        query: query,
      );
    }
    return const _TaskSelectionEmpty();
  }
}

/// _TaskListMemoryLinkPanel links selected memory to a task list.
class _TaskListMemoryLinkPanel extends StatelessWidget {
  const _TaskListMemoryLinkPanel({
    required this.controller,
    required this.list,
    required this.query,
  });

  final AuroraAppController controller;
  final WorkspaceTaskList list;
  final String query;

  /// Builds the task-list memory-linking panel.
  @override
  Widget build(BuildContext context) {
    final selectedMemory = controller.selectedMemory;
    return _TaskMemoryLinkScaffold(
      selectedMemory: selectedMemory,
      links: _filteredLinks(list.memoryLinks, query),
      onLink: controller.tasksBusy || selectedMemory == null
          ? null
          : () => unawaited(
              controller.linkSelectedMemoryToTaskListFromUi(list.id),
            ),
      onUnlink: (link) => unawaited(
        controller.unlinkTaskListMemoryFromUi(listId: list.id, linkId: link.id),
      ),
    );
  }
}

/// _TaskMemoryLinkScaffold renders selected-memory and linked-memory sections.
class _TaskMemoryLinkScaffold extends StatelessWidget {
  const _TaskMemoryLinkScaffold({
    required this.selectedMemory,
    required this.links,
    required this.onLink,
    required this.onUnlink,
  });

  final MemoryRecord? selectedMemory;
  final List<TaskMemoryLink> links;
  final VoidCallback? onLink;
  final ValueChanged<TaskMemoryLink> onUnlink;

  /// Builds reusable selected-memory and linked-memory sections.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _TaskPanelLabel('Selected Memory')),
              Tooltip(
                message: 'Link selected memory',
                child: OutlinedButton.icon(
                  onPressed: onLink,
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Link'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TaskSelectedMemoryBlock(memory: selectedMemory),
          const SizedBox(height: 12),
          _TaskMemoryLinksBlock(links: links, onUnlink: onUnlink),
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
            const PanelEmptyBlock(label: 'No tasks match this view')
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
                  onDelete: () =>
                      unawaited(controller.deleteTaskFromUi(task.id)),
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
    return PanelSectionBlock(
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
    required this.onDelete,
  });

  final WorkspaceTask task;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback onDelete;

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
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Delete task',
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: AuroraColors.muted,
                          ),
                        ),
                      ),
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
            const PanelEmptyBlock(label: 'No named lists')
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
            const PanelEmptyBlock(label: 'No review has run yet')
          else ...<Widget>[
            PanelSectionBlock(
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
              const PanelEmptyBlock(label: 'No recommendations match')
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
          PanelSectionBlock(
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
                      child: _TaskDatePickerField(
                        controller: _dueAt,
                        label: 'Due date',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDatePickerField(
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
          PanelSectionBlock(
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
                        onDelete: () => unawaited(
                          widget.controller.deleteTaskFromUi(task.id),
                        ),
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
          PanelSectionBlock(
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
                      child: _TaskDatePickerField(
                        controller: _dueAt,
                        label: 'Due date',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDatePickerField(
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
                onPressed: widget.controller.tasksBusy
                    ? null
                    : () => unawaited(_delete()),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TaskMetadataBlock(controller: widget.controller, task: task),
          const SizedBox(height: 14),
          _TaskGraphDetailsBlock(controller: widget.controller, task: task),
        ],
      ),
    );
  }

  /// Copies selected task data into text fields.
  void _syncFromTask() {
    _title.text = widget.task.title;
    _description.text = widget.task.description;
    _topics.text = widget.task.topics.join(', ');
    _dueAt.text = _formatTaskDate(widget.task.dueAt);
    _scheduledAt.text = _formatTaskDate(widget.task.scheduledAt);
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
  const _TaskMetadataBlock({required this.controller, required this.task});

  final AuroraAppController controller;
  final WorkspaceTask task;

  /// Builds task metadata details.
  @override
  Widget build(BuildContext context) {
    return PanelSectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _TaskPanelLabel('Metadata')),
              Tooltip(
                message: 'Edit graph metadata',
                child: IconButton(
                  onPressed: controller.tasksBusy
                      ? null
                      : () => unawaited(
                          _showTaskMetadataDialog(context, controller, task),
                        ),
                  icon: const Icon(Icons.tune_outlined, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TaskMetadataRow(
            label: 'Estimate',
            value: task.estimateMinutes <= 0
                ? ''
                : '${task.estimateMinutes} min',
          ),
          _TaskMetadataRow(label: 'Energy', value: task.energyRequired),
          _TaskMetadataRow(label: 'Context', value: task.context),
          _TaskMetadataRow(label: 'Domain', value: task.domain),
          _TaskMetadataRow(label: 'Location', value: task.location),
          _TaskMetadataRow(label: 'Owner', value: task.owner),
          _TaskMetadataRow(label: 'Source', value: task.source),
          _TaskMetadataRow(
            label: 'Effort',
            value: _formatTaskScore(task.effort),
          ),
          _TaskMetadataRow(label: 'Value', value: _formatTaskScore(task.value)),
          _TaskMetadataRow(
            label: 'Urgency',
            value: _formatTaskScore(task.urgency),
          ),
          _TaskMetadataRow(label: 'Risk', value: _formatTaskScore(task.risk)),
          _TaskMetadataRow(
            label: 'Confidence',
            value: _formatTaskScore(task.confidence),
          ),
          _TaskMetadataRow(label: 'Task id', value: task.id),
          _TaskMetadataRow(label: 'Server', value: task.sourceLabel),
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

class _TaskGraphDetailsBlock extends StatelessWidget {
  const _TaskGraphDetailsBlock({required this.controller, required this.task});

  final AuroraAppController controller;
  final WorkspaceTask task;

  /// Builds relationship, suggestion, and commitment controls.
  @override
  Widget build(BuildContext context) {
    final relationSuggestions = controller.selectedTaskRelationSuggestions;
    final metadataSuggestions = controller.selectedTaskMetadataSuggestions;
    final commitmentSuggestions = controller.selectedTaskCommitmentSuggestions;
    final relations = controller.selectedTaskRelations;
    final commitments = controller.selectedTaskCommitments;
    final suggestionWidgets = <Widget>[
      for (final suggestion in relationSuggestions)
        _TaskRelationSuggestionTile(
          controller: controller,
          task: task,
          suggestion: suggestion,
        ),
      for (final suggestion in metadataSuggestions)
        _TaskMetadataSuggestionTile(
          controller: controller,
          suggestion: suggestion,
        ),
      for (final suggestion in commitmentSuggestions)
        _TaskCommitmentSuggestionTile(
          controller: controller,
          suggestion: suggestion,
        ),
    ];
    return PanelSectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _TaskPanelLabel('Graph')),
              Tooltip(
                message: 'Add relation',
                child: IconButton(
                  onPressed: controller.tasksBusy
                      ? null
                      : () => unawaited(
                          _showTaskRelationDialog(context, controller, task),
                        ),
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                ),
              ),
              Tooltip(
                message: 'Add commitment',
                child: IconButton(
                  onPressed: controller.tasksBusy
                      ? null
                      : () => unawaited(
                          _showTaskCommitmentDialog(context, controller, task),
                        ),
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TaskGraphSubsection(
            title: 'Suggestions',
            emptyLabel: 'No graph suggestions',
            children: suggestionWidgets,
          ),
          const Divider(height: 22),
          _TaskGraphSubsection(
            title: 'Relations',
            emptyLabel: 'No explicit relations',
            children: <Widget>[
              for (final relation in relations)
                _TaskRelationTile(
                  controller: controller,
                  task: task,
                  relation: relation,
                ),
            ],
          ),
          const Divider(height: 22),
          _TaskGraphSubsection(
            title: 'Commitments',
            emptyLabel: 'No first-class commitments',
            children: <Widget>[
              for (final commitment in commitments)
                _TaskCommitmentTile(
                  controller: controller,
                  task: task,
                  commitment: commitment,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskGraphSubsection extends StatelessWidget {
  const _TaskGraphSubsection({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  /// Builds one compact graph data subsection.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(emptyLabel, style: const TextStyle(color: AuroraColors.muted))
        else
          ...children,
      ],
    );
  }
}

class _TaskMetadataSuggestionTile extends StatelessWidget {
  const _TaskMetadataSuggestionTile({
    required this.controller,
    required this.suggestion,
  });

  final AuroraAppController controller;
  final TaskMetadataSuggestion suggestion;

  /// Builds one inferred metadata suggestion row.
  @override
  Widget build(BuildContext context) {
    return _TaskGraphRow(
      icon: Icons.tune_outlined,
      title: 'Fill task metadata',
      subtitle: _metadataSuggestionSummary(suggestion),
      badges: <String>['Metadata', _formatTaskScore(suggestion.confidence)],
      actions: <Widget>[
        Tooltip(
          message: 'Accept suggestion',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(
                    controller.applyTaskSuggestionFromUi(suggestion.id),
                  ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
          ),
        ),
        Tooltip(
          message: 'Dismiss suggestion',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(
                    controller.dismissTaskSuggestionFromUi(suggestion.id),
                  ),
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ],
    );
  }
}

class _TaskCommitmentSuggestionTile extends StatelessWidget {
  const _TaskCommitmentSuggestionTile({
    required this.controller,
    required this.suggestion,
  });

  final AuroraAppController controller;
  final TaskCommitmentSuggestion suggestion;

  /// Builds one inferred commitment suggestion row.
  @override
  Widget build(BuildContext context) {
    return _TaskGraphRow(
      icon: Icons.handshake_outlined,
      title: 'Create commitment',
      subtitle: _commitmentSuggestionSummary(suggestion),
      badges: <String>[
        'Commitment',
        if (suggestion.hardness.isNotEmpty) suggestion.hardness,
        _formatTaskScore(suggestion.confidence),
      ],
      actions: <Widget>[
        Tooltip(
          message: 'Accept suggestion',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(
                    controller.applyTaskSuggestionFromUi(suggestion.id),
                  ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
          ),
        ),
        Tooltip(
          message: 'Dismiss suggestion',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(
                    controller.dismissTaskSuggestionFromUi(suggestion.id),
                  ),
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ],
    );
  }
}

class _TaskRelationSuggestionTile extends StatelessWidget {
  const _TaskRelationSuggestionTile({
    required this.controller,
    required this.task,
    required this.suggestion,
  });

  final AuroraAppController controller;
  final WorkspaceTask task;
  final TaskRelationSuggestion suggestion;

  /// Builds one inferred relation suggestion row.
  @override
  Widget build(BuildContext context) {
    final otherId = suggestion.fromTaskId == task.id
        ? suggestion.toTaskId
        : suggestion.fromTaskId;
    return _TaskGraphRow(
      icon: Icons.auto_awesome_outlined,
      title: _taskTitleFor(controller, otherId),
      subtitle: suggestion.explanation,
      badges: <String>[
        _taskLabel(suggestion.relationType),
        _formatTaskScore(suggestion.confidence),
      ],
      actions: <Widget>[
        Tooltip(
          message: 'Accept suggestion',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(
                    controller.applyTaskSuggestionFromUi(suggestion.id),
                  ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
          ),
        ),
        Tooltip(
          message: 'Dismiss suggestion',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(
                    controller.dismissTaskSuggestionFromUi(suggestion.id),
                  ),
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ],
    );
  }
}

class _TaskRelationTile extends StatelessWidget {
  const _TaskRelationTile({
    required this.controller,
    required this.task,
    required this.relation,
  });

  final AuroraAppController controller;
  final WorkspaceTask task;
  final TaskRelationRecord relation;

  /// Builds one explicit relation row.
  @override
  Widget build(BuildContext context) {
    final outgoing = relation.fromTaskId == task.id;
    final otherId = outgoing ? relation.toTaskId : relation.fromTaskId;
    final direction = outgoing ? 'To' : 'From';
    return _TaskGraphRow(
      icon: outgoing ? Icons.arrow_forward : Icons.arrow_back,
      title: '$direction ${_taskTitleFor(controller, otherId)}',
      subtitle: relation.explanation,
      badges: <String>[
        _taskLabel(relation.relationType),
        relation.source.isEmpty ? 'Explicit' : _taskLabel(relation.source),
        _formatTaskScore(relation.confidence),
      ],
      actions: <Widget>[
        Tooltip(
          message: 'Delete relation',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(_deleteRelation(context, relation)),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteRelation(
    BuildContext context,
    TaskRelationRecord relation,
  ) async {
    if (!await _confirmTaskWrite(context, 'Delete this task relation?')) {
      return;
    }
    await controller.deleteTaskRelationFromUi(relation);
  }
}

class _TaskCommitmentTile extends StatelessWidget {
  const _TaskCommitmentTile({
    required this.controller,
    required this.task,
    required this.commitment,
  });

  final AuroraAppController controller;
  final WorkspaceTask task;
  final TaskCommitment commitment;

  /// Builds one first-class commitment row.
  @override
  Widget build(BuildContext context) {
    final title = commitment.project.isNotEmpty
        ? commitment.project
        : commitment.domain.isNotEmpty
        ? commitment.domain
        : task.title;
    final subtitleParts = <String>[
      if (commitment.timeWindow.isNotEmpty) commitment.timeWindow,
      if (commitment.responsibility.isNotEmpty) commitment.responsibility,
      if (commitment.promiseSource.isNotEmpty) commitment.promiseSource,
      if (commitment.consequence.isNotEmpty) commitment.consequence,
    ];
    return _TaskGraphRow(
      icon: Icons.handshake_outlined,
      title: title,
      subtitle: subtitleParts.join(' • '),
      badges: <String>[
        for (final person in commitment.people.take(3)) person,
        if (commitment.hardness.isNotEmpty) _taskLabel(commitment.hardness),
      ],
      actions: <Widget>[
        Tooltip(
          message: 'Edit commitment',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(
                    _showTaskCommitmentDialog(
                      context,
                      controller,
                      task,
                      commitment: commitment,
                    ),
                  ),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        ),
        Tooltip(
          message: 'Delete commitment',
          child: IconButton(
            onPressed: controller.tasksBusy
                ? null
                : () => unawaited(_deleteCommitment(context, commitment)),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteCommitment(
    BuildContext context,
    TaskCommitment commitment,
  ) async {
    if (!await _confirmTaskWrite(context, 'Delete this commitment?')) {
      return;
    }
    await controller.deleteTaskCommitmentFromUi(commitment);
  }
}

class _TaskGraphRow extends StatelessWidget {
  const _TaskGraphRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> badges;
  final List<Widget> actions;

  /// Builds a compact graph metadata row.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AuroraColors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AuroraColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (badges.where((badge) => badge.isNotEmpty).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final badge in badges)
                          if (badge.isNotEmpty) _TaskBadge(label: badge),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          for (final action in actions) action,
        ],
      ),
    );
  }
}

/// _TaskMemoryLinkPanel links selected memory to a task.
class _TaskMemoryLinkPanel extends StatelessWidget {
  const _TaskMemoryLinkPanel({
    required this.controller,
    required this.task,
    required this.query,
  });

  final AuroraAppController controller;
  final WorkspaceTask task;
  final String query;

  /// Builds the task memory-linking panel.
  @override
  Widget build(BuildContext context) {
    final selectedMemory = controller.selectedMemory;
    return _TaskMemoryLinkScaffold(
      selectedMemory: selectedMemory,
      links: _filteredLinks(task.memoryLinks, query),
      onLink: controller.tasksBusy || selectedMemory == null
          ? null
          : () => unawaited(controller.linkSelectedMemoryToTaskFromUi(task.id)),
      onUnlink: (link) => unawaited(
        controller.unlinkTaskMemoryFromUi(taskId: task.id, linkId: link.id),
      ),
    );
  }
}

class _TaskSelectedMemoryBlock extends StatelessWidget {
  const _TaskSelectedMemoryBlock({required this.memory});

  final MemoryRecord? memory;

  /// Builds a compact preview of the memory selected elsewhere in the app.
  @override
  Widget build(BuildContext context) {
    final record = memory;
    return PanelSectionBlock(
      child: record == null
          ? const Text(
              'No memory selected',
              style: TextStyle(color: AuroraColors.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 17,
                      color: AuroraColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (record.kind.isNotEmpty) _TaskBadge(label: record.kind),
                  ],
                ),
                if (record.summary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    record.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AuroraColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
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
          PanelSectionBlock(
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
                onPressed: controller.tasksBusy
                    ? null
                    : () => unawaited(_deleteList(context)),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete List'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PanelSectionBlock(
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
    return PanelSectionBlock(
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
    return PanelSectionBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
    return PanelBadge(label: _taskLabel(label));
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  /// Builds a compact task form field.
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

/// _TaskDatePickerField renders a task date value with a popup date picker.
class _TaskDatePickerField extends StatefulWidget {
  const _TaskDatePickerField({required this.controller, required this.label});

  /// Text controller that stores the formatted date.
  final TextEditingController controller;

  /// Field label shown in the editor.
  final String label;

  /// Creates state that can refresh suffix icons after date changes.
  @override
  State<_TaskDatePickerField> createState() => _TaskDatePickerFieldState();
}

/// _TaskDatePickerFieldState owns picker and clear interactions.
class _TaskDatePickerFieldState extends State<_TaskDatePickerField> {
  /// Builds a button-like date field backed by a date picker dialog.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final value = widget.controller.text.trim();
        final hasValue = value.isNotEmpty;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _pickDate,
            child: InputDecorator(
              isEmpty: !hasValue,
              decoration: InputDecoration(
                labelText: widget.label,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: AuroraColors.surface,
                suffixIcon: IconButton(
                  tooltip: hasValue
                      ? 'Clear ${widget.label}'
                      : 'Pick ${widget.label}',
                  onPressed: hasValue ? _clearDate : _pickDate,
                  icon: Icon(
                    hasValue ? Icons.close : Icons.calendar_today_outlined,
                    size: 18,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AuroraColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AuroraColors.border),
                ),
              ),
              child: Text(
                hasValue ? _datePickerFieldLabel(value) : 'Select date',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasValue ? AuroraColors.ink : AuroraColors.muted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Opens a date picker and writes the selected date into the text controller.
  Future<void> _pickDate() async {
    final selectedDate = _parseTaskDateInput(widget.controller.text);
    final now = DateTime.now();
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(selectedDate ?? now, firstDate, lastDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      widget.controller.text = _formatTaskDate(picked);
    });
  }

  /// Clears the selected date.
  void _clearDate() {
    setState(() {
      widget.controller.clear();
    });
  }
}

/// Returns a normalized visible label for a date picker field value.
String _datePickerFieldLabel(String value) {
  final parsed = _parseTaskDateInput(value);
  if (parsed == null) {
    return value;
  }
  return _formatTaskDate(parsed);
}

/// Returns a date constrained to a picker-supported range.
DateTime _clampDate(DateTime value, DateTime firstDate, DateTime lastDate) {
  if (value.isBefore(firstDate)) {
    return firstDate;
  }
  if (value.isAfter(lastDate)) {
    return lastDate;
  }
  return value;
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

/// Shows the graph metadata editing dialog.
Future<void> _showTaskMetadataDialog(
  BuildContext context,
  AuroraAppController controller,
  WorkspaceTask task,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _TaskMetadataDialog(controller: controller, task: task);
    },
  );
}

class _TaskMetadataDialog extends StatefulWidget {
  const _TaskMetadataDialog({required this.controller, required this.task});

  final AuroraAppController controller;
  final WorkspaceTask task;

  @override
  State<_TaskMetadataDialog> createState() => _TaskMetadataDialogState();
}

class _TaskMetadataDialogState extends State<_TaskMetadataDialog> {
  final TextEditingController _estimate = TextEditingController();
  final TextEditingController _energy = TextEditingController();
  final TextEditingController _context = TextEditingController();
  final TextEditingController _domain = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _owner = TextEditingController();
  final TextEditingController _source = TextEditingController();
  final TextEditingController _effort = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _urgency = TextEditingController();
  final TextEditingController _risk = TextEditingController();
  final TextEditingController _confidence = TextEditingController();
  String _message = '';

  /// Initializes metadata fields from the selected task.
  @override
  void initState() {
    super.initState();
    _estimate.text = widget.task.estimateMinutes <= 0
        ? ''
        : widget.task.estimateMinutes.toString();
    _energy.text = widget.task.energyRequired;
    _context.text = widget.task.context;
    _domain.text = widget.task.domain;
    _location.text = widget.task.location;
    _owner.text = widget.task.owner;
    _source.text = widget.task.source;
    _effort.text = _scoreInputText(widget.task.effort);
    _value.text = _scoreInputText(widget.task.value);
    _urgency.text = _scoreInputText(widget.task.urgency);
    _risk.text = _scoreInputText(widget.task.risk);
    _confidence.text = _scoreInputText(widget.task.confidence);
  }

  /// Cleans up metadata field controllers.
  @override
  void dispose() {
    _estimate.dispose();
    _energy.dispose();
    _context.dispose();
    _domain.dispose();
    _location.dispose();
    _owner.dispose();
    _source.dispose();
    _effort.dispose();
    _value.dispose();
    _urgency.dispose();
    _risk.dispose();
    _confidence.dispose();
    super.dispose();
  }

  /// Builds the metadata editing dialog.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Graph Metadata'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _TaskTextField(
                controller: _estimate,
                label: 'Estimate minutes',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _TaskTextField(controller: _energy, label: 'Energy'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _context, label: 'Context'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _domain, label: 'Domain'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _location, label: 'Location'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _owner, label: 'Owner'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _source, label: 'Source'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TaskTextField(
                      controller: _effort,
                      label: 'Effort 0-1',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TaskTextField(
                      controller: _value,
                      label: 'Value 0-1',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TaskTextField(
                      controller: _urgency,
                      label: 'Urgency 0-1',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TaskTextField(
                      controller: _risk,
                      label: 'Risk 0-1',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TaskTextField(
                controller: _confidence,
                label: 'Confidence 0-1',
                keyboardType: TextInputType.number,
              ),
              if (_message.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _message,
                  style: const TextStyle(color: AuroraColors.coral),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  /// Saves the edited metadata to the task service.
  Future<void> _save() async {
    final estimateText = _estimate.text.trim();
    final estimate = estimateText.isEmpty ? 0 : int.tryParse(estimateText);
    if (estimate == null || estimate < 0) {
      setState(() => _message = 'Estimate must be zero or greater');
      return;
    }
    final effort = _parseDialogScore(_effort.text);
    final value = _parseDialogScore(_value.text);
    final urgency = _parseDialogScore(_urgency.text);
    final risk = _parseDialogScore(_risk.text);
    final confidence = _parseDialogScore(_confidence.text);
    if (<double?>[effort, value, urgency, risk, confidence].contains(null)) {
      setState(() => _message = 'Scores must be between 0 and 1');
      return;
    }
    await widget.controller.updateTaskFromUi(
      taskId: widget.task.id,
      estimateMinutes: estimate,
      energyRequired: _energy.text.trim(),
      effort: effort,
      value: value,
      urgency: urgency,
      risk: risk,
      context: _context.text.trim(),
      domain: _domain.text.trim(),
      location: _location.text.trim(),
      owner: _owner.text.trim(),
      source: _source.text.trim(),
      confidence: confidence,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Shows the task relation creation dialog.
Future<void> _showTaskRelationDialog(
  BuildContext context,
  AuroraAppController controller,
  WorkspaceTask task,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _TaskRelationDialog(controller: controller, task: task);
    },
  );
}

class _TaskRelationDialog extends StatefulWidget {
  const _TaskRelationDialog({required this.controller, required this.task});

  final AuroraAppController controller;
  final WorkspaceTask task;

  @override
  State<_TaskRelationDialog> createState() => _TaskRelationDialogState();
}

class _TaskRelationDialogState extends State<_TaskRelationDialog> {
  final TextEditingController _explanation = TextEditingController();
  String _targetTaskId = '';
  String _relationType = 'related_to';

  /// Initializes the first available target task.
  @override
  void initState() {
    super.initState();
    final targets = _relationTargets;
    if (targets.isNotEmpty) {
      _targetTaskId = targets.first.id;
    }
  }

  /// Cleans up dialog controllers.
  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  List<WorkspaceTask> get _relationTargets {
    return widget.controller.workspace.tasks.where((task) {
      return task.id != widget.task.id;
    }).toList();
  }

  /// Builds the task relation creation dialog.
  @override
  Widget build(BuildContext context) {
    final targets = _relationTargets;
    return AlertDialog(
      title: const Text('Add Relation'),
      content: SizedBox(
        width: 460,
        child: targets.isEmpty
            ? const Text('Create another task before adding a relation.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: _targetTaskId.isEmpty ? null : _targetTaskId,
                    decoration: _taskDialogDecoration('Related task'),
                    isExpanded: true,
                    items: <DropdownMenuItem<String>>[
                      for (final target in targets)
                        DropdownMenuItem<String>(
                          value: target.id,
                          child: Text(
                            target.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _targetTaskId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _TaskDropdown(
                    value: _relationType,
                    values: _taskRelationTypes,
                    tooltip: 'Relation type',
                    onChanged: (value) => setState(() => _relationType = value),
                  ),
                  const SizedBox(height: 10),
                  _TaskTextField(
                    controller: _explanation,
                    label: 'Explanation',
                    maxLines: 3,
                  ),
                ],
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: targets.isEmpty ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }

  /// Saves the explicit relation to the task service.
  Future<void> _save() async {
    if (_targetTaskId.isEmpty) {
      return;
    }
    await widget.controller.upsertTaskRelationFromUi(
      fromTaskId: widget.task.id,
      toTaskId: _targetTaskId,
      relationType: _relationType,
      explanation: _explanation.text.trim(),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Shows the commitment create or edit dialog.
Future<void> _showTaskCommitmentDialog(
  BuildContext context,
  AuroraAppController controller,
  WorkspaceTask task, {
  TaskCommitment? commitment,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _TaskCommitmentDialog(
        controller: controller,
        task: task,
        commitment: commitment,
      );
    },
  );
}

class _TaskCommitmentDialog extends StatefulWidget {
  const _TaskCommitmentDialog({
    required this.controller,
    required this.task,
    this.commitment,
  });

  final AuroraAppController controller;
  final WorkspaceTask task;
  final TaskCommitment? commitment;

  @override
  State<_TaskCommitmentDialog> createState() => _TaskCommitmentDialogState();
}

class _TaskCommitmentDialogState extends State<_TaskCommitmentDialog> {
  final TextEditingController _people = TextEditingController();
  final TextEditingController _domain = TextEditingController();
  final TextEditingController _project = TextEditingController();
  final TextEditingController _timeWindow = TextEditingController();
  final TextEditingController _responsibility = TextEditingController();
  final TextEditingController _promiseSource = TextEditingController();
  final TextEditingController _hardness = TextEditingController();
  final TextEditingController _consequence = TextEditingController();

  /// Initializes commitment fields from the existing commitment when present.
  @override
  void initState() {
    super.initState();
    final commitment = widget.commitment;
    if (commitment == null) {
      _domain.text = widget.task.domain;
      _project.text = widget.task.context;
      _people.text = widget.task.owner;
      return;
    }
    _people.text = commitment.people.join(', ');
    _domain.text = commitment.domain;
    _project.text = commitment.project;
    _timeWindow.text = commitment.timeWindow;
    _responsibility.text = commitment.responsibility;
    _promiseSource.text = commitment.promiseSource;
    _hardness.text = commitment.hardness;
    _consequence.text = commitment.consequence;
  }

  /// Cleans up commitment field controllers.
  @override
  void dispose() {
    _people.dispose();
    _domain.dispose();
    _project.dispose();
    _timeWindow.dispose();
    _responsibility.dispose();
    _promiseSource.dispose();
    _hardness.dispose();
    _consequence.dispose();
    super.dispose();
  }

  /// Builds the commitment create or edit dialog.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.commitment == null ? 'Add Commitment' : 'Edit Commitment',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _TaskTextField(controller: _people, label: 'People'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _domain, label: 'Domain'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _project, label: 'Project'),
              const SizedBox(height: 10),
              _TaskTextField(controller: _timeWindow, label: 'Time window'),
              const SizedBox(height: 10),
              _TaskTextField(
                controller: _responsibility,
                label: 'Responsibility',
              ),
              const SizedBox(height: 10),
              _TaskTextField(
                controller: _promiseSource,
                label: 'Promise source',
              ),
              const SizedBox(height: 10),
              _TaskTextField(controller: _hardness, label: 'Hardness'),
              const SizedBox(height: 10),
              _TaskTextField(
                controller: _consequence,
                label: 'Consequence',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  /// Saves the commitment to the task service.
  Future<void> _save() async {
    await widget.controller.upsertTaskCommitmentFromUi(
      commitmentId: widget.commitment?.id ?? '',
      taskId: widget.task.id,
      people: _splitTaskList(_people.text),
      domain: _domain.text.trim(),
      project: _project.text.trim(),
      timeWindow: _timeWindow.text.trim(),
      responsibility: _responsibility.text.trim(),
      promiseSource: _promiseSource.text.trim(),
      hardness: _hardness.text.trim(),
      consequence: _consequence.text.trim(),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
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

/// Returns memory links filtered by the panel query.
List<TaskMemoryLink> _filteredLinks(List<TaskMemoryLink> links, String query) {
  return links.where((link) {
    return _matchesText(
      '${link.relationship} ${link.note} ${link.memoryCatalogId} '
      '${link.memoryEvidenceId}',
      query,
    );
  }).toList();
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

/// Formats a normalized score for inspector display.
String _formatTaskScore(double value) {
  if (value <= 0) {
    return '';
  }
  return '${(value * 100).round()}%';
}

/// Summarizes proposed task metadata fields for the inspector.
String _metadataSuggestionSummary(TaskMetadataSuggestion suggestion) {
  final parts = <String>[
    if (suggestion.estimateMinutes > 0) '${suggestion.estimateMinutes} min',
    if (suggestion.energyRequired.isNotEmpty) suggestion.energyRequired,
    if (suggestion.context.isNotEmpty) suggestion.context,
    if (suggestion.domain.isNotEmpty) suggestion.domain,
    if (suggestion.location.isNotEmpty) suggestion.location,
    if (suggestion.effort > 0) 'effort ${_formatTaskScore(suggestion.effort)}',
    if (suggestion.value > 0) 'value ${_formatTaskScore(suggestion.value)}',
    if (suggestion.urgency > 0)
      'urgency ${_formatTaskScore(suggestion.urgency)}',
    if (suggestion.risk > 0) 'risk ${_formatTaskScore(suggestion.risk)}',
  ];
  if (parts.isEmpty) {
    return suggestion.explanation;
  }
  return parts.join(' • ');
}

/// Summarizes proposed commitment fields for the inspector.
String _commitmentSuggestionSummary(TaskCommitmentSuggestion suggestion) {
  final parts = <String>[
    if (suggestion.domain.isNotEmpty) suggestion.domain,
    if (suggestion.project.isNotEmpty) suggestion.project,
    if (suggestion.timeWindow.isNotEmpty) suggestion.timeWindow,
    if (suggestion.responsibility.isNotEmpty) suggestion.responsibility,
    if (suggestion.promiseSource.isNotEmpty) suggestion.promiseSource,
    if (suggestion.consequence.isNotEmpty) suggestion.consequence,
  ];
  if (parts.isEmpty) {
    return suggestion.explanation;
  }
  return parts.join(' • ');
}

/// Formats a normalized score for dialog input.
String _scoreInputText(double value) {
  if (value <= 0) {
    return '';
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Parses a dialog score where blank means no explicit signal.
double? _parseDialogScore(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return 0;
  }
  final score = double.tryParse(text);
  if (score == null || score < 0 || score > 1) {
    return null;
  }
  return score;
}

/// Builds dialog field decoration consistent with task text fields.
InputDecoration _taskDialogDecoration(String label) {
  return InputDecoration(
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
  );
}

/// Resolves a task title for graph rows.
String _taskTitleFor(AuroraAppController controller, String taskId) {
  for (final task in controller.workspace.tasks) {
    if (task.id == taskId) {
      return task.title;
    }
  }
  return taskId.isEmpty ? 'Unknown task' : taskId;
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
