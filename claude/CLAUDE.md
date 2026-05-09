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
