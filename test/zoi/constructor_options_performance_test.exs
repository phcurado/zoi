defmodule Zoi.ConstructorOptionsPerformanceTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  test "common constructors still validate invalid and unknown options" do
    constructors = [
      &Zoi.string/1,
      &Zoi.integer/1,
      &Zoi.float/1,
      &Zoi.array(Zoi.string(), &1),
      &Zoi.object([name: Zoi.string()], &1)
    ]

    for constructor <- constructors, opts <- [[coerce: "invalid"], [unknown: true]] do
      assert_raise Zoi.ParseError, fn -> constructor.(opts) end
    end
  end

  test "options retain defaults, duplicate-key behavior, and custom messages" do
    assert Zoi.parse(Zoi.integer(), "12") |> elem(0) == :error
    assert Zoi.parse(Zoi.integer(coerce: false, coerce: true), "12") == {:ok, 12}
    assert {:error, [error]} = Zoi.parse(Zoi.string(min_length: {3, [error: "too short"]}), "a")
    assert error.message == "too short"
  end

  test "empty options retain the same schema as explicit default coercion" do
    constructors = [
      &Zoi.string/1,
      &Zoi.integer/1,
      &Zoi.float/1,
      &Zoi.array(Zoi.string(), &1),
      &Zoi.object([name: Zoi.string()], &1)
    ]

    for constructor <- constructors do
      assert constructor.([]) == constructor.(coerce: false)
    end
  end

  test "deprecated strict option still emits its warning" do
    output = capture_io(:stderr, fn -> Zoi.object([name: Zoi.string()], strict: true) end)
    assert output =~ "strict"
    assert output =~ "deprecated"
  end
end
