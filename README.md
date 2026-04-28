# Agent Awesome UI

A desktop-first Flutter app for the Aurora personal assistant workspace.

## Run

Start the personal-assistant pilot services, then run the UI:

```sh
flutter run -d linux
```

The UI reads these optional `--dart-define` values:

- `AGENT_API_BASE_URL`, default `http://127.0.0.1:8080/api`
- `MEMORY_MCP_URL`, default `http://127.0.0.1:8090/mcp`
- `TASKS_MCP_URL`, default `http://127.0.0.1:8091/mcp`
- `AGENT_APP_NAME`, default `personal_pilot`
- `AGENT_USER_ID`, default `doug`

When services are unavailable, the app renders seeded Aurora concept data and
marks the relevant connections as disconnected.
