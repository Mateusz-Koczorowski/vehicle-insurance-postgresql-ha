# Repository instructions

## Project

This repository implements the university project **B OUT 15 - Ubezpieczenia komunikacyjne**.
The target is a PostgreSQL-based highly available vehicle-insurance system with a small demonstration web application.

## Source of truth

Before making architectural or domain changes, read:

- `docs/PRD.md`
- `docs/DATABASE_DESIGN.md`
- `docs/IMPLEMENTATION_PLAN.md`
- `docs/agents/COMMON_CONTRACT.md`
- `docs/agents/QUALITY_GATES.md`

When working as a specialized agent, also read the matching file in `docs/agents/`.

## Working rules

- Keep the implementation aligned with the 70-point grading rubric.
- Treat PostgreSQL, replication, query distribution, backup and security as the primary deliverables.
- Keep the web application deliberately small and focused on demonstrating database behavior.
- Never commit passwords, private keys, generated certificates, database data directories, backup repositories or restored clusters.
- Do not use network-wide `trust` authentication or business-user rules covering `0.0.0.0/0`.
- Preserve user changes and do not modify files outside the assigned ownership area without coordination.
- Use migrations and repeatable scripts instead of undocumented manual database edits.
- Record commands and evidence needed for the final Moodle submission.
- Run verification proportional to the changed area and report what was not tested.
- Do not declare work complete until the applicable quality gates and grading gates in `docs/agents/QUALITY_GATES.md` are satisfied or explicitly reported as blocked.

## Agent collaboration

Available project agents:

- `database-engineer`
- `infrastructure-engineer`
- `backup-recovery-engineer`
- `application-engineer`
- `project-integrator`

Their shared contracts and ownership boundaries are documented in `docs/agents/README.md`.
