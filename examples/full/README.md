# Full Example

This example shows the default six-agent layout:

- `communicator`
- `planner`
- `researcher`
- `coder`
- `reviewer`
- `runner`

Every worker uses an agent-scoped sandbox, a unique `agentDir`, and the same narrow bind mount at `/coord`.
