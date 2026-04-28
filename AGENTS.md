# AGENTS.md

## Architecture

### Code Documentation

ALWAYS add concise code documentation for each file and function.
OPTIONALLY add concise code comments for any nuanced statements you feel should be highlighted.

### Code Organization

Root-adjacent packages wire systems together. Deeper packages contain narrower, more reusable logic and should not import their parent package.

Codegen files needed for the project must be generated in the project root's `build` folder.

### Coding Practices

ALWAYS follow SOLID principles. Place particular emphasis on the Single
Responsibility Principle.

NEVER add backwards compatibility or legacy support unless explicitly asked. 

ALWAYS write production grade code. DO NOT write shims, stubs, or non-test mocks unless explicitly asked.

ALWAYS give security and bug fixes priority over other coding concerns. Your implementation is only complete once it's secure and bug free.

ALWAYS add a concise doc.go to each package. ALWAYS state what the packages intended use cases and high-level examples to let users know when they are mis-using the package if required.

## Build and Test

Task summaries can be provided in the chat window, or in `build/ai`. 

## Collaboration

ALWAYS scope changes to one task (ex: added new LLM provider, fixed a bug, changed persistence layer). Remind the user to restructure their requests when they ask for broad, sweeping changes. 