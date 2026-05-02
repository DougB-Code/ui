## Core idea

These are **not separate task systems**. They are different views over one richer task model.

A normal task app treats a task as a row:

> title, status, due date, priority, tags

A futuristic task app should treat a task as a **node in a personal operating system**:

> task + time + people + context + dependencies + value + effort + risk + commitments + source + confidence

Calendar, Gantt, and Kanban are already projections of the same data:

| View     | Primary question                |
| -------- | ------------------------------- |
| Calendar | When does this happen?          |
| Gantt    | What depends on what over time? |
| Kanban   | What state is this work in?     |

The new views are also projections, but they answer more human questions:

| View               | Primary question                            |
| ------------------ | ------------------------------------------- |
| Task Constellation | How are my tasks connected?                 |
| Task Stream        | What should flow through my attention next? |
| Priority Terrain   | Where is the best place to spend effort?    |
| Commitment Weave   | What obligations are competing for me?      |

The app should have **one canonical task graph**, then render different views from it.

---

# 1. Task Constellation

## What it is

Task Constellation is a **relationship-first view**.

Instead of sorting tasks by due date or status, it shows tasks as spatial nodes. Tasks that are related appear closer together. Dependencies, shared contexts, shared people, projects, locations, and semantic similarity all create gravitational pull.

In your app, this would feel like a calm “map of everything I currently have in motion.”

## How it would work

A task appears as a node.

The node’s visual properties communicate task meaning:

| Visual element | Meaning                                       |
| -------------- | --------------------------------------------- |
| Position       | Relationship to other tasks                   |
| Cluster        | Project, life area, topic, context, or source |
| Orbital ring   | Time horizon: today, this week, later         |
| Node size      | Effort, value, or importance                  |
| Glow/intensity | Urgency                                       |
| Border color   | Status or risk                                |
| Solid line     | Explicit relationship                         |
| Dotted line    | Inferred relationship                         |
| Thick line     | Strong relationship                           |
| Faded node     | Waiting, blocked, or low relevance            |

Example:

* “Buy bread”
* “Buy milk”
* “Grocery shopping”
* “Plan dinner for guests”

These naturally cluster together because they share:

* errand context
* grocery location
* time window
* topic similarity
* household/personal domain

The user could click “Buy bread” and see:

* related tasks
* possible batch actions
* what depends on it
* what can be merged
* what should be done in the same trip

## What this view is good for

Task Constellation is strongest when the user asks:

* “What tasks are connected?”
* “Can I batch anything?”
* “What does this task affect?”
* “What am I forgetting around this topic?”
* “Are there duplicates?”
* “What should be grouped into a project?”

## Data the app needs

### Required task data

| Data                       | Example                   |
| -------------------------- | ------------------------- |
| Task title                 | Buy bread                 |
| Status                     | Open                      |
| Due date                   | May 8                     |
| Tags/topics                | groceries, errands        |
| Project/source             | Personal Tasks            |
| Description                | Pick up whole grain bread |
| Created/updated timestamps | May 6, May 8              |

### Relationship data

This is the key requirement.

| Relationship type | Example                                         |
| ----------------- | ----------------------------------------------- |
| Related to        | Buy bread related to Buy milk                   |
| Depends on        | Submit expense report depends on receipts       |
| Blocks            | Draft proposal blocks review proposal           |
| Part of           | Buy bread part of grocery run                   |
| Same context      | Buy bread and pick up prescription both errands |
| Same location     | Buy bread and grocery shopping at grocery store |
| Same person       | Reply to James and schedule meeting with James  |
| Same project      | Prepare project summary and design review       |

### Inferred data

The app should infer many relationships automatically:

| Signal                   | Inference                                    |
| ------------------------ | -------------------------------------------- |
| Similar text             | “Buy bread” and “Buy milk” are grocery tasks |
| Shared due date          | Both can be batched today                    |
| Shared location          | Both can happen during one errand            |
| Shared person            | Both involve same contact                    |
| Shared document          | Both relate to same workstream               |
| Same conversation source | Tasks came from same chat/email thread       |

### Important design note

Do not make the user manually connect every task. That would be too much friction.

The app should support both:

* **explicit edges** created by the user
* **inferred edges** created by the assistant with confidence scores

Example:

> “This task looks related to Grocery shopping. Link them?”

---

# 2. Task Stream

## What it is

Task Stream is an **attention-flow view**.

It treats tasks less like objects sitting in a database and more like work moving through the user’s day, week, and mental energy.

This is probably the most immediately useful concept for daily execution.

## How it would work

Tasks flow across lanes.

The horizontal axis represents time or sequence:

* Now
* Next
* Later
* Upcoming

The lanes represent modes of attention:

* Deep Work
* Admin
* Errands
* Waiting
* Personal
* Communication
* Low-energy tasks
* Out-of-house tasks

Each task is placed in the stream where it best fits.

Example:

| Lane      | Task            |
| --------- | --------------- |
| Deep Work | Draft proposal  |
| Admin     | Review invoices |
| Errands   | Buy bread       |
| Waiting   | Vendor reply    |
| Personal  | Book flights    |

A selected task like “Buy bread” appears in the Errands stream. The app can show that it should be done after “Pick up prescription” or batched with “Buy milk.”

Blocked tasks become pools or eddies. If several tasks are waiting on someone else, the stream visibly slows down or accumulates.

## What this view is good for

Task Stream answers:

* “What should I do next?”
* “What is ready now?”
* “What is blocked?”
* “Where is my attention overloaded?”
* “How can I batch similar tasks?”
* “What work mode am I in?”
* “What can fit into the next 20 minutes?”

This is less about seeing everything and more about helping the user move.

## Data the app needs

### Required task data

| Data                | Example                 |
| ------------------- | ----------------------- |
| Status              | Open, Waiting, Blocked  |
| Due date            | Today                   |
| Scheduled date/time | 11:00 AM                |
| Estimate            | 20 minutes              |
| Context             | Errands                 |
| Energy required     | Low, normal, high       |
| Location            | Grocery store           |
| Priority            | Normal/Urgent           |
| Dependencies        | Waiting on vendor reply |

### Flow-specific data

| Data                   | Why it matters                           |
| ---------------------- | ---------------------------------------- |
| Readiness              | Can this task be done now?               |
| Duration estimate      | Determines where it fits                 |
| Energy mode            | Deep work vs shallow work                |
| Context-switching cost | Avoids jumping between unrelated modes   |
| Location requirement   | Groups out-of-house errands              |
| Calendar availability  | Finds available windows                  |
| Dependency state       | Blocks/unblocks flow                     |
| User work rhythm       | Morning deep work, afternoon admin, etc. |
| Recurrence             | Repeating streams/routines               |

### Derived concepts

The app should calculate:

| Derived field       | Meaning                             |
| ------------------- | ----------------------------------- |
| ready_now           | Task can be acted on immediately    |
| next_best_action    | The next concrete step              |
| flow_lane           | Best attention/context lane         |
| bottleneck_score    | How much this task slows other work |
| batch_score         | How well it pairs with nearby tasks |
| context_switch_cost | How disruptive it is to do now      |

## Important design note

This view needs strong automation. If the user has to manually drag every task into a flow lane, it becomes another Kanban board.

The app should infer the lane and let the user correct it.

Example:

> “Buy bread” automatically goes to Errands because it has grocery tags, a location, and low effort.

---

# 3. Priority Terrain

## What it is

Priority Terrain is a **decision landscape**.

It turns prioritization into a map.

Instead of saying “priority = high/medium/low,” it shows tasks in a terrain shaped by several dimensions:

* urgency
* value
* effort
* risk
* blockers
* time horizon

This is the most strategic of the concepts.

## How it would work

Tasks sit on a landscape.

The terrain could encode:

| Terrain element | Meaning                         |
| --------------- | ------------------------------- |
| X-axis          | Value or impact                 |
| Y-axis          | Urgency                         |
| Elevation       | Combined priority               |
| Marker size     | Effort                          |
| Texture         | Risk/blockers                   |
| Color           | Domain or status                |
| Path            | Recommended route through tasks |

A task like “Finish quarterly report” appears on a high ridge because it is both high urgency and high value.

A task like “Buy coffee” appears in the quick-win foothills: low effort, low risk, maybe modest value.

A task like “Refill prescription” might sit in risky terrain if it is waiting on approval, has health impact, or is time-sensitive.

## What this view is good for

Priority Terrain answers:

* “What matters most?”
* “What should I do first?”
* “What is urgent but low value?”
* “What is valuable but not urgent yet?”
* “Where are the quick wins?”
* “What is risky to ignore?”
* “Where am I spending too much effort for too little return?”

## Data the app needs

### Required task data

| Data           | Example                  |
| -------------- | ------------------------ |
| Due date       | Today, 5 PM              |
| Estimate       | 3-4 hours                |
| Priority       | High                     |
| Status         | Open                     |
| Domain/project | Work                     |
| Dependencies   | Waiting on final numbers |
| Description    | Q1 report due today      |

### Priority-specific data

This view needs richer scoring than most task apps capture.

| Data               | Meaning                                |
| ------------------ | -------------------------------------- |
| Urgency            | How soon consequences arrive           |
| Value              | How much benefit completion creates    |
| Effort             | Time, energy, complexity               |
| Risk               | Cost of delay or failure               |
| Confidence         | How certain the app is about the score |
| Deadline hardness  | Soft preference vs real deadline       |
| Consequence        | What happens if ignored                |
| Goal alignment     | Which goal this supports               |
| Opportunity window | When it is most useful to do           |
| Reversibility      | Whether a bad decision is costly       |

### Derived scoring

The app can calculate something like:

| Score                 | Based on                                       |
| --------------------- | ---------------------------------------------- |
| urgency_score         | Due date, deadline hardness, time remaining    |
| value_score           | goal alignment, user rating, source importance |
| effort_score          | estimate, complexity, required energy          |
| risk_score            | blockers, dependencies, penalty of delay       |
| terrain_position      | combined projection of the above               |
| recommended_next_step | best actionable move                           |

## Important design note

This is the view where the app can become annoying if it pretends to know too much.

For personal tasks, “value” is not objective. Buying bread may be low value in a work system but high value if dinner depends on it.

The app needs humility:

* show why a task is placed where it is
* let the user override the score
* keep a confidence value
* avoid making every task feel like a quantified productivity contest

Good inspector copy:

> “Placed here because it is due today, affects dinner planning, and can be completed in under 20 minutes.”

---

# 4. Commitment Weave

## What it is

Commitment Weave is an **obligation-density view**.

It shows that tasks are rarely just tasks. They are commitments across:

* time
* people
* projects
* life domains
* goals
* promises
* responsibilities

This is probably the most “futuristic” concept because it goes beyond task management into life-load management.

## How it would work

The main canvas is a woven matrix.

Threads represent dimensions:

| Thread type    | Example                              |
| -------------- | ------------------------------------ |
| Time           | This week, next week, later          |
| People         | You, family, team, client            |
| Projects       | Personal Tasks, Work Project, Admin  |
| Domains        | Errands, Health, Finance, Growth     |
| Status         | Open, Waiting, Blocked               |
| Responsibility | Owned, delegated, waiting on someone |

Tasks appear at intersections.

Example:

“Buy bread” intersects:

* This Week
* Personal
* Errands
* Family/household
* Open
* Medium priority

“Team sync notes” intersects:

* This Week
* Team
* Work Project
* Communication
* Possibly conflict if it overlaps with other obligations

Dense woven areas reveal overload. Sparse areas reveal available capacity. Red intersections show conflicts.

## What this view is good for

Commitment Weave answers:

* “Where am I overcommitted?”
* “Who is affected by my tasks?”
* “Which life domains are getting ignored?”
* “What promises did I make?”
* “What commitments collide this week?”
* “Am I spending too much capacity on one area?”
* “What can be delegated or deferred?”

## Data the app needs

### Required task data

| Data            | Example                    |
| --------------- | -------------------------- |
| Time horizon    | This week                  |
| People affected | You, family                |
| Domain          | Errands                    |
| Project         | Personal Tasks             |
| Status          | Open                       |
| Priority        | Medium                     |
| Description     | Pick up bread for the week |

### Commitment-specific data

| Data                    | Why it matters                                  |
| ----------------------- | ----------------------------------------------- |
| Owner                   | Who is responsible                              |
| Affected people         | Who benefits or is blocked                      |
| Promise source          | Chat, email, meeting, manual entry              |
| Commitment type         | Task, obligation, follow-up, favor, appointment |
| Soft vs hard commitment | Promise vs optional idea                        |
| Domain                  | Work, health, finance, family, errands          |
| Capacity budget         | How much time/energy each area can consume      |
| Conflict rules          | What overlaps are unacceptable                  |
| Delegation state        | Owned, delegated, waiting                       |
| Social importance       | Boss, partner, client, friend, self             |

### Derived concepts

| Derived field          | Meaning                                    |
| ---------------------- | ------------------------------------------ |
| commitment_density     | How crowded a person/domain/time period is |
| conflict_score         | Whether commitments compete                |
| neglect_score          | A domain has too little attention          |
| overload_score         | Too many commitments in a window           |
| affected_people        | People impacted by completion or delay     |
| balance_recommendation | Move, defer, delegate, batch               |

## Important design note

This view requires the app to distinguish between a task and a commitment.

A task is:

> “Buy bread”

A commitment is:

> “Have food available for the household this week”

The task is one expression of a broader obligation. That distinction is powerful.

---

# Shared underlying data model

The cleanest model is a **task graph with projection views**.

Conceptually:

```text
Task
  id
  title
  description
  status
  priority
  due_date
  scheduled_date
  estimate
  energy_required
  effort
  value
  urgency
  risk
  source
  project_id
  domain_id
  context_id
  location_id
  owner_id
  created_at
  updated_at

TaskRelation
  from_task_id
  to_task_id
  relation_type
  confidence
  source

Commitment
  id
  task_id
  people
  domain
  project
  time_window
  responsibility
  promise_source
  hardness
  consequence

DerivedSignal
  task_id
  urgency_score
  value_score
  effort_score
  risk_score
  readiness_score
  bottleneck_score
  density_score
  confidence
  explanation
```

The important architectural pattern is:

> **Canonical task graph + view-specific read projections**

The source of truth stays unified. Each view gets its own computed projection.

| Projection    | Uses the same task graph to produce |
| ------------- | ----------------------------------- |
| Calendar      | time blocks                         |
| Gantt         | dependency timeline                 |
| Kanban        | status columns                      |
| Constellation | spatial relationship graph          |
| Stream        | attention flow                      |
| Terrain       | priority surface                    |
| Weave         | commitment density map              |

---

# Are they mutually exclusive?

No.

They are different views of the same underlying data.

But they are not equally dependent on the same fields.

## Same core data

All four need:

* title
* status
* due date
* project/source
* tags/topics
* priority
* relationships
* effort estimate
* domain/context

## Different emphasis

| View               | Needs most                                             |
| ------------------ | ------------------------------------------------------ |
| Task Constellation | relationships, semantic similarity, tags, dependencies |
| Task Stream        | schedule, readiness, context, duration, energy         |
| Priority Terrain   | value, urgency, effort, risk, goal alignment           |
| Commitment Weave   | people, domains, ownership, commitments, capacity      |

## Practical answer

They should be sibling views.

A user might use them like this:

1. **Priority Terrain** to decide what matters.
2. **Task Stream** to decide what to do next.
3. **Task Constellation** to understand relationships and batch work.
4. **Commitment Weave** to see overload, tradeoffs, and affected people.

They are not competitors. They are lenses.

---

# What the app should capture manually vs infer automatically

This is important. A futuristic task app should not ask the user to fill out twenty fields per task.

## User should manually provide

* title
* description if needed
* due date if known
* status
* rough priority
* project/domain when obvious
* explicit dependencies when important

## App should infer

* topics
* context
* semantic relationships
* related tasks
* likely duration
* urgency
* batching opportunities
* possible location
* affected people
* whether something is waiting/blocked
* whether a task belongs to a broader commitment

## App should ask only when uncertain

Example:

> “Is Buy bread part of Grocery shopping?”

or:

> “This looks like an errand. Should I group it with Buy milk and Pick up prescription?”

The app should capture **confidence** and **source** for inferred data.

Example:

```text
context: Errands
confidence: 0.82
source: inferred from title and grocery-related tasks
```

That lets the UI explain itself instead of feeling magical or arbitrary.

---

# Best product direction

I would not ship all four as equal top-level views at first.

I would treat them like this:

| Concept            | Product role                           |
| ------------------ | -------------------------------------- |
| Task Stream        | Primary daily execution view           |
| Priority Terrain   | Planning and prioritization view       |
| Task Constellation | Exploration and relationship view      |
| Commitment Weave   | Advanced review / weekly planning view |

The strongest MVP pairing is:

1. **Task Stream** for daily use.
2. **Priority Terrain** for deciding what deserves attention.

Then add:

3. **Task Constellation** once the app has enough relationship data.
4. **Commitment Weave** once the app understands people, promises, and capacity.

The biggest mistake would be building beautiful visualizations before the data model is rich enough. The underlying task graph matters more than the view. Once the graph is strong, all of these become different renderings of the same reality.
