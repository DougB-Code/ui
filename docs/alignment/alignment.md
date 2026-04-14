# UI Alignment Report

## Scope

This report compares the current `ui` against the capabilities and architecture expressed by:

- the harness in `../harness`
- the control plane in `../control-plane`

The harness and control plane are treated as the current source of truth for execution behavior, state, and product boundaries. That does not mean they are frozen; it means the UI should be judged by how well it represents and operates those systems as they exist today.

## Executive Summary

The UI is now materially aligned for beta testing, and the scoped alignment plan is effectively complete.

It has moved from a mostly prototype shell to a live beta operator console. The current beta path is meaningfully control-plane-backed for operational summaries, runs, approvals, artifacts, audits, metrics, tenants, users, memberships, installations, conversations, channel routes, and harness configuration for providers, agents, tools, and workflows.

The remaining differences are now mostly about depth and ergonomics rather than missing beta-critical surfaces:

- harness config authoring is still deliberately YAML-first rather than schema-form-first
- some control-plane entity areas remain inspect-heavy compared to the full backend lifecycle model
- deployed-mode awareness is now in place, but future cloud-native workflows can still be broadened

## High-Level Alignment

- `Providers`: strong alignment
- `Harness agent configuration`: strong alignment
- `Harness tool configuration`: strong alignment
- `Harness workflow authoring`: strong alignment
- `Run operations`: strong alignment
- `Approvals, artifacts, audits, metrics`: strong alignment
- `Tenants, users, installations, conversations, channel routes`: strong alignment
- `Cloudflare / deployed control-plane model`: aligned for current beta scope

## What Is Aligned Today

### 1. Provider management is real

The provider screen is the clearest example of genuine alignment:

- The UI calls the control-plane admin provider API in `ui/lib/provider_catalog_api.dart`.
- The control plane exposes matching routes in `control-plane/internal/controlplane/http.go`.
- Those routes mutate the harness `provider.yaml` through the control plane's provider catalog manager.
- The UI reflects several real harness provider fields: alias, adapter, base URL, API key env var, allowed hosts, model enablement, verification bits, timeout, API version, account ID, and gateway ID.

This is a good pattern because the UI is not editing harness files directly. It is asking the control plane to manage harness config on its behalf.

### 2. Run operations are real

The beta shell now has a live operations surface:

- operational summary
- run list
- run filters
- pending approval queue
- run detail
- approval state
- approval resolution
- operator actions
- artifacts
- audits
- dedicated artifact views
- dedicated audit views

This means the UI can now answer the core operational questions the earlier report identified as missing.

### 3. Harness agent and tool management are now real

The beta shell now exposes live harness config surfaces for more than providers:

- harness agents
- harness tools
- raw YAML round-tripping through the control plane
- parsed summaries for lead agent, templates, policies, tool groups, external tools, and MCP servers
- validation-backed save flows that call the real harness checks before persistence

This is an important architectural step because the UI is still not editing files directly. It is using control-plane admin routes that load, validate, and persist `agent.yaml` and `tool.yaml` on behalf of the operator.

### 4. Harness workflow management is now real

The beta shell now exposes a live workflow authoring surface through the control plane:

- workflow list and detail
- workflow-level limits
- rule set summaries
- node-level schema summaries
- transition graph derived from the real node transitions
- raw `workflow.yaml` round-tripping
- validation-backed save flows that run the real harness workflow checks

This closes the earlier gap where workflow authoring was entirely absent from the live beta shell.

### 5. The shell now reflects the control-plane-first architecture much more clearly

The left rail is now split into:

- `Operations`
- `Control Plane`
- `Harness Config`

That is much closer to the intended system boundary than the older flat config-editor shell.

### 6. The control-plane entity model is now visible

The UI now exposes live lists for:

- tenants
- users
- memberships
- control-plane agents
- installations
- conversations
- channel routes

This is no longer just an inspection surface. The beta path now includes detail and live management for tenants, agents, and installations, while users and memberships remain inspection-oriented.

### 7. Conversation state and route-aware health are now real

The UI now exposes live conversation detail with:

- recent turns
- pending execution state
- latest approval request
- latest run
- route/install health

That closes one of the biggest earlier gaps between the UI and the control plane's conversation-centric model.

### 8. The shell is now deployed-mode aware

The beta shell now differentiates local and deployed control-plane modes and hides local-only provider catalog mutation when Cloudflare mode is active.

## Major Deltas

### 1. Harness session and workflow state are now exposed

This was the last major harness-side mismatch, and it is now closed for beta.

The harness persists much more execution detail than the UI currently shows, including:

- session status
- current workflow node
- node visit and failure counts
- node results
- blockers
- waiting reasons
- artifact directories
- persisted structured outputs

That is visible in:

- `harness/internal/core/workflow_types.go`
- `harness/docs/user/modules/ROOT/pages/reference/sessions-and-state.adoc`

The UI now shows live harness execution state on run detail, including:

- session status
- current workflow node
- node visit and failure counts
- node results
- blockers
- waiting reasons
- execution file references
- persisted structured outputs when present

That means the UI now covers both workflow authoring and workflow/runtime inspection through the control plane.

### 2. Harness configuration parity beyond providers is now broad, but still YAML-first

Real harness tool configuration supports:

- reusable tool groups
- external tools
- MCP servers
- trust gating
- process lifecycle
- stdio vs HTTP transport
- startup and shutdown timeouts
- working directories
- env handling
- temp-file wiring
- per-platform overrides
- tool naming and MCP prefixing

That is visible in:

- `harness/internal/appconfig/toolconfig/types.go`
- `harness/docs/user/modules/ROOT/pages/reference/providers-and-tools.adoc`

The beta shell no longer presents misleading seed-data `Agents`, `Tools`, and `Workflows` sections as active product surfaces, which is an improvement. The remaining parity gap is no longer basic access to agent, tool, and workflow config. It is the lack of richer schema-aware editing beyond the safe raw-YAML path.

What changed is that the UI can now safely inspect and edit the full `agent.yaml`, `tool.yaml`, and `workflow.yaml` documents through control-plane-backed raw YAML editors with live validation. What remains missing is deeper schema-specific authoring affordances beyond the raw-editor model.

### 3. Run operations now include execution inspection

The control plane already has a rich run lifecycle:

- queued
- running
- waiting for approval
- waiting for user
- blocked
- completed
- failed
- cancelled

It also tracks:

- result summaries
- operator actions
- runtime profile snapshots
- approvals
- artifacts
- conversation pending state

The UI now covers the main operational model, including:

- harness session state
- workflow state and node results
- pending questions and blockers as first-class execution objects
- approval resolution and evidence inspection

What remains is broader operator workflow depth, not missing visibility into the runtime model.

### 4. Control-plane entity management is real, but still selective

The beta UI now supports live detail and management for the most operationally important mutable entities:

- tenants
- control-plane agents
- installations

But the broader admin surface is still narrower than the backend model. Users and memberships are still inspect-only, and deeper onboarding, template-rebinding, and other lifecycle flows are not yet exposed.

### 5. Conversation detail is now real, but broader channel lifecycle tooling is still shallow

The UI now shows:

- recent turns
- pending execution state
- latest approval request
- latest run
- route and install health

But broader onboarding and channel lifecycle tooling is still shallow compared to the control plane's long-term Slack-first product model.

### 6. Deployed-mode awareness is now aligned for beta

The provider screen assumes:

- a local control plane
- `CONTROL_PLANE_BASE_URL`
- optional `X-Admin-Token`
- the Go control plane's local provider catalog routes

But the deployed control-plane direction is Cloudflare-first and asynchronous, and provider catalog management is explicitly unavailable in Cloudflare builds:

- `control-plane/internal/controlplane/harness_provider_catalog_cloud.go`
- `control-plane/docs/architecture/cloudflare-deployment.md`

The shell now adapts to deployment mode, labels local-only harness config surfaces, and shows explicit unavailable messaging when local harness inspection is not possible in deployed builds. That is sufficient for the current beta scope even though broader cloud-native admin flows can still expand later.

## Areas Where The UI Is Closest To The North Star

If we separate "good direction" from "current completeness," the strongest bets are:

- Provider administration flowing through the control plane rather than direct file edits.
- A real run-operations surface with summary and approval queue instead of placeholder observability.
- A shell that is now explicitly split across operations, control-plane, and harness-config concerns.

## Recommended Realignment

### 1. Split the UI into explicit architectural domains

This has mostly been implemented. The current need is to keep deepening the separation so each domain has the right default workflows and level of detail:

- `Control Plane`
- `Harness Config`
- `Run Operations`

That architectural boundary is now legible, but still incomplete in depth.

### 2. Make control-plane entities first-class before expanding more harness editors

This is now implemented well enough for beta operations. The remaining gap is breadth of admin actions, not whether the model is visible.

### 3. Rework harness authoring screens to match actual schemas

This is now implemented at the structural level. The remaining work is depth and ergonomics rather than basic parity:

- harness agents should reflect role templates, tool groups, policies, and lead/worker behavior
- tools should model external tools and MCP servers separately
- workflows should model structured transitions and governance fields, not just node links

### 4. Deepen the real run detail and operator workflow

A real run detail should show:

- run status
- tenant / agent / actor / source
- runtime profile snapshot
- wait reason or blocker
- approval state
- result summary
- artifacts
- audit entries
- harness session / workflow state

Most of this now exists in the shipped beta shell. The next work here is broader operator flow depth beyond approval resolve.

### 5. Decide what belongs in the control plane vs what should remain harness-local

That decision is now effectively made for the current beta shell:

- the control plane is the authoritative API for local harness config authoring for providers, agents, tools, and workflows
- Cloudflare mode still hides these local-only mutation surfaces when they are unavailable

The remaining question is no longer ownership. It is how far to deepen these authoring flows beyond safe YAML-first editing.

## Suggested Priority Order

1. Deepen operator workflows beyond approval resolution and inspection.
2. Broaden control-plane admin actions for users, memberships, and onboarding flows.
3. Improve schema-aware harness authoring ergonomics beyond the raw-YAML-first model.
4. Expand cloud-native admin flows where local-only harness config management is intentionally unavailable.

## Bottom Line

The current UI is no longer just a prototype shell. It is now a live beta console that is aligned to the current harness and control-plane architecture for the scoped beta surface.

Today it behaves like:

- a real operations surface for runs, approvals, artifacts, audits, and metrics
- a real inspection surface for core control-plane entities
- real harness configuration administration for providers, agents, tools, and workflows
- an intentionally narrowed beta shell with misleading seed-data sections removed

The system underneath it still has room for deeper lifecycle tooling and richer UX, but the next step is no longer "replace fake UI with real UI" for the beta shell. That work is done. The next step is deepening the real surfaces that now exist so they match the product and execution model more completely:

- the control plane as the product brain
- the harness as the execution engine
- runs as the main operational object
- harness config as a narrower, explicit admin concern

## Phased Implementation Plan

This plan is sequenced to maximize real alignment early, avoid building more seed-data UI, and keep the control plane as the product-facing source of truth.

## Guiding Principles

- Prefer live control-plane-backed surfaces over richer local mocks.
- Treat `Run` as the primary operational object.
- Keep harness configuration as an explicit admin/operator surface, not the default product experience.
- Do not deepen the workflow editor until it can represent the real harness schema.
- Replace synthetic dashboard metrics with real control-plane or harness-derived data as soon as possible.

## Implementation Checklist

Status key:

- `[x]` implemented
- `[ ]` not implemented
- `Phase status` shows the current aggregate state for the phase

### Phase 0 status: complete

- [x] Split navigation into explicit `Operations`, `Control Plane`, and `Harness Config` domains.
- [x] Make `Runs` the default landing surface.
- [x] Move `Providers` under `Harness Config`.
- [x] Label the agent surface as control-plane-first instead of leaving it semantically ambiguous.
- [x] Remove major seed-data sections from the beta shell so live sections are clearly live.
- [x] Keep live API clients in bounded modules (`operations_api.dart`, `control_plane_api.dart`, `provider_catalog_api.dart`).
- [x] Move most feature state out of `ui/lib/main.dart`.
- [x] Add explicit local-vs-deployed environment awareness.

### Phase 1 status: complete

- [x] Build a real `Runs` list view with tenant, agent, actor, invocation mode, timestamps, status, and result summary.
- [x] Build run detail with source context, runtime profile snapshot, wait state, operator actions, artifact manifest, and approval state.
- [x] Add live status filters for queued, running, waiting approval, waiting user, blocked, completed, failed, and cancelled.
- [x] Make run operations the default first screen of the product.

### Phase 2 status: complete

- [x] Add a dedicated pending approval queue to the live operator UI.
- [x] Add approval detail and live approve/reject actions.
- [x] Replace synthetic dashboard cards with real metrics and run status counts.
- [x] Show artifacts and audit trail on live run detail.
- [x] Add dedicated artifact list/detail screens outside run detail.
- [x] Add dedicated audit log filtering screens outside run detail.

### Phase 3 status: complete

- [x] Add a real `Control Plane` UI domain.
- [x] Expose live tenants, users, memberships, control-plane agents, and installations.
- [x] Add detail and management flows for the mutable control-plane entities beyond inspection.

### Phase 4 status: complete

- [x] Expose live conversations and channel routes.
- [x] Add conversation detail with recent turns, pending execution state, latest approval request, and latest run.
- [x] Add route-aware onboarding and install health surfaces.

### Phase 5 status: complete

- [x] Keep provider management live through the control plane.
- [x] Add real harness agents/tooling surfaces only if the control plane is meant to own them.
- [x] Add validation-backed harness config editing beyond providers.

### Phase 6 status: complete

- [x] Replace the workflow sketcher with a schema-faithful harness workflow editor.

### Phase 7 status: complete

- [x] Add deployed-mode and Cloudflare-aware feature availability.

## Phase 0: Foundation And Information Architecture

### Goal

Reshape the UI shell so it reflects the actual architecture before more feature work lands.

### UI changes

- Split navigation into explicit domains:
  - `Operations`
  - `Control Plane`
  - `Harness Config`
- Move the current `Runs` section into `Operations` and make it the default landing area.
- Move `Providers` under `Harness Config`.
- Reframe current `Agents` so there is no ambiguity between control-plane agents and harness agents.
- Mark any remaining non-live sections as `Prototype` or `Coming soon` instead of presenting them as active product surfaces.

### Supporting work

- Extract API clients and screen state out of `ui/lib/main.dart` into feature modules.
- Define shared UI models for:
  - runs
  - approvals
  - artifacts
  - audits
  - tenants
  - control-plane agents
- Add a simple environment/config layer for local vs deployed control-plane modes.

### Exit criteria

- The shell clearly distinguishes control-plane surfaces from harness-config surfaces.
- No major section title implies a live integration when it is still seed-data only.
- `main.dart` is no longer the long-term home for all application state.

## Phase 1: Run Operations First

### Goal

Make the UI useful as an operational console even before full configuration parity exists.

### Why this phase comes first

The control plane already has the richest real model around runs, approvals, artifacts, and statuses. This is the fastest path to a UI that reflects the actual system rather than a design mock.

### UI changes

- Build a real `Runs` list view with:
  - status
  - tenant
  - agent
  - actor
  - invocation mode
  - created / started / completed timestamps
  - result summary
- Build a run detail view with:
  - source context
  - runtime profile snapshot
  - wait reason or blocker
  - operator actions
  - artifact manifest reference
  - approval state when present
- Add status filters for:
  - queued
  - running
  - waiting approval
  - waiting user
  - blocked
  - completed
  - failed
  - cancelled

### Backend/API needs

The control plane already exposes run-related admin routes. If list/detail endpoints are incomplete for UI use, add thin read endpoints rather than inventing client-side reconstruction.

### Exit criteria

- A user can answer "what is happening in the system right now?" from the UI.
- Placeholder `Runs` content is removed.
- The UI’s default experience is centered on real runtime state.

## Phase 2: Approvals, Artifacts, Audits, And Metrics

### Goal

Turn the UI into a genuine operator console around governance and evidence.

### UI changes

- Add approval queue and approval detail views.
- Add artifact list/detail views with:
  - tenant
  - agent
  - run
  - kind
  - retention
  - reference
- Add audit log views with filtering by:
  - tenant
  - agent
  - user
  - run
- Replace synthetic dashboard cards with real operational summaries:
  - run status counts
  - approval latency
  - run latency
  - integration errors
  - installation counts

### Backend/API needs

- Confirm admin read routes for approvals and audits are sufficient for list/detail use.
- Add summary endpoints only where they simplify UI loading patterns.

### Exit criteria

- Operators can inspect pending approvals, produced artifacts, and historical audits from the UI.
- Dashboard cards are backed by real control-plane data.
- The dashboard stops presenting fabricated trends.

## Phase 3: Control-Plane Entity Management

### Goal

Expose the real product model managed by the control plane.

### UI changes

- Add tenants screen:
  - list
  - detail
  - status
  - region
  - default template
  - retention / budget summaries
- Add users and memberships screens.
- Add control-plane agents screen:
  - tenant
  - template
  - status
  - enabled capabilities
  - denied capabilities
  - integration bindings
  - approval override
  - runtime limits override
- Add installations screen:
  - provider type
  - workspace binding
  - tenant mapping
  - default agent mapping
  - allowed channels / users / agents

### Important naming rule

At this phase, the UI should explicitly label this surface `Control-plane agents` to avoid confusion with harness runtime roles.

### Exit criteria

- The UI can manage the product entities that the control plane already treats as first-class.
- The user can inspect tenant, user, agent, and installation state without dropping to raw API calls.

## Phase 4: Conversations, Routes, And Channel-Aware Operations

### Goal

Expose the conversation-centric model that sits above the harness.

### UI changes

- Add conversations view with:
  - conversation id
  - tenant
  - agent
  - kind
  - status
  - latest run
- Add channel route views with:
  - provider type
  - installation
  - channel
  - thread
  - mapped conversation
- Add conversation detail with:
  - recent turns
  - pending execution state
  - latest approval request
  - latest run
- Add onboarding/install health surfaces for Slack-first flows.

### Backend/API needs

If list/detail APIs for conversations and routes do not exist yet, add them here. This phase should not rely on stitching together unrelated endpoints in the client.

### Exit criteria

- The UI reflects the control plane's conversation and route model rather than looking like a standalone config console.
- Slack and future channel adapters fit naturally into the product model shown by the UI.

## Phase 5: Harness Configuration Parity Beyond Providers

### Goal

Expand harness authoring carefully, but only as an explicit admin/operator concern.

### Scope decision

This decision has now effectively been made for beta: the control plane owns provider, agent, tool, and workflow config management in local mode.

The implementation uses the same pattern as providers:

- the UI does not edit harness files directly
- the control plane loads and persists the document
- validation runs through the real harness before save
- the editor round-trips full YAML so unknown fields are not silently dropped

### Implemented UI changes

- Add a harness agents screen that reflects real harness role config:
  - lead agent
  - agents
  - templates
  - policy presets
  - subagent settings
- Add a harness tools screen with separate views for:
  - tool groups
  - external tools
  - MCP servers
- Add validation feedback directly from control-plane-backed harness validation.
- Keep the actual edit surface as raw YAML so the UI can safely round-trip the full schema.

### Exit criteria

- No harness config screen is backed by seed-only data.
- The UI schema matches the harness config schema closely enough that saving through the UI cannot silently discard important fields.

## Phase 6: Workflow Authoring Parity

### Goal

Replace the current workflow sketcher with a workflow editor that actually represents the harness runtime model.

### Implemented UI changes

- Rebuild the workflow editor around the real schema:
  - structured transitions: `success`, `failure`, `blocked`
  - node `with`
  - input contracts
  - output contracts
  - include-node-results
  - input mappings
  - prompt overlays
  - gate policy
  - policy gate
  - completion contract
  - workflow-level visit/transition limits
- Preserve a graph view, but make it a visualization of the true schema rather than the schema itself.
- Keep the edit surface raw-YAML-first so the UI can round-trip the full schema without losing semantics.
- Run save validation through the real control-plane-backed harness checks.

### Important constraint

The current canvas is a good prototype. It should not be extended incrementally into production if doing so preserves the wrong abstraction.

### Exit criteria

- A workflow authored in the UI can round-trip to real harness config without losing semantics.
- The graph view reflects true workflow execution behavior.

## Phase 7: Deployed Mode And Cloudflare Readiness

### Goal

Ensure the UI works against the intended deployed control-plane model, not only local Go-admin mode.

### UI changes

- Introduce environment-aware feature availability:
  - local Go control plane
  - deployed Cloudflare control plane
- Hide or relabel features that are local-only, such as provider catalog management when unavailable in Cloudflare builds.
- Add deployment-mode messaging so users understand whether a surface is:
  - local-only
  - deployed
  - not yet supported in this environment

### Exit criteria

- The UI no longer assumes that local admin routes are universally available.
- Feature availability aligns with the actual backend build/runtime.

## Cross-Cutting Workstreams

These should run across phases instead of waiting for one phase to finish completely.

### 1. API client modularization

- Move feature-specific clients out of `main.dart`.
- Keep one client per bounded domain, such as `runs_api.dart`, `tenants_api.dart`, and `approvals_api.dart`.

### 2. Shared design system

- Reuse common cards, filters, detail layouts, tables, and status chips.
- Encode run and approval statuses consistently across screens.

### 3. Test strategy

- Replace navigation-only tests with feature tests that exercise real screen state transitions using mock APIs.
- Add golden tests for the most operationally important views:
  - run list
  - run detail
  - approval queue
  - artifact detail

### 4. Documentation

- Keep `ui/docs/alignment/alignment.md` as the architecture and rollout source of truth.
- Add one implementation note per phase as work starts so the plan stays connected to the actual codebase.

## Suggested Delivery Order

1. Phase 0
2. Phase 1
3. Phase 2
4. Phase 3
5. Phase 4
6. Phase 5
7. Phase 6
8. Phase 7

## Recommended First Slice

If work starts immediately, the best first implementation slice is:

1. Restructure navigation into `Operations`, `Control Plane`, and `Harness Config`.
2. Build a real run list.
3. Build run detail with runtime profile, blocker/wait state, and artifacts.
4. Replace synthetic dashboard content with live run and approval summaries.

That slice would give the UI real alignment quickly without forcing premature decisions about full harness authoring parity.
