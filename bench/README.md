# Zoi Benchmarks

Performance benchmarks for Zoi schema validation.

## Running Benchmarks

```bash
cd bench

# Quick smoke test
elixir run.exs quick

# Run specific suite
elixir run.exs primitives
elixir run.exs complex
elixir run.exs comparisons

# Run all benchmarks
elixir run.exs
```

## Available Suites

| Suite         | Description                                 | Duration |
| ------------- | ------------------------------------------- | -------- |
| `quick`       | Fast smoke test with a simple schema        | ~5s      |
| `primitives`  | String, integer, boolean, email, uuid, enum | ~50s     |
| `complex`     | Maps, arrays, nested structures             | ~30s     |
| `comparisons` | vs Ecto.Changeset and NimbleOptions         | ~30s     |
| `all`         | Run all suites                              | ~2min    |
