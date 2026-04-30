/// Tests ADK and MCP response parsing used by the Aurora UI.
library;

import 'package:agentawesome_ui/clients/assistant_client.dart';
import 'package:agentawesome_ui/clients/mcp_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs parser coverage for client helpers.
void main() {
  group('assistant parsing', () {
    test('parses text events', () {
      final event = parseAssistantEvent(<String, dynamic>{
        'id': 'event-1',
        'author': 'assistant',
        'partial': true,
        'content': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': 'Hello'},
          ],
        },
      });

      expect(event.id, 'event-1');
      expect(event.text, 'Hello');
      expect(event.partial, isTrue);
    });

    test('parses SSE error events', () {
      final event = parseSseAssistantEvent(
        'error',
        '{"error":"provider does not support streaming"}',
      );

      expect(event.author, 'Runtime');
      expect(event.errorMessage, 'provider does not support streaming');
    });

    test('parses tool activity events', () {
      final event = parseAssistantEvent(<String, dynamic>{
        'id': 'event-2',
        'author': 'assistant',
        'content': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'functionCall': <String, dynamic>{
                'id': 'call-1',
                'name': 'search_catalog',
                'args': <String, dynamic>{},
              },
            },
          ],
        },
      });

      expect(event.toolActivity?.name, 'search_catalog');
      expect(event.confirmation, isNull);
    });

    test('parses tool response errors', () {
      final event = parseAssistantEvent(<String, dynamic>{
        'id': 'event-tool-error',
        'author': 'assistant',
        'content': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'functionResponse': <String, dynamic>{
                'id': 'call-1',
                'name': 'create_task',
                'response': <String, dynamic>{
                  'error': 'tool requires confirmation',
                },
              },
            },
          ],
        },
      });

      expect(event.toolActivity?.name, 'create_task');
      expect(event.toolActivity?.status, 'failed');
      expect(event.toolActivity?.summary, contains('requires confirmation'));
    });

    test('parses confirmation events', () {
      final event = parseAssistantEvent(<String, dynamic>{
        'id': 'event-3',
        'author': 'assistant',
        'content': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'functionCall': <String, dynamic>{
                'id': 'confirm-1',
                'name': 'adk_request_confirmation',
                'args': <String, dynamic>{
                  'originalFunctionCall': <String, dynamic>{
                    'id': 'call-1',
                    'name': 'create_task',
                  },
                  'toolConfirmation': <String, dynamic>{
                    'hint': 'Approve saving memory?',
                    'payload': <String, dynamic>{
                      'options': <Map<String, dynamic>>[
                        <String, dynamic>{'action': 'deny', 'label': 'Deny'},
                        <String, dynamic>{
                          'action': 'approve_once',
                          'label': 'Approve once',
                        },
                      ],
                    },
                  },
                },
              },
            },
          ],
        },
      });

      expect(event.confirmation?.callId, 'confirm-1');
      expect(event.confirmation?.hint, 'Approve saving memory?');
      expect(event.confirmation?.options.length, 2);
      expect(event.confirmation?.toolName, 'create_task');
    });

    test('adds and hides runtime task policy text', () {
      final outbound = messageTextWithRuntimePolicy('Remind me to buy milk.');
      expect(outbound, startsWith(runtimePolicyPrefix));

      final visible = parseAssistantEvent(<String, dynamic>{
        'id': 'event-policy',
        'author': 'user',
        'content': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{'text': outbound},
          ],
        },
      });
      expect(visible.text, 'Remind me to buy milk.');

      final hidden = parseAssistantEvent(<String, dynamic>{
        'id': 'event-hidden-policy',
        'author': 'user',
        'content': <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'text':
                  '$runtimePolicyPrefix${hiddenRuntimeMessagePrefix}Create it.',
            },
          ],
        },
      });
      expect(hidden.text, isEmpty);
    });
  });

  group('mcp parsing', () {
    test('extracts structured tool content', () {
      final content = parseToolStructuredContent(<String, dynamic>{
        'jsonrpc': '2.0',
        'id': 1,
        'result': <String, dynamic>{
          'isError': false,
          'structuredContent': <String, dynamic>{'ok': true},
        },
      });

      expect(content, <String, dynamic>{'ok': true});
    });

    test('parses memory records', () {
      final records = parseMemoryRecords(<String, dynamic>{
        'primary_evidence': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'cat-1',
            'evidence_id': 'ev-1',
            'title': 'Preference',
            'summary': 'Doug likes concise UI.',
            'kind': 'profile_fact',
            'scope': 'user',
            'trust_level': 'user_asserted',
            'sensitivity': 'private',
            'status': 'active',
            'subjects': <String>['preferences'],
            'topics': <String>['ui'],
            'entity_ids': <String>['ent-1'],
            'entity_names': <String>['Doug'],
            'source': <String, dynamic>{'system': 'chat', 'id': '1'},
            'raw': <String, dynamic>{
              'path': 'evidence/ev-1.txt',
              'checksum': 'abc',
              'media_type': 'text/plain; charset=utf-8',
              'content_text': 'Doug likes concise UI.',
            },
            'relationships': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'rel-1',
                'from_id': 'cat-1',
                'type': 'refers_to',
                'to_id': 'cat-0',
                'source_id': 'ev-1',
                'trust_level': 'user_asserted',
              },
            ],
          },
        ],
      });

      expect(records.single.title, 'Preference');
      expect(records.single.evidenceId, 'ev-1');
      expect(records.single.trustLevel, 'user_asserted');
      expect(records.single.rawContent, 'Doug likes concise UI.');
      expect(records.single.sourceLabel, 'chat:1');
      expect(records.single.relationships.single.type, 'refers_to');
    });

    test('parses compiled memory pages', () {
      final page = parseCompiledMemoryPage(<String, dynamic>{
        'id': 'page-1',
        'kind': 'timeline',
        'scope': 'user',
        'title': 'ui',
        'path': 'pages/page-1.md',
        'status': 'active',
        'source_ids': <String>['ev-1'],
        'content': '# UI',
        'stale': false,
      });

      expect(page.title, 'ui');
      expect(page.sourceIds, <String>['ev-1']);
      expect(page.content, '# UI');
    });

    test('parses workspace tasks', () {
      final tasks = parseWorkspaceTasks(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'task-1',
          'title': 'Draft brief',
          'status': 'open',
          'priority': 'high',
          'topics': <String>['brief'],
          'memory_links': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'link-1',
              'memory_catalog_id': 'cat-1',
              'relationship': 'context',
            },
          ],
        },
        <String, dynamic>{
          'id': 'task-2',
          'title': 'Send brief',
          'status': 'done',
        },
      ]);

      expect(tasks.length, 2);
      expect(tasks.first.active, isTrue);
      expect(tasks.first.priority, 'high');
      expect(tasks.first.memoryLinks.single.memoryCatalogId, 'cat-1');
      expect(tasks.last.done, isTrue);
    });

    test('parses task lists and review reports', () {
      final lists = parseTaskLists(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'list-1',
          'name': 'Errands',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'item-1',
              'list_id': 'list-1',
              'text': 'Buy stamps',
              'checked': false,
            },
          ],
        },
      ]);
      final report = parseTaskReviewReport(<String, dynamic>{
        'actor': 'task_steward',
        'reviewed_tasks': 3,
        'reviewed_lists': 1,
        'summary': 'Review complete',
        'recommendations': <Map<String, dynamic>>[
          <String, dynamic>{
            'kind': 'overdue_task',
            'severity': 'high',
            'target_type': 'task',
            'target_id': 'task-1',
            'title': 'Overdue',
            'message': 'Past due',
            'proposed_action': 'Reschedule',
          },
        ],
      });

      expect(lists.single.items.single.text, 'Buy stamps');
      expect(report.reviewedTasks, 3);
      expect(report.recommendations.single.kind, 'overdue_task');
    });
  });
}
