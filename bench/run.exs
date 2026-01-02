# Zoi Benchmark Suite
#
# Usage:
#   cd bench && elixir run.exs              # Run all benchmarks
#   cd bench && elixir run.exs primitives   # Run specific suite
#   cd bench && elixir run.exs quick        # Quick smoke test (~5s)
#
# Available suites: primitives, complex, comparisons, quick, all

Mix.install([
  {:benchee, "~> 1.3"},
  {:ecto, "~> 3.12"},
  {:nimble_options, "~> 1.1"},
  {:zoi, path: "../"}
])

# Ecto schema for comparison benchmarks
defmodule BenchEctoUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :email, :string
    field :age, :integer
    field :active, :boolean
  end

  def changeset(user \\ %__MODULE__{}, attrs) do
    user
    |> cast(attrs, [:name, :email, :age, :active])
    |> validate_required([:name, :email, :active])
  end
end

defmodule Zoi.Bench do
  @moduledoc false

  def run(suite, opts \\ []) do
    config = bench_config(opts)

    case suite do
      "primitives" -> primitives(config)
      "complex" -> complex(config)
      "comparisons" -> comparisons(config)
      "quick" -> quick()
      "all" -> all(config)
      _ -> help()
    end
  end

  defp bench_config(opts) do
    if opts[:quick] do
      [warmup: 0.5, time: 1, memory_time: 0.5]
    else
      [warmup: 1, time: 3, memory_time: 1]
    end
  end

  # === Primitives ===

  def primitives(config) do
    IO.puts("\n=== Primitives Benchmark ===\n")

    string_schema = Zoi.string()
    string_validated = Zoi.string() |> Zoi.min(3) |> Zoi.max(50)
    integer_schema = Zoi.integer()
    integer_coerce = Zoi.integer(coerce: true)
    float_schema = Zoi.float()
    boolean_schema = Zoi.boolean()
    email_schema = Zoi.email()
    uuid_schema = Zoi.uuid()
    enum_schema = Zoi.enum(["red", "green", "blue"])

    Benchee.run(
      %{
        "string" => fn -> Zoi.parse(string_schema, "hello") end,
        "string (validated)" => fn -> Zoi.parse(string_validated, "hello world") end,
        "string (invalid)" => fn -> Zoi.parse(string_schema, 123) end,
        "integer" => fn -> Zoi.parse(integer_schema, 12345) end,
        "integer (coerce)" => fn -> Zoi.parse(integer_coerce, "12345") end,
        "float" => fn -> Zoi.parse(float_schema, 3.14) end,
        "boolean" => fn -> Zoi.parse(boolean_schema, true) end,
        "email" => fn -> Zoi.parse(email_schema, "test@example.com") end,
        "uuid" => fn -> Zoi.parse(uuid_schema, "550e8400-e29b-41d4-a716-446655440000") end,
        "enum" => fn -> Zoi.parse(enum_schema, "blue") end
      },
      config
    )
  end

  # === Complex Types ===

  def complex(config) do
    IO.puts("\n=== Complex Types Benchmark ===\n")

    # Maps
    map_5 = Zoi.map(for(i <- 1..5, into: %{}, do: {:"field_#{i}", Zoi.string()}), coerce: true)
    map_20 = Zoi.map(for(i <- 1..20, into: %{}, do: {:"field_#{i}", Zoi.string()}), coerce: true)

    map_5_data = for i <- 1..5, into: %{}, do: {"field_#{i}", "value_#{i}"}
    map_20_data = for i <- 1..20, into: %{}, do: {"field_#{i}", "value_#{i}"}

    # Nested
    nested_3 =
      Zoi.map(%{
        l1: Zoi.map(%{
          l2: Zoi.map(%{value: Zoi.string()}, coerce: true)
        }, coerce: true)
      }, coerce: true)

    nested_3_data = %{"l1" => %{"l2" => %{"value" => "deep"}}}

    # Arrays
    array_schema = Zoi.array(Zoi.string())
    array_10 = for i <- 1..10, do: "item_#{i}"
    array_100 = for i <- 1..100, do: "item_#{i}"

    # Array of maps
    array_maps = Zoi.array(Zoi.map(%{id: Zoi.integer(), name: Zoi.string()}, coerce: true))
    array_maps_data = for i <- 1..10, do: %{"id" => i, "name" => "item_#{i}"}

    Benchee.run(
      %{
        "map (5 fields)" => fn -> Zoi.parse(map_5, map_5_data) end,
        "map (20 fields)" => fn -> Zoi.parse(map_20, map_20_data) end,
        "nested (3 levels)" => fn -> Zoi.parse(nested_3, nested_3_data) end,
        "array (10)" => fn -> Zoi.parse(array_schema, array_10) end,
        "array (100)" => fn -> Zoi.parse(array_schema, array_100) end,
        "array of maps (10)" => fn -> Zoi.parse(array_maps, array_maps_data) end
      },
      config
    )
  end

  # === Comparisons ===

  def comparisons(config) do
    IO.puts("\n=== Comparisons Benchmark ===\n")

    # NimbleOptions schema
    nimble_schema = [
      name: [type: :string, required: true],
      timeout: [type: :pos_integer, default: 5000],
      retry: [type: :boolean, default: false]
    ]

    # Zoi schemas
    zoi_user = Zoi.map(%{
      name: Zoi.string(),
      email: Zoi.string(),
      age: Zoi.optional(Zoi.integer()),
      active: Zoi.boolean()
    }, coerce: true)

    zoi_opts = Zoi.keyword(
      name: Zoi.string(),
      timeout: Zoi.optional(Zoi.integer() |> Zoi.min(1)) |> Zoi.default(5000),
      retry: Zoi.optional(Zoi.boolean()) |> Zoi.default(false)
    )

    # Test data
    valid_user = %{"name" => "John", "email" => "john@example.com", "age" => 30, "active" => true}
    invalid_user = %{"name" => "", "email" => "bad", "age" => "nope", "active" => "nope"}
    opts_data = [name: "service", timeout: 10_000, retry: true]

    Benchee.run(
      %{
        "Zoi: map (valid)" => fn -> Zoi.parse(zoi_user, valid_user) end,
        "Ecto: changeset (valid)" => fn -> BenchEctoUser.changeset(valid_user) end,
        "Zoi: map (invalid)" => fn -> Zoi.parse(zoi_user, invalid_user) end,
        "Ecto: changeset (invalid)" => fn -> BenchEctoUser.changeset(invalid_user) end,
        "Zoi: keyword" => fn -> Zoi.parse(zoi_opts, opts_data) end,
        "NimbleOptions" => fn -> NimbleOptions.validate(opts_data, nimble_schema) end
      },
      config
    )
  end

  # === Quick Smoke Test ===

  def quick do
    IO.puts("\n=== Quick Smoke Test ===\n")

    schema = Zoi.map(%{
      name: Zoi.string() |> Zoi.min(1),
      email: Zoi.email(),
      age: Zoi.optional(Zoi.integer())
    }, coerce: true)

    valid = %{"name" => "Test", "email" => "test@example.com", "age" => 30}
    invalid = %{"name" => "", "email" => "bad", "age" => "nope"}

    Benchee.run(
      %{
        "valid" => fn -> Zoi.parse(schema, valid) end,
        "invalid" => fn -> Zoi.parse(schema, invalid) end
      },
      warmup: 0.5,
      time: 1,
      memory_time: 0.5
    )
  end

  # === All Suites ===

  def all(config) do
    primitives(config)
    complex(config)
    comparisons(config)
  end

  defp help do
    IO.puts("""
    Zoi Benchmark Suite

    Usage:
      mix run bench/run.exs [suite]

    Suites:
      primitives   - String, integer, boolean, email, uuid, etc.
      complex      - Maps, arrays, nested structures
      comparisons  - vs Ecto.Changeset and NimbleOptions
      quick        - Fast smoke test (~5 seconds)
      all          - Run all suites (default)

    Examples:
      mix run bench/run.exs
      mix run bench/run.exs primitives
      mix run bench/run.exs quick
    """)
  end
end

# Parse args and run
suite = System.argv() |> List.first() || "all"
Zoi.Bench.run(suite)
