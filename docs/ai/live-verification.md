# Live Verification

This note captures the exact steps used to perform a live verification of the Flutter provider screen after wiring it to the control plane provider API.

## Goal

Launch the UI, navigate to the `Providers` screen, and confirm that provider CRUD and live verification are flowing through the control plane.

## Important Context

- The provider screen now loads from the control plane admin API instead of seed data.
- The default UI client expects the control plane at `http://127.0.0.1:8080`.
- If the control plane requires an admin token, pass it into Flutter with `--dart-define=CONTROL_PLANE_ADMIN_TOKEN=...`.
- The existing widget test already covers basic navigation to `Providers`.

## Prerequisites

- Flutter installed and working.
- Chrome installed.
- A runnable control plane serving the new provider admin routes.
- Permission to let Flutter access its SDK cache if running inside a sandboxed agent environment.

## Fast Verification

From `/home/doug/dev/agentawesome/ui`:

```bash
flutter pub get
flutter test test/widget_test.dart
```

This confirms the shell renders and the test can navigate to the `Providers` section with the in-test provider API.

## Full Live Verification

From `/home/doug/dev/agentawesome/ui`:

1. Start the control plane locally so the provider API is reachable.

2. Build the web app.

```bash
flutter build web \
  --dart-define=CONTROL_PLANE_BASE_URL=http://127.0.0.1:8080
```

3. Serve the built app locally.

```bash
python3 -m http.server 8123 --directory build/web
```

4. In a second terminal, launch Chrome with DevTools enabled against the local app.

```bash
google-chrome --headless=new \
  --remote-debugging-port=9222 \
  --user-data-dir=/home/doug/dev/agentawesome/ui/build/chrome-provider-pilot \
  http://127.0.0.1:8123
```

5. Open the app in a browser, or drive it through Chrome DevTools.

6. Navigate from `Dashboard` to `Providers` using the left rail cloud icon.

## What To Confirm

The live provider screen should show:

- A provider loaded from the control plane response.
- Title: `<alias> Provider Settings`
- Actions: `Save`, `Verify`, `Delete`
- Tabs: `General`, `Status`, `Models`, `Verification`, `YAML`
- Editable provider alias, adapter, base URL, API key env var, and model rows
- The `Verification` tab should update after pressing `Verify`
- The `YAML` tab should render a provider YAML preview from the current editor state

Optional live checks:

- Create a new provider with the top-bar `New` action and confirm it appears in the selector.
- Change the adapter or endpoint, press `Save`, and confirm the control plane persists the change.
- Delete a provider and confirm it disappears from the selector after the control plane responds.

## Capturing Evidence

During the last successful verification, screenshots were saved to:

- [ai-dashboard.png](/home/doug/dev/agentawesome/ui/build/ai-dashboard.png)
- [ai-providers.png](/home/doug/dev/agentawesome/ui/build/ai-providers.png)
- [ai-providers-lower.png](/home/doug/dev/agentawesome/ui/build/ai-providers-lower.png)

## Cleanup

Stop the local server and Chrome process when finished.

## Notes

- If Flutter fails with SDK cache write errors, rerun with permissions that allow writes under the Flutter SDK install.
- If the provider screen shows a control-plane error, verify the control plane is running and the `CONTROL_PLANE_BASE_URL` value matches it.
- If port `8123` is already in use, choose another local port and update the Chrome URL to match.
