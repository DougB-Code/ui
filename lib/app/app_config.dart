/// Defines runtime configuration for local Agent Awesome services.
library;

/// AppConfig stores endpoint and identity settings for service clients.
class AppConfig {
  /// Creates an immutable app configuration.
  const AppConfig({
    required this.agentApiBaseUrl,
    required this.memoryMcpUrl,
    required this.tasksMcpUrl,
    required this.agentAppName,
    required this.agentUserId,
  });

  /// Builds configuration from Flutter compile-time environment values.
  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      agentApiBaseUrl: String.fromEnvironment(
        'AGENT_API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8080/api',
      ),
      memoryMcpUrl: String.fromEnvironment(
        'MEMORY_MCP_URL',
        defaultValue: 'http://127.0.0.1:8090/mcp',
      ),
      tasksMcpUrl: String.fromEnvironment(
        'TASKS_MCP_URL',
        defaultValue: 'http://127.0.0.1:8091/mcp',
      ),
      agentAppName: String.fromEnvironment(
        'AGENT_APP_NAME',
        defaultValue: 'personal_pilot',
      ),
      agentUserId: String.fromEnvironment(
        'AGENT_USER_ID',
        defaultValue: 'doug',
      ),
    );
  }

  /// Base URL for the ADK REST API.
  final String agentApiBaseUrl;

  /// URL for the memory MCP JSON-RPC endpoint.
  final String memoryMcpUrl;

  /// URL for the tasks MCP JSON-RPC endpoint.
  final String tasksMcpUrl;

  /// ADK app name that hosts the configured agent.
  final String agentAppName;

  /// ADK user id used for local sessions.
  final String agentUserId;
}
