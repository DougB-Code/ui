/// Provides seeded Aurora concept data for offline and empty-service states.
library;

import '../domain/models.dart';

/// Creates the seeded focused workspace from the Aurora concept.
ProjectWorkspace seededWorkspace() {
  return ProjectWorkspace(
    title: 'SaaS Market Research',
    subtitle: 'Research project • Created today',
    tasks: seededTasks(),
    sources: seededSources(),
    memoryRecords: seededMemoryRecords(),
  );
}

/// Creates seeded home execution steps.
List<WorkspaceTask> seededExecutionSteps() {
  return const <WorkspaceTask>[
    WorkspaceTask(
      id: 'review-source-material',
      title: 'Review source material',
      detail: '15 documents reviewed',
      done: true,
    ),
    WorkspaceTask(
      id: 'synthesize-key-themes',
      title: 'Synthesize key themes',
      detail: '6 themes identified',
      done: true,
    ),
    WorkspaceTask(
      id: 'draft-talking-points',
      title: 'Draft talking points',
      detail: 'In progress • 70%',
      done: false,
      active: true,
    ),
    WorkspaceTask(
      id: 'assemble-brief',
      title: 'Assemble brief',
      detail: 'Pending',
      done: false,
    ),
    WorkspaceTask(
      id: 'prepare-for-q-and-a',
      title: 'Prepare for Q&A',
      detail: 'Pending',
      done: false,
    ),
  ];
}

/// Creates seeded workspace tasks.
List<WorkspaceTask> seededTasks() {
  return const <WorkspaceTask>[
    WorkspaceTask(
      id: 'scan-market-reports',
      title: 'Scan market reports',
      detail: 'Done',
      done: true,
    ),
    WorkspaceTask(
      id: 'compile-key-metrics',
      title: 'Compile key metrics',
      detail: 'Done',
      done: true,
    ),
    WorkspaceTask(
      id: 'analyze-competitor-positioning',
      title: 'Analyze competitor positioning',
      detail: 'Open',
      done: false,
      active: true,
    ),
    WorkspaceTask(
      id: 'draft-executive-summary',
      title: 'Draft executive summary',
      detail: 'Open',
      done: false,
    ),
  ];
}

/// Creates seeded memory records.
List<MemoryRecord> seededMemoryRecords() {
  return const <MemoryRecord>[
    MemoryRecord(
      id: 'mem-market-reports',
      title: 'Market Reports',
      summary: 'Recent SaaS market reporting and investor commentary.',
      kind: 'document',
      topics: <String>['saas', 'market'],
      sourceLabel: 'concept:market_reports',
    ),
    MemoryRecord(
      id: 'mem-industry-signals',
      title: 'Industry Signals',
      summary:
          'Signals around efficient growth, AI workflows, and consolidation.',
      kind: 'summary',
      topics: <String>['signals', 'ai'],
      sourceLabel: 'concept:signals',
    ),
    MemoryRecord(
      id: 'mem-customer-interviews',
      title: 'Customer Interviews',
      summary: 'Buyer notes emphasizing tool consolidation and workflow depth.',
      kind: 'conversation',
      topics: <String>['customers'],
      sourceLabel: 'concept:interviews',
    ),
  ];
}

/// Creates seeded source items.
List<SourceItem> seededSources() {
  return const <SourceItem>[
    SourceItem(
      id: 'source-market-report',
      title: '2025 SaaS Market Report',
      detail: 'Market report • 18 pages',
    ),
    SourceItem(
      id: 'source-customer-notes',
      title: 'Customer Interview Notes',
      detail: 'Research notes • 6 interviews',
    ),
    SourceItem(
      id: 'source-competitor-brief',
      title: 'Competitor Positioning Brief',
      detail: 'Analysis • updated today',
    ),
  ];
}

/// Creates seeded home chat messages.
List<ChatMessage> seededHomeMessages() {
  final now = DateTime(2025, 5, 20, 9, 15);
  return <ChatMessage>[
    ChatMessage(
      id: 'seed-user-investor-brief',
      role: ChatRole.user,
      author: 'You',
      text:
          'Focus on our growth runway, unit economics, and the new enterprise wins. Keep it crisp and investor-ready.',
      createdAt: now,
    ),
    ChatMessage(
      id: 'seed-aurora-investor-brief',
      role: ChatRole.assistant,
      author: 'Aurora',
      text:
          'I have pulled the latest metrics, enterprise case studies, and market signals. Here is a draft of your briefing.',
      createdAt: now.add(const Duration(minutes: 1)),
    ),
  ];
}

/// Creates seeded focused workspace chat messages.
List<ChatMessage> seededWorkspaceMessages() {
  final now = DateTime(2025, 5, 20, 9, 22);
  return <ChatMessage>[
    ChatMessage(
      id: 'seed-user-saas-trends',
      role: ChatRole.user,
      author: 'You',
      text: 'What are the latest SaaS market trends?',
      createdAt: now,
    ),
    ChatMessage(
      id: 'seed-aurora-saas-trends',
      role: ChatRole.assistant,
      author: 'Aurora',
      text: 'I will build a deeper research brief with data-backed insights.',
      createdAt: now,
    ),
  ];
}

/// Creates seeded chat sessions.
List<ChatSession> seededSessions() {
  return <ChatSession>[
    ChatSession(
      id: 'seed-home',
      title: 'Investor meeting brief',
      updatedAt: DateTime(2025, 5, 20, 9, 16),
    ),
    ChatSession(
      id: 'seed-saas-market',
      title: 'SaaS Market Research',
      updatedAt: DateTime(2025, 5, 20, 9, 22),
    ),
  ];
}
