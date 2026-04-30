/// Tests runtime profile parsing for harness and MCP topologies.
library;

import 'package:agentawesome_ui/app/app_config.dart';
import 'package:agentawesome_ui/app/runtime_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs runtime profile tests.
void main() {
  test('loads profile with harness and multiple MCP kinds', () async {
    final profile = await RuntimeProfileLoader(_testConfig()).load();

    expect(profile.harness.toolConfigPath, contains('tool.yaml'));
    expect(
      profile.harness.arguments,
      containsAllInOrder(<String>[
        'web',
        '--port',
        '39850',
        'api',
        '--webui_address',
        '127.0.0.1:39850',
      ]),
    );
    expect(profile.memoryServers.single.label, 'Personal Memory');
    expect(profile.taskServers.single.label, 'Personal Tasks');
  });

  test('rejects configured profile with missing harness config', () {
    expect(
      () => RuntimeProfile.fromJson(<String, dynamic>{
        'id': 'bad',
        'label': 'Bad',
        'harness': <String, dynamic>{
          'id': 'bad-harness',
          'label': 'Bad Harness',
        },
        'mcp_servers': <Map<String, dynamic>>[],
      }),
      throwsFormatException,
    );
  });
}

AppConfig _testConfig() {
  return const AppConfig(
    agentApiBaseUrl: 'http://127.0.0.1:8080/api',
    memoryMcpUrl: 'http://127.0.0.1:8090/mcp',
    tasksMcpUrl: 'http://127.0.0.1:8091/mcp',
    agentAppName: 'personal_pilot',
    agentUserId: 'doug',
    workspaceRoot: '/home/doug/dev/agentawesome',
    autoStartLocalServices: true,
    runtimeProfilePath:
        '/home/doug/dev/agentawesome/ui/runtime_profiles/personal_assistant.json',
  );
}
