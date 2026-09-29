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
elixir run.exs review

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
| `review`      | Constructors, large collections, and regex | ~40s     |
| `all`         | Run all suites                              | ~3min    |

## Comparing Revisions

Use the same benchmark script and runtime for both revisions. Set `ZOI_PATH`
to the absolute path of the source directory to measure:

```bash
ZOI_PATH=/absolute/path/to/reference elixir run.exs review
ZOI_PATH=/absolute/path/to/candidate elixir run.exs review
```

Alternate reference and candidate runs at least three times. Compare each case
across revisions, not against other cases in the same run. Parse schemas are
built outside timing; the construction case includes all constructor work.
The 1,000-item cases measure scaling and are not typical input sizes.
