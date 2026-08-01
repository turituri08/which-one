# Project Guidelines

## Source of truth

Before planning or changing implementation, read the applicable project documents in `.github/docs/`:

- `vision.md` — product direction and non-negotiable experience principles
- `gdd.md` — game rules and player-facing behavior
- `tdd.md` — architecture, MVVM, dependency rules, and technical constraints
- `roadmap.md` — phase order, task priorities, and completion criteria
- `implementation-workflow.md` — mandatory planning and commit workflow
- `decisions/` — accepted decisions from prior consultations
- `implementation-plans/` — approved, phase-specific execution plans

When documents conflict, flag the conflict and ask before implementation.

## Implementation workflow

- Do not begin production implementation without a written implementation plan and explicit user approval.
- Break each plan into one-commit units. For each unit, state scope, affected files, verification, and completion criteria.
- Keep each commit focused, independently reviewable, and limited to one logical purpose.
- Use Japanese free-form commit messages that describe the change clearly; Conventional Commits are not required.
- Propose the Japanese commit message and provide the verified change summary, but never execute `git commit`; the user commits after review.
- Update the relevant plan checklist only after its implementation and verification are complete.
- Record decisions made through consultation in `docs/decisions/` before relying on them in subsequent work.

## Architecture

Use Feature-first MVVM. Views call ViewModels; ViewModels call Use Cases; Use Cases coordinate Domain Services, Repositories, and Core Services. Keep the dependency direction defined in `docs/tdd.md`.

Do not put game rules in Views, ViewModels, Repositories, or Core Services. Keep game rules in `features/game/domain/`.

## Validation

Run the relevant formatter, static analysis, and tests for each implemented plan unit. Do not report a task complete if its planned verification has not run or has failed.
