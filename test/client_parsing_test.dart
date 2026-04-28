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
            'title': 'Preference',
            'summary': 'Doug likes concise UI.',
            'kind': 'profile_fact',
            'topics': <String>['ui'],
            'source': <String, dynamic>{'system': 'chat', 'id': '1'},
          },
        ],
      });

      expect(records.single.title, 'Preference');
      expect(records.single.sourceLabel, 'chat:1');
    });

    test('parses workspace tasks', () {
      final tasks = parseWorkspaceTasks(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'task-1',
          'title': 'Draft brief',
          'status': 'open',
        },
        <String, dynamic>{
          'id': 'task-2',
          'title': 'Send brief',
          'status': 'done',
        },
      ]);

      expect(tasks.length, 2);
      expect(tasks.first.active, isTrue);
      expect(tasks.last.done, isTrue);
    });
  });
}
