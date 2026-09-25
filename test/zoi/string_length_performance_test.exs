defmodule Zoi.StringLengthPerformanceTest do
  use ExUnit.Case, async: true

  test "combined length checks match each protocol check, including error order" do
    for input <- ["", "abc", "e\u0301", "👩‍👩‍👧‍👦", <<255, 0>>],
        min <- [-1, 0, 1, 3, 10],
        max <- [-1, 0, 1, 3, 10] do
      min_opts = [error: "too short"]
      max_opts = [error: "too long"]
      schema = Zoi.string() |> Zoi.min(min, min_opts) |> Zoi.max(max, max_opts)

      errors =
        [
          Zoi.Validations.Gte.validate(schema, input, min, min_opts),
          Zoi.Validations.Lte.validate(schema, input, max, max_opts)
        ]
        |> Enum.flat_map(fn
          :ok -> []
          {:error, error} -> [error]
        end)

      expected = if errors == [], do: {:ok, input}, else: {:error, errors}
      assert Zoi.parse(schema, input) == expected
    end
  end

  test "exact length replaces both bounds" do
    schema = Zoi.string() |> Zoi.min(10) |> Zoi.max(0) |> Zoi.length(1)
    assert Zoi.parse(schema, "e\u0301") == {:ok, "e\u0301"}
    assert {:error, [%Zoi.Error{code: :invalid_length}]} = Zoi.parse(schema, "ab")
  end
end
