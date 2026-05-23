# Developer Profile — Lupontes

These are personal preferences that apply to every project I work on.

## Communication

- Before making any non-trivial change, explain what you intend to do and why, then wait for my confirmation.
- Be concise. Avoid unnecessary summaries of what you just did.

## Code Style

- Write all code, identifiers, and comments in **English**.
- Follow the naming conventions recommended by each language:
  - Java: `camelCase` for variables/methods, `PascalCase` for classes, `UPPER_SNAKE_CASE` for constants.
  - JavaScript/Vue: `camelCase` for variables/methods, `PascalCase` for components.
- Prioritize **readability and maintainability** over cleverness. Code is read more than it is written.
- Write meaningful comments that explain **why**, not what. Avoid redundant comments that just restate the code.

## Testing

- Tests are required, not optional. Every significant feature or bug fix must include tests.
- Prefer unit tests for isolated logic and integration tests for system boundaries.
- Never mock what you can test with a real implementation.

## Git Branching Strategy

Always follow this GitFlow by default across all projects. Suggest deviations only when the user explicitly requests them (e.g., "skip to alpha").

```
feat/* / fix/* / refact/* / chore/*
        ↓
      develop    ← integration, merge via reviewed PR
        ↓
      alpha      ← internal team tests
        ↓
       beta      ← selected user tests
        ↓
     release     ← sign-off / UAT, critical fixes only
        ↓
       main      ← production, version tag required
```

- Never commit directly to `main`, `release`, `beta`, `alpha`, or `develop`.
- All work happens in short-lived branches (`feat/*`, `fix/*`, `refact/*`, `chore/*`).
- Hotfix in production: `fix/*` → `main` + cherry-pick back down to `develop`.
- If the project has only some of these branches, apply the same directional flow with what exists.
- If the user asks to skip a stage, accept it explicitly and adapt — but always mention the safe path first.

## Git Commits

- Always follow the Conventional Commits format:
  ```
  <type>(<optional scope>): <description>
  ```
- Common types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`.
- The description must be in English, imperative mood, lowercase, no trailing period.
- Examples:
  ```
  feat(auth): add JWT refresh token support
  fix(api): handle null response from camunda client
  test(user): add unit tests for password validation
  ```
