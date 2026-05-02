# Task Concept Implementation Plan

This plan implements the concept from `task-concept-1.md` as one canonical task graph with multiple read projections. The current codebase already has a Go task MCP service and a Flutter task workspace, so the implementation should extend those systems rather than introduce a second task stack.

The plan is intentionally phased. Each phase should be treated as its own scoped task or PR so the product can stay production-grade while the model becomes richer.

## Current State

The task service in `../tasks` currently supports operational tasks, named lists, list items, topics, due dates, scheduled dates, priorities, statuses, memory links, metrics, and a deterministic steward review.

The UI currently loads tasks and lists through `TasksClient`, stores them in `AuroraAppController`, and renders the Tasks section as Queue, Lists, Review, Capture, Task Inspector, and Memory Links.

The concept requires richer data than the service currently stores:

- explicit task-to-task relationships
- inferred relationships with confidence and explanation
- effort, value, urgency, risk, energy, context, domain, owner, location, source, and goal metadata
- commitments and affected people
- projection payloads for Stream, Terrain, Constellation, and Weave

## Product Direction

Ship the views in this order:

1. Task Stream as the daily execution MVP.
2. Priority Terrain as the planning and prioritization MVP.
3. Task Constellation after relationship data is useful.
4. Commitment Weave after people, promises, and capacity are modeled.

The first milestone should not chase a beautiful canvas before the graph is credible. It should make the canonical graph richer, explainable, and testable, then expose two useful projections.

## Architecture Target

Use this ownership split:

- `../tasks/internal/tasks/domain`: dumb data models, value enums, validation, and projection payload structs.
- `../tasks/internal/tasks/store`: SQLite persistence only.
- `../tasks/internal/tasks/graph`: deterministic graph assembly and relationship inference.
- `../tasks/internal/tasks/projection`: read-only projection builders for Stream, Terrain, Constellation, and Weave.
- `../tasks/internal/tasks/service`: orchestration across repository, graph, and projections.
- `../tasks/internal/tasks/transport`: MCP tool schemas and JSON-RPC adapters.
- `ui/lib/clients`: task MCP calls and response parsing.
- `ui/lib/domain/tasks`: UI-facing task graph and projection models.
- `ui/lib/ui/tasks`: task view widgets only.
- `ui/lib/app`: controller state and command coordination only.

Do not mix scoring or inference logic into Flutter widgets. Widgets should render projection models returned by the controller.

## Phase 1: Canonical Task Graph Foundation

Goal: make the backend capable of representing task graph data even before every UI view exists.

Backend changes:

- Add domain models for `TaskRelation`, `TaskFacet`, `TaskSignal`, `Commitment`, and `TaskGraph`.
- Extend `Task` with optional graph metadata fields:
  - `estimate_minutes`
  - `energy_required`
  - `effort`
  - `value`
  - `urgency`
  - `risk`
  - `context`
  - `domain`
  - `location`
  - `owner`
  - `source`
  - `confidence`
- Add relationship type enums:
  - `related_to`
  - `depends_on`
  - `blocks`
  - `part_of`
  - `same_context`
  - `same_location`
  - `same_person`
  - `same_project`
  - `same_source`
- Add persistence tables:
  - `task_relations`
  - `task_signals`
  - `commitments`
  - `commitment_people`
  - indexes for relation endpoints, relation type, confidence, context, domain, owner, and due/scheduled time.
- Add repository methods:
  - `ListTaskRelations`
  - `UpsertTaskRelation`
  - `DeleteTaskRelation`
  - `ListCommitments`
  - `UpsertCommitment`
  - `BuildTaskGraph`
- Add MCP tools:
  - `get_task_graph`
  - `list_task_relations`
  - `upsert_task_relation`
  - `delete_task_relation`
  - `list_commitments`
  - `upsert_commitment`

Implementation notes:

- Keep explicit and inferred relations in the same table with `source`, `confidence`, and `explanation`.
- Do not use fake embeddings or fake seed data. The first inference pass should use deterministic signals: shared topics, shared memory links, shared due/scheduled day, shared status, list membership, title token overlap, and explicit dependencies.
- Keep existing task/list APIs working as the main mutation path. The graph tools are additive read/projection support and relationship editing.

Tests:

- Domain validation for relation types, signal ranges, confidence range, and commitment hardness.
- Store tests for relation CRUD, commitment CRUD, cascade behavior, and graph assembly.
- MCP transport tests for new tool discovery and payload shape.

## Phase 2: Projection Builders

Goal: compute view-specific read models from the same graph.

Backend packages:

- Add `internal/tasks/projection/stream`.
- Add `internal/tasks/projection/terrain`.
- Add `internal/tasks/projection/constellation`.
- Add `internal/tasks/projection/weave`.

Shared projection rules:

- Projection builders must be pure and deterministic for a supplied graph and time.
- Projection outputs must include explanations for inferred placement.
- Projection outputs must preserve confidence and source fields.
- Projection builders must not mutate tasks or inferred relations.

Task Stream MVP:

- Add `TaskStreamProjection`, `TaskStreamLane`, and `TaskStreamCard`.
- Compute lanes from status, context, domain, energy, location, topics, schedule, and relation state.
- Start with lanes:
  - Now
  - Next
  - Later
  - Waiting
  - Blocked
- Include fields:
  - `ready_now`
  - `next_best_action`
  - `flow_lane`
  - `batch_score`
  - `context_switch_cost`
  - `bottleneck_score`
  - `explanation`

Priority Terrain MVP:

- Add `PriorityTerrainProjection`, `PriorityTerrainPoint`, and `PriorityTerrainBand`.
- Compute normalized scores for urgency, value, effort, and risk.
- Include fields:
  - `urgency_score`
  - `value_score`
  - `effort_score`
  - `risk_score`
  - `x`
  - `y`
  - `elevation`
  - `recommended_next_step`
  - `explanation`
- Keep scoring humble. If the app has weak evidence, confidence should be low and the explanation should say why.

Later projections:

- Task Constellation should use relation strength, shared facets, and confidence to build nodes and edges.
- Commitment Weave should use commitments, people, domains, responsibility, and time windows to build density and conflict rows.

MCP tools:

- `project_task_stream`
- `project_priority_terrain`
- `project_task_constellation`
- `project_commitment_weave`

Tests:

- Projection unit tests using explicit graph fixtures.
- Boundary tests for missing dates, terminal tasks, blocked tasks, no confidence, and overloaded periods.
- Snapshot-style JSON shape tests at the transport layer.

## Phase 3: UI Models And Client Contract

Goal: let the UI consume graph and projection payloads without putting business logic into widgets.

Flutter changes:

- Add `ui/lib/domain/tasks/task_graph.dart` for UI task graph models.
- Add `ui/lib/domain/tasks/task_projection.dart` for Stream, Terrain, Constellation, and Weave payload models.
- Extend `ui/lib/clients/mcp_client.dart` with methods:
  - `getTaskGraph`
  - `projectTaskStream`
  - `projectPriorityTerrain`
  - `projectTaskConstellation`
  - `projectCommitmentWeave`
  - relation and commitment mutation methods
- Keep parsing functions small and documented.
- Add controller state:
  - `TaskGraph? taskGraph`
  - `TaskStreamProjection? taskStream`
  - `PriorityTerrainProjection? priorityTerrain`
  - `TaskConstellationProjection? taskConstellation`
  - `CommitmentWeaveProjection? commitmentWeave`
  - selected task relation and selected projection mode
- Add controller load methods that fetch projections after `_loadTasks`, but degrade to empty projection state on service errors instead of inventing local data.

Tests:

- Client parsing tests for each projection.
- Controller tests for projection refresh and failure messages.
- Widget tests for empty, loading, and populated Stream/Terrain states.

## Phase 4: Task Stream UI

Goal: ship the first useful daily execution view.

UI structure:

- Move task-specific UI into narrower files under `ui/lib/ui/tasks`.
- Keep `tasks_section.dart` as a small composition entry point or split it after the first implementation pass.
- Add a new `Task Stream` area to the existing Tasks left panel.
- Keep the existing Queue area during rollout; Stream becomes the recommended default after it is stable.

Task Stream UI behavior:

- Render lanes as dense, scan-friendly columns or horizontal sections, depending on available width.
- Show task cards with title, status, due/scheduled time, estimate, energy, context, and confidence/explanation indicator.
- Provide existing actions: select, complete, edit in inspector, delete.
- Show blocked/waiting tasks as distinct lane states.
- Let the inspector explain why the selected task is in its lane.
- Avoid manual drag placement for MVP. Corrections should be explicit metadata edits or relation edits.

Tests:

- Widget test that Stream renders lanes and cards from projection models.
- Widget test that selecting a Stream card updates the existing inspector.
- Widget test for blocked/waiting visual states.

## Phase 5: Priority Terrain UI

Goal: add a planning view that helps choose what matters.

UI behavior:

- Add `Priority Terrain` as a Tasks panel area.
- Render a two-dimensional map using pure Flutter layout or `CustomPainter`.
- Place tasks by value and urgency; encode effort and risk with marker size/border/color.
- Show quick-win, high-ridge, risky, and low-signal bands.
- Selecting a point opens the same task inspector.
- Inspector shows placement explanation, confidence, and score breakdown.

Implementation notes:

- Use stable dimensions and responsive constraints for the map.
- Do not make the terrain decorative. It should support scanning, selection, and explanation.
- Do not add 3D or physics for the MVP.

Tests:

- Unit test marker placement from score inputs.
- Widget test that points render, remain selectable, and do not overlap controls at common desktop widths.

## Phase 6: Relationship Editing And Constellation

Goal: make relationship data visible and correctable.

Backend:

- Add relation suggestions from deterministic graph inference.
- Add explicit accept/reject mutation path for inferred relation suggestions.
- Track source and confidence changes.

UI:

- Add relation list to the Task Inspector.
- Add actions to link, unlink, accept suggestion, and dismiss suggestion.
- Add `Task Constellation` after relation density is high enough to be meaningful.
- Use a simple force-directed or clustered `CustomPainter` view only after the relation projection payload is stable.

Tests:

- Relation suggestion tests.
- UI tests for accept/reject flows.
- Projection tests for edge strength and confidence filtering.

## Phase 7: Commitments And Weave

Goal: distinguish a task from the broader commitment it represents.

Backend:

- Add commitment mutation and query flows.
- Add deterministic derivation for low-risk commitments from tasks, lists, due dates, memory links, and affected people when present.
- Add density, overload, neglect, and conflict scoring.

UI:

- Add commitment fields to the inspector.
- Add `Commitment Weave` as an advanced review panel, not a daily default.
- Show time, people, domains, responsibility, and conflict intersections.

Tests:

- Commitment validation and persistence tests.
- Weave projection tests for overload/conflict cases.
- UI tests for advanced review empty and populated states.

## Phase 8: Assistant Automation

Goal: let the assistant enrich tasks while staying explainable and correctable.

Backend/service behavior:

- Add read-only suggestion tools before any auto-write tools.
- Suggestions must include confidence, source, and explanation.
- User correction should create explicit graph metadata rather than hidden local overrides.

Possible tools:

- `suggest_task_relationships`
- `suggest_task_metadata`
- `suggest_commitments`
- `apply_task_suggestion`
- `dismiss_task_suggestion`

Safety rules:

- Do not silently overwrite explicit user metadata with inferred metadata.
- Inferred data must be visibly marked as inferred.
- Low-confidence suggestions should ask the user instead of changing placement.

Tests:

- Suggestions never mutate state.
- Explicit values win over inferred values.
- Dismissed suggestions do not immediately reappear without changed evidence.

## Recommended First Implementation Task

Start with Phase 1 and a thin slice of Phase 2:

1. Add explicit `TaskRelation` persistence and MCP tools.
2. Add deterministic graph assembly from current tasks, topics, dates, lists, and memory links.
3. Add `project_task_stream` with lanes for Now, Next, Later, Waiting, and Blocked.
4. Add UI client parsing and a read-only Task Stream panel.

That gives the product a visible improvement while proving the canonical graph architecture. Priority Terrain should follow once the scoring fields and explanations are in place.

## Verification Checklist

- `go test ./...` from `../tasks`
- `flutter test` from `ui`
- Manual run with `flutter run -d linux`
- Confirm existing Queue, Lists, Review, Capture, Inspector, and Memory Links still work.
- Confirm Stream/Terrain empty states appear when the task service lacks projection support.
- Confirm no fake tasks, fake scores, or seeded demo data are introduced.
