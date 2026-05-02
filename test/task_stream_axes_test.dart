/// Verifies reusable task stream axis projection behavior.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:agentawesome_ui/domain/models.dart';
import 'package:agentawesome_ui/ui/task_stream_axes.dart';

void main() {
  group('TaskStreamAxisProjector', () {
    test('rebuckets columns while preserving row buckets by task id', () {
      final view = TaskStreamAxisProjector.project(
        _projection,
        columnAxis: TaskStreamAxisDimension.priority,
        rowAxis: TaskStreamAxisDimension.status,
      );

      expect(view.lanes.map((lane) => lane.id), <String>['high', 'normal']);
      expect(view.lanes.first.cards.map((card) => card.taskId), <String>[
        'draft',
      ]);
      expect(view.rowBucketsByTaskId['draft']!.title, 'Open');
      expect(view.rowBucketsByTaskId['approval']!.title, 'Waiting');
    });

    test('supports cost buckets without requiring explicit money data', () {
      final view = TaskStreamAxisProjector.project(
        _projection,
        columnAxis: TaskStreamAxisDimension.cost,
        rowAxis: TaskStreamAxisDimension.attention,
      );

      expect(view.lanes.map((lane) => lane.id), <String>[
        'low-cost',
        'high-switch',
      ]);
      expect(view.lanes.last.title, 'High Switch');
    });

    test('does not promote attention labels into lifecycle status buckets', () {
      final view = TaskStreamAxisProjector.project(
        const TaskStreamProjection(
          lanes: <TaskStreamLane>[
            TaskStreamLane(
              id: 'now',
              title: 'Now',
              cards: <TaskStreamCard>[
                TaskStreamCard(
                  taskId: 'bad-status',
                  title: 'Clean up status metadata',
                  status: 'Deep Focus',
                  priority: 'normal',
                  flowLane: 'Deep Focus',
                ),
              ],
            ),
          ],
        ),
        columnAxis: TaskStreamAxisDimension.attention,
        rowAxis: TaskStreamAxisDimension.status,
      );

      expect(view.lanes.single.title, 'Deep Focus');
      expect(view.rowBucketsByTaskId['bad-status']!.title, 'Other status');
      expect(view.rowBucketsByTaskId['bad-status']!.title, isNot('Deep Focus'));
    });
  });
}

const _projection = TaskStreamProjection(
  lanes: <TaskStreamLane>[
    TaskStreamLane(
      id: 'now',
      title: 'Now',
      subtitle: 'Ready work',
      cards: <TaskStreamCard>[
        TaskStreamCard(
          taskId: 'draft',
          title: 'Draft proposal',
          status: 'open',
          priority: 'high',
          context: 'Focus',
          flowLane: 'Deep Work',
          project: 'Pilot',
          domain: 'Work',
          owner: 'Doug',
          contextSwitchCost: 0.2,
          estimateMinutes: 45,
        ),
      ],
    ),
    TaskStreamLane(
      id: 'later',
      title: 'Later',
      subtitle: 'This week',
      cards: <TaskStreamCard>[
        TaskStreamCard(
          taskId: 'approval',
          title: 'Follow up on approval',
          status: 'waiting',
          priority: 'normal',
          context: 'Admin',
          flowLane: 'Waiting',
          costLabel: 'High switch',
          costScore: 0.8,
          estimateMinutes: 10,
        ),
      ],
    ),
  ],
);
