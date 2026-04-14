# UI Alignment Report

## Scope

This report compares the current `ui` against the capabilities and architecture expressed by:

- the harness in `../harness`
- the control plane in `../control-plane`

The harness and control plane are treated as the current source of truth for execution behavior, state, and product boundaries. That does not mean they are frozen; it means the UI should be judged by how well it represents and operates those systems as they exist today.

## Executive Summary

The UI is now partially aligned with the system underneath it.

It has moved from a mostly prototype shell to an early live beta console. The current beta path is meaningfully control-plane-backed for runs, approvals, artifacts, audits, metrics, tenants, users, memberships, installations, conversations, channel routes, and provider administration.

The remaining misalignment is now less about fake data in the main beta shell and more about depth and completeness:

- run operations are real, but not yet the default landing flow
- control-plane entities are visible, but mostly inspection-only
- harness configuration beyond providers is still missing
- workflow authoring parity is still not started
- deployed-mode / Cloudflare awareness is still missing

## High-Level Alignment

- `Providers`: partial alignment
- `Harness agent configuration`: low alignment
- `Harness tool configuration`: low alignment
- `Harness workflow authoring`: low alignment
- `Run operations`: partial alignment
- `Approvals, artifacts, audits, metrics`: partial alignment
- `Tenants, users, installations, conversations, channel routes`: partial alignment
- `Cloudflare / deployed control-plane model`: not aligned

## What Is Aligned Today

### 1. Provider management is real

The provider screen is the clearest example of genuine alignment:

- The UI calls the control-plane admin provider API in `ui/lib/provider_catalog_api.dart`.
- The control plane exposes matching routes in `control-plane/internal/controlplane/http.go`.
- Those routes mutate the harness `provider.yaml` through the control plane's provider catalog manager.
- The UI reflects several real harness provider fields: alias, adapter, base URL, API key env var, allowed hosts, model enablement, verification bits, timeout, API version, account ID, and gateway ID.

This is a good pattern because the UI is not editing harness files directly. It is asking the control plane to manage harness config on its behalf.

### 2. Run operations are real

The beta shell now has a live runs surface:

- run list
- run filters
- run detail
- approval state
- operator actions
- artifacts
- audits
- live metrics
- pending approvals on the overview

This means the UI can now answer the core operational questions the earlier report identified as missing.

### 3. The shell now reflects the control-plane-first architecture much more clearly

The left rail is now split into:

- `Operations`
- `Control Plane`
- `Harness Config`

That is much closer to the intended system boundary than the older flat config-editor shell.

### 4. The control-plane entity model is now visible

The UI now exposes live lists for:

- tenants
- users
- memberships
- control-plane agents
- installations
- conversations
- channel routes

This is still mostly an inspection surface, but it is no longer true that the UI "exposes almost none" of the product model.

## Major Deltas

### 1. The shell is much closer to the right architecture, but the default flow is still not centered on runs

The navigation now reflects the intended architecture, but the default landing area is still `Overview` rather than the live runs console. For beta testing, the most valuable first screen is still likely the operational run surface.

This is now an ordering and focus issue rather than a fundamental shell-structure issue.

### 2. Control-plane entities are visible, but they are still mostly read-only inspection surfaces

There are two distinct agent concepts in the backend:

- Harness agents: runtime roles resolved from templates, tool groups, policies, instructions, lead/worker roles, and subagent settings.
- Control-plane agents: tenant-scoped product entities with templates, capability bindings, integration bindings, approval overrides, and runtime profile relationships.

The current beta UI correctly labels the product-side agent surface as control-plane-first, but it does not yet provide deep detail or full management flows for tenants, users, memberships, agents, installations, conversations, and routes.

So the ambiguity problem has improved substantially, but product-entity management is still incomplete.

### 3. Harness configuration parity beyond providers is still largely absent

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

The beta shell no longer presents misleading seed-data `Agents`, `Tools`, and `Workflows` sections as active product surfaces, which is an improvement. But the underlying parity gap remains: the UI still cannot safely author the real harness agent, tool, and workflow schemas.

That means the beta console is now better scoped, but harness administration is still far from complete.

### 4. Workflow authoring parity is still missing

This is the second-largest harness-side mismatch.

Real harness workflows support much more than a list of nodes and edges. The schema includes:

- `max_visits_per_node`
- `max_total_transitions`
- `duplicate_result_cap`
- per-node `with`
- input contracts
- output contracts
- typed `success` / `failure` / `blocked` transitions
- `include_node_results`
- `input_mappings`
- prompt overlays
- gate policies
- policy gates
- completion contracts
- implementation flags and gate requirements

That is visible in:

- `harness/internal/appconfig/workflowconfig/types.go`
- `harness/configs/workflow.sample.yaml`
- `harness/docs/workflow-authoring.md`

The current live beta path does not yet attempt a workflow editor at all, which is better than presenting the old prototype as real capability. But the actual alignment gap remains unresolved until a workflow editor can round-trip the real schema.

### 5. Run operations are present, but still not complete enough to be considered fully aligned

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

The UI now covers much of this, but still lacks:

- dedicated artifact screens outside run detail
- dedicated audit screens outside run detail
- conversation-linked execution detail
- richer operator workflows beyond approval resolve

### 6. Conversations and routes are now visible, but conversation state is still shallow

The control plane is explicitly designed around:

- conversations
- channel routes
- installations
- external identities
- Slack onboarding and delivery
- conversation history and pending execution state

That is visible in:

- `control-plane/README.md`
- `control-plane/docs/architecture/slack-integration.md`
- `control-plane/docs/architecture/onboarding.md`
- `control-plane/internal/controlplane/types.go`

The UI now has concepts for:

- conversations
- routes
- installations
- provider/channel identifiers

But it still does not expose:

- recent turns
- pending execution state
- latest approval request on conversation detail
- onboarding/install health detail

### 7. The dashboard is now real, but still narrow

The dashboard has been updated from synthetic placeholders to live operational summaries. The remaining gap is breadth, not authenticity.

### 8. The UI still assumes local admin-route availability and is not yet deployed-mode aware

The provider screen assumes:

- a local control plane
- `CONTROL_PLANE_BASE_URL`
- optional `X-Admin-Token`
- the Go control plane's local provider catalog routes

But the deployed control-plane direction is Cloudflare-first and asynchronous, and provider catalog management is explicitly unavailable in Cloudflare builds:

- `control-plane/internal/controlplane/harness_provider_catalog_cloud.go`
- `control-plane/docs/architecture/cloudflare-deployment.md`

The problem is no longer that providers are the only real feature. The problem is that the shell still assumes the local/admin route surface is available and does not yet adapt to Cloudflare/deployed capability differences.

### 9. Harness session and workflow state are invisible in the UI

The harness persists:

- session status
- current plan
- pending questions
- pending approvals
- workflow state
- node results
- blockers
- artifacts
- memory

That is visible in:

- `harness/README.md`
- `harness/docs/user/modules/ROOT/pages/reference/sessions-and-state.adoc`
- `harness/internal/core/workflow_types.go`

The UI still shows none of this. If the harness is the execution engine, the UI still needs a way to inspect execution state, not just control-plane summaries and approvals.

## Areas Where The UI Is Closest To The North Star

If we separate "good direction" from "current completeness," the strongest bets are:

- Provider administration flowing through the control plane rather than direct file edits.
- A real run-operations surface instead of placeholder observability.
- A shell that is now explicitly split across operations, control-plane, and harness-config concerns.

## Recommended Realignment

### 1. Split the UI into explicit architectural domains

This has mostly been implemented. The current need is to keep deepening the separation so each domain has the right default workflows and level of detail:

- `Control Plane`
- `Harness Config`
- `Run Operations`

That architectural boundary is now legible, but still incomplete in depth.

### 2. Make control-plane entities first-class before expanding more harness editors

This has also mostly been implemented at the list/inspection level. The remaining gap is detail and management depth, not total absence.

### 3. Rework harness authoring screens to match actual schemas

If `Agents`, `Tools`, and `Workflows` stay in the UI, they should align to the real harness config model:

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
- harness session / workflow state when available

Most of this now exists except the harness session / workflow state, plus broader operator flows beyond approval resolve.

### 5. Decide what belongs in the control plane vs what should remain harness-local

The current provider flow proves the pattern, but it also exposes a product question:

- Should the control plane become the authoritative API for all harness config authoring?
- Or should some harness config remain local/operator-only?

That decision matters before investing heavily in live `Agents`, `Tools`, and `Workflows` screens.

## Suggested Priority Order

1. Make `Runs` the default first-run beta experience.
2. Deepen operator workflows around approvals, artifacts, audits, and conversation-linked execution.
3. Add detail and management flows for control-plane entities.
4. Only then expand harness authoring beyond providers.
5. Rebuild workflow editing around the real harness schema.

## Bottom Line

The current UI is no longer just a prototype shell. It is now an early live beta console with meaningful control-plane integration, but it is still only partially aligned to the full architecture.

Today it behaves like:

- a real operations surface for runs, approvals, artifacts, audits, and metrics
- a real inspection surface for core control-plane entities
- a real provider administration surface
- an intentionally narrowed beta shell with misleading seed-data sections removed

The system underneath it still has a richer control-plane model and a much stricter harness configuration/runtime model than the UI exposes. The next alignment step is no longer "replace fake UI with real UI" for the main beta shell. It is deepening the real surfaces that now exist so they match the product and execution model more completely:

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

### Phase 0 status: partial

- [x] Split navigation into explicit `Operations`, `Control Plane`, and `Harness Config` domains.
- [ ] Make `Runs` the default landing surface.
- [x] Move `Providers` under `Harness Config`.
- [x] Label the agent surface as control-plane-first instead of leaving it semantically ambiguous.
- [x] Remove major seed-data sections from the beta shell so live sections are clearly live.
- [x] Keep live API clients in bounded modules (`operations_api.dart`, `control_plane_api.dart`, `provider_catalog_api.dart`).
- [ ] Move most feature state out of `ui/lib/main.dart`.
- [ ] Add explicit local-vs-deployed environment awareness.

### Phase 1 status: partial

- [x] Build a real `Runs` list view with tenant, agent, actor, invocation mode, timestamps, status, and result summary.
- [x] Build run detail with source context, runtime profile snapshot, wait state, operator actions, artifact manifest, and approval state.
- [x] Add live status filters for queued, running, waiting approval, waiting user, blocked, completed, failed, and cancelled.
- [ ] Make run operations the default first screen of the product.

### Phase 2 status: partial

- [x] Add a pending approval queue to the live operator UI.
- [x] Add approval detail and live approve/reject actions.
- [x] Replace synthetic dashboard cards with real metrics and run status counts.
- [x] Show artifacts and audit trail on live run detail.
- [ ] Add dedicated artifact list/detail screens outside run detail.
- [ ] Add dedicated audit log filtering screens outside run detail.

### Phase 3 status: partial

- [x] Add a real `Control Plane` UI domain.
- [x] Expose live tenants, users, memberships, control-plane agents, and installations.
- [ ] Add detail and management flows for those entities beyond inspection.

### Phase 4 status: partial

- [x] Expose live conversations and channel routes.
- [ ] Add conversation detail with recent turns, pending execution state, latest approval request, and latest run.
- [ ] Add route-aware onboarding and install health surfaces.

### Phase 5 status: partial

- [x] Keep provider management live through the control plane.
- [ ] Add real harness agents/tooling surfaces only if the control plane is meant to own them.
- [ ] Add validation-backed harness config editing beyond providers.

### Phase 6 status: not started

- [ ] Replace the workflow sketcher with a schema-faithful harness workflow editor.

### Phase 7 status: not started

- [ ] Add deployed-mode and Cloudflare-aware feature availability.

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

### Scope decision before implementation

Before building these screens, decide which harness configuration is meant to be controlled through the control plane versus which remains local-only. Provider management already proves one pattern, but the same decision has not yet been made for agents, tools, and workflows.

### UI changes if the answer is "control plane should manage them"

- Add a harness agents screen that reflects real harness role config:
  - lead agent
  - resolved agents
  - templates
  - tool groups
  - allowed tools
  - loop instructions
  - policy presets
  - subagent settings
- Add a harness tools screen with separate views for:
  - tool groups
  - external tools
  - MCP servers
- Add validation feedback directly from control-plane-backed harness validation.

### Exit criteria

- No harness config screen is backed by seed-only data.
- The UI schema matches the harness config schema closely enough that saving through the UI cannot silently discard important fields.

## Phase 6: Workflow Authoring Parity

### Goal

Replace the current workflow sketcher with a workflow editor that actually represents the harness runtime model.

### UI changes

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
- Keep AI-assisted editing only if it produces or patches valid workflow config rather than mutating demo state.

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
