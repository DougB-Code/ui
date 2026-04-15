# UI Rendering Audit (2026-04-15)

Scope: audit of rendering performance issues related to rail expand/collapse and screen switching.

## Audit Health Score

| # | Dimension | Score | Key Finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 3/4 | Most controls are proper Material widgets with tap/hover affordances; no major keyboard trap found in audited surfaces. |
| 2 | Performance | 1/4 | Rail expand/collapse animates layout-affecting properties (`width` + `padding`) inside the main shell row, causing repeated full-layout work and visible jitter. |
| 3 | Responsive Design | 2/4 | Desktop-first shell with fixed rail widths (`304`/`84`) and large fixed paddings can increase layout pressure on narrower windows. |
| 4 | Theming | 3/4 | Theming is centralized in shared tokens/constants, but many high-cost visual effects (gradients/shadows) are always-on. |
| 5 | Anti-Patterns | 3/4 | No severe "AI slop" signatures; most issues are technical runtime/rendering inefficiencies rather than style anti-patterns. |
| **Total** |  | **12/20** | **Acceptable (significant work needed)** |

## Anti-Patterns Verdict

**Pass:** this does **not** primarily look like AI-generated template UI. The main concern is runtime behavior (layout churn and repaint cost) rather than visual-template fingerprints.

## Executive Summary

- Audit Health Score: **12/20 (Acceptable)**.
- Issues found: **6 total** (**P0: 0, P1: 3, P2: 2, P3: 1**).
- Top critical issues:
  1. Rail animation drives parent layout on every frame.
  2. Shell-level `setState` re-renders the full shell on both rail toggle and section switch.
  3. Indexed stack child list is rebuilt on every shell build, including screen switches.
- Recommended next steps:
  - Prioritize rail animation architecture and rebuild isolation.
  - Introduce repaint boundaries and lighter animation primitives.
  - Re-profile with Flutter DevTools frame chart after changes.

## Detailed Findings by Severity

### [P1] Layout animation on app rail causes frame-time spikes
- **Location**: `lib/app/app_shell.dart` (`AnimatedContainer` in `_AppRailState.build`) 
- **Category**: Performance
- **Impact**: Animating `width` and `padding` forces repeated layout for the shell row and content pane while toggling rail, which commonly manifests as stutter/jitter.
- **WCAG/Standard**: Flutter performance guidance (avoid expensive layout work during animation).
- **Recommendation**: Replace width animation with paint/composition-friendly strategy (e.g., fixed rail layout with inner `SlideTransition`/`Transform`, or split-shell approach where content area width is decoupled from rail animation). Keep layout changes discrete, not per-frame.
- **Suggested command**: `/optimize`

### [P1] Shell-wide rebuild on rail toggle and section select
- **Location**: `lib/app/app_shell.dart` (`_toggleRail` and `_selectSection` calling `setState` in `BetaShell`)
- **Category**: Performance
- **Impact**: A state change in navigation triggers rebuilds for header, rail, and indexed content container, increasing per-interaction CPU work and amplifying jitter.
- **WCAG/Standard**: N/A (runtime optimization concern).
- **Recommendation**: Isolate state domains (rail state, selected section, header state) using smaller `StatefulWidget`s, `ValueListenableBuilder`, or local state holders so only affected subtrees rebuild.
- **Suggested command**: `/optimize`

### [P1] IndexedStack children list recreated on every shell build
- **Location**: `lib/app/app_shell.dart` (`AppSection.values.map(...).toList()` in build)
- **Category**: Performance
- **Impact**: Recreating the entire list of `KeyedSubtree` wrappers on each build adds avoidable overhead during fast interactions (screen switching/rail animation).
- **WCAG/Standard**: N/A (runtime optimization concern).
- **Recommendation**: Precompute static child slots once (e.g., in `initState`) and update only changed entries, or maintain a stable list structure and swap child pointers minimally.
- **Suggested command**: `/optimize`

### [P2] High-cost visual effects in interactive list items
- **Location**: `lib/providers/providers_page.dart` (`_ProviderListCard` selected-state shadow + animated decoration)
- **Category**: Performance
- **Impact**: Animated shadows/decoration on list selections can increase raster cost on lower-end GPUs or under load, especially during concurrent shell transitions.
- **WCAG/Standard**: N/A.
- **Recommendation**: Reduce blur radius/spread, limit shadow animation frequency, and prefer color/opacity transforms over shadow-heavy transitions for high-frequency interactions.
- **Suggested command**: `/optimize`

### [P2] `ListView(shrinkWrap: true)` in detail pane can force extra layout passes
- **Location**: `lib/control_plane/control_plane_components.dart` (`Conversation detail` panel)
- **Category**: Performance
- **Impact**: `shrinkWrap: true` often increases layout work because dimensions must be computed from children, which can hurt smoothness when parent layout is already under pressure.
- **WCAG/Standard**: N/A.
- **Recommendation**: Prefer constrained `Column` + `SingleChildScrollView` for bounded detail panes, or use a non-shrink-wrapped list with fixed constraints.
- **Suggested command**: `/optimize`

### [P3] Missing explicit profiling hooks/baselines in repo
- **Location**: repository-level (no committed frame-budget/profile baseline docs)
- **Category**: Performance process
- **Impact**: Regressions can reappear without a measurable baseline (frame time, raster time, worst-case transitions).
- **WCAG/Standard**: N/A.
- **Recommendation**: Add a lightweight performance checklist (target: <16ms/frame for primary interactions) and capture DevTools profile snapshots for rail toggle + screen switch.
- **Suggested command**: `/harden`

## Patterns & Systemic Issues

1. **Animation strategy favors layout mutations** in core shell surfaces, increasing the chance of jank during navigation-state transitions.
2. **State updates are too coarse** at the shell level, leading to avoidable rebuild scope.
3. **Visual richness is not budgeted** against interaction frequency (shadows/gradients on frequently changing surfaces).

## Positive Findings

- Uses `IndexedStack` + content cache strategy to preserve screen state and avoid full page recreation each switch.
- Navigation and content responsibilities are cleanly separated into dedicated widgets.
- Shared visual tokens/constants in `lib/shared/ui.dart` provide a good basis for systematic optimization without visual drift.

## Recommended Actions

1. **[P1] `/optimize`** — Refactor rail expand/collapse to avoid per-frame layout width/padding mutations in shell.
2. **[P1] `/optimize`** — Decompose shell state so rail toggles and section changes rebuild only affected subtrees.
3. **[P2] `/optimize`** — Reduce animated shadow/decorative paint cost on frequently updated list/nav elements.
4. **[P3] `/harden`** — Add repeatable performance profiling checklist and baseline metrics.
5. **[P3] `/polish`** — Final pass for motion smoothness and micro-optimization consistency after structural changes.

You can ask me to run these one at a time, all at once, or in any order you prefer.

Re-run `/audit` after fixes to see your score improve.
