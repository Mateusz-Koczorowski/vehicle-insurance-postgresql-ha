# Project guidance for Claude Code

Read `AGENTS.md` first and follow it as the repository-wide working agreement.
Treat `docs/PRD.md` as the authoritative implementation scope,
`docs/DATABASE_DESIGN.md` as the data contract, and
`docs/architecture/ARCHITECTURE_CONTRACT.md` as the infrastructure contract.

The canonical specialist-agent instructions live in `docs/agents/`. Every agent must apply `docs/agents/QUALITY_GATES.md`. Project subagents are registered under `.claude/agents/`; those files are platform adapters and must remain consistent with the canonical role documents.

When delegating work:

- use the narrowest matching specialist,
- run write-heavy agents in parallel only when their ownership areas do not overlap,
- route changes to root orchestration files through `project-integrator` or coordinate them explicitly,
- require each agent to return changed files, verification results, risks and handoff notes.
