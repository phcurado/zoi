defmodule Zoi.MetaTest do
  use ExUnit.Case, async: true

  alias Zoi.Types.Meta

  defmodule Validation do
    def integer?(input, _opts) when is_integer(input), do: :ok
    def integer?(_input, _opts), do: {:error, "Value is not an integer"}

    def integer_error?(_input, opts) do
      opts[:ctx]
      |> Zoi.Context.add_error(%{message: "Value is not an integer", path: [:test]})
    end

    def upcase(value, _opts) when is_binary(value) do
      {:ok, String.upcase(value)}
    end

    def upcase(_value, _opts), do: {:error, "Value is not a string"}

    def upcase_error(_value, opts) do
      opts[:ctx]
      |> Zoi.Context.add_error(%{message: "Value is not a string"})
    end

    def refine_valid(_input, opts), do: %{opts[:ctx] | valid?: true, parsed: "valid", errors: []}
    def refine_nil(_input, opts), do: opts[:ctx] |> Zoi.Context.add_parsed(nil) |> Zoi.Context.add_error("nil")
    def refine_partial(_input, opts), do: opts[:ctx] |> Zoi.Context.add_parsed("partial") |> Zoi.Context.add_error("partial")
    def refine_error_partial(_input, _opts), do: {:error, "partial error", "partial_data"}
    def transform_valid(_input, opts), do: %{opts[:ctx] | valid?: true, parsed: "valid", errors: []}
    def transform_nil(_input, opts), do: opts[:ctx] |> Zoi.Context.add_parsed(nil) |> Zoi.Context.add_error("nil")
    def transform_partial(_input, opts), do: opts[:ctx] |> Zoi.Context.add_parsed("partial") |> Zoi.Context.add_error("partial")
    def transform_error_partial(_input, _opts), do: {:error, "partial error", "partial_data"}
  end

  describe "create_meta/1" do
    test "creates a meta struct with effects" do
      opts = [
        effects: [{:refine, &is_integer/1}, {:transform, &String.upcase/1}],
        extra_param: "value"
      ]

      assert {%Meta{effects: effects}, rest} = Meta.create_meta(opts)

      assert effects == [{:refine, &is_integer/1}, {:transform, &String.upcase/1}]
      assert rest == [extra_param: "value"]
    end

    test "returns an empty meta struct when no options are provided" do
      {meta, rest} = Meta.create_meta([])

      assert %Meta{effects: []} = meta
      assert rest == []
    end
  end

  describe "run_effects/1 with refinements" do
    test "runs refinements and returns ok for valid input" do
      schema =
        Zoi.integer()
        |> Zoi.refine(fn val ->
          if val > 10 do
            :ok
          else
            {:error, "Value is smaller or equal to 10"}
          end
        end)

      ctx = Zoi.Context.new(schema, 42) |> Zoi.Context.add_parsed(42)
      assert {:ok, %{parsed: 42}} = Meta.run_effects(ctx)

      ctx = Zoi.Context.new(schema, 9) |> Zoi.Context.add_parsed(9)
      assert {:error, %{errors: [%Zoi.Error{} = error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "Value is smaller or equal to 10"
    end

    test "refinement with mfa" do
      schema = Zoi.integer() |> Zoi.refine({Validation, :integer?, []})

      ctx = Zoi.Context.new(schema, 42) |> Zoi.Context.add_parsed(42)
      assert {:ok, %{parsed: 42}} = Meta.run_effects(ctx)

      ctx = Zoi.Context.new(schema, "55") |> Zoi.Context.add_parsed("55")
      assert {:error, %{errors: [%Zoi.Error{} = error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "Value is not an integer"
    end

    test "accumulates errors from refinements" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _val -> {:error, "refinement error 1"} end)
        |> Zoi.refine(fn _val -> {:error, "refinement error 2"} end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{errors: [error_1, error_2]}} = Meta.run_effects(ctx)
      assert Exception.message(error_1) == "refinement error 1"
      assert Exception.message(error_2) == "refinement error 2"
    end

    test "return multiple errors from a single refinement" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _val, ctx ->
          Zoi.Context.add_error(ctx, %{message: "refinement error 1", path: [:test]})
          |> Zoi.Context.add_error("refinement error 2")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{errors: [error_1, error_2]}} = Meta.run_effects(ctx)
      assert Exception.message(error_1) == "refinement error 1"
      assert Exception.message(error_2) == "refinement error 2"
    end

    test "return multiple errors from a refinement with mfa" do
      schema = Zoi.string() |> Zoi.refine({Validation, :integer_error?, []})

      ctx = Zoi.Context.new(schema, "not an integer") |> Zoi.Context.add_parsed("not an integer")
      assert {:error, %{errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "Value is not an integer"
    end

    test "refinement returning context with unchanged parsed" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn input, ctx ->
          ctx
          |> Zoi.Context.add_parsed(input)
          |> Zoi.Context.add_error("unchanged")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: nil, errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "unchanged"
    end

    test "refinement returning context with nil parsed" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _input, ctx ->
          ctx
          |> Zoi.Context.add_parsed(nil)
          |> Zoi.Context.add_error("nil parsed")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: nil, errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "nil parsed"
    end

    test "refinement returning valid context from function" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _input, ctx ->
          %{ctx | valid?: true, parsed: "from_fn", errors: []}
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:ok, %{parsed: "from_fn"}} = Meta.run_effects(ctx)
    end

    test "refinement returning context with different parsed" do
      schema =
        Zoi.string()
        |> Zoi.refine(fn _input, ctx ->
          ctx
          |> Zoi.Context.add_parsed("partial")
          |> Zoi.Context.add_error("has partial")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: "partial", errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "has partial"
    end

    test "mfa refinement returning error with partial" do
      schema = Zoi.string() |> Zoi.refine({Validation, :refine_error_partial, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: "partial_data"}} = Meta.run_effects(ctx)
    end

    test "mfa refinement returning valid context" do
      schema = Zoi.string() |> Zoi.refine({Validation, :refine_valid, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:ok, %{parsed: "valid"}} = Meta.run_effects(ctx)
    end

    test "mfa refinement returning context with nil parsed" do
      schema = Zoi.string() |> Zoi.refine({Validation, :refine_nil, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: nil}} = Meta.run_effects(ctx)
    end

    test "mfa refinement returning context with partial" do
      schema = Zoi.string() |> Zoi.refine({Validation, :refine_partial, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: "partial"}} = Meta.run_effects(ctx)
    end

    test "returns partial from refinement errors" do
      schema =
        Zoi.map(%{sku: Zoi.string(), qty: Zoi.integer()})
        |> Zoi.refine(fn %{sku: sku} ->
          {:error, "qty is invalid", %{sku: sku}}
        end)

      input = %{sku: "A", qty: -1}
      ctx = Zoi.Context.new(schema, input) |> Zoi.Context.add_parsed(input)

      assert {:error, %{parsed: %{sku: "A"}, errors: [%Zoi.Error{} = error]}} =
               Meta.run_effects(ctx)

      assert Exception.message(error) == "qty is invalid"
    end
  end

  describe "run_effects/1 with transforms" do
    test "runs transforms and returns the transformed value" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn input ->
          String.trim(input)
        end)
        |> Zoi.transform({Validation, :upcase, []})

      ctx = Zoi.Context.new(schema, "   hello   ") |> Zoi.Context.add_parsed("   hello   ")
      assert {:ok, %{parsed: "HELLO"}} = Meta.run_effects(ctx)
    end

    test "runs transforms and returns the tuple for valid input" do
      schema = Zoi.string() |> Zoi.transform(fn _val -> {:ok, "random return"} end)

      ctx = Zoi.Context.new(schema, "hello") |> Zoi.Context.add_parsed("hello")
      assert {:ok, %{parsed: "random return"}} = Meta.run_effects(ctx)
    end

    test "returns error for invalid transform" do
      schema = Zoi.string() |> Zoi.transform(fn _val -> {:error, "Transform failed"} end)

      ctx = Zoi.Context.new(schema, "not a number") |> Zoi.Context.add_parsed("not a number")
      assert {:error, %{errors: [%Zoi.Error{} = error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "Transform failed"
    end

    test "returns error for invalid transform using mfa" do
      schema = Zoi.string() |> Zoi.transform({Validation, :upcase, []})

      ctx = Zoi.Context.new(schema, 12) |> Zoi.Context.add_parsed(12)
      assert {:error, %{errors: [%Zoi.Error{} = error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "Value is not a string"
    end

    test "accumulates errors from transforms" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _val -> {:error, "transform error 1"} end)
        |> Zoi.transform(fn _val -> {:error, "transform error 2"} end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{errors: [error_1, error_2]}} = Meta.run_effects(ctx)
      assert Exception.message(error_1) == "transform error 1"
      assert Exception.message(error_2) == "transform error 2"
    end

    test "return multiple errors from a single transform" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _val, ctx ->
          Zoi.Context.add_error(ctx, %{message: "transform error 1", path: [:test]})
          |> Zoi.Context.add_error("transform error 2")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{errors: [error_1, error_2]}} = Meta.run_effects(ctx)
      assert Exception.message(error_1) == "transform error 1"
      assert Exception.message(error_2) == "transform error 2"
    end

    test "return multiple errors from a transform with mfa" do
      schema = Zoi.string() |> Zoi.transform({Validation, :upcase_error, []})

      ctx = Zoi.Context.new(schema, 12) |> Zoi.Context.add_parsed(12)
      assert {:error, %{errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "Value is not a string"
    end

    test "transform returning context with unchanged parsed" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn input, ctx ->
          ctx
          |> Zoi.Context.add_parsed(input)
          |> Zoi.Context.add_error("unchanged")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: nil, errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "unchanged"
    end

    test "transform returning context with nil parsed" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _input, ctx ->
          ctx
          |> Zoi.Context.add_parsed(nil)
          |> Zoi.Context.add_error("nil parsed")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: nil, errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "nil parsed"
    end

    test "transform returning valid context from function" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _input, ctx ->
          %{ctx | valid?: true, parsed: "from_fn", errors: []}
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:ok, %{parsed: "from_fn"}} = Meta.run_effects(ctx)
    end

    test "transform returning context with different parsed" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn _input, ctx ->
          ctx
          |> Zoi.Context.add_parsed("partial")
          |> Zoi.Context.add_error("has partial")
        end)

      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: "partial", errors: [error]}} = Meta.run_effects(ctx)
      assert Exception.message(error) == "has partial"
    end

    test "mfa transform returning error with partial" do
      schema = Zoi.string() |> Zoi.transform({Validation, :transform_error_partial, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: "partial_data"}} = Meta.run_effects(ctx)
    end

    test "mfa transform returning valid context" do
      schema = Zoi.string() |> Zoi.transform({Validation, :transform_valid, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:ok, %{parsed: "valid"}} = Meta.run_effects(ctx)
    end

    test "mfa transform returning context with nil parsed" do
      schema = Zoi.string() |> Zoi.transform({Validation, :transform_nil, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: nil}} = Meta.run_effects(ctx)
    end

    test "mfa transform returning context with partial" do
      schema = Zoi.string() |> Zoi.transform({Validation, :transform_partial, []})
      ctx = Zoi.Context.new(schema, "test") |> Zoi.Context.add_parsed("test")
      assert {:error, %{parsed: "partial"}} = Meta.run_effects(ctx)
    end

    test "keeps transforming explicit partials after an error" do
      schema =
        Zoi.string()
        |> Zoi.transform(fn input -> {:error, "transform error", String.trim(input)} end)
        |> Zoi.transform(&String.upcase/1)

      ctx = Zoi.Context.new(schema, "  hello  ") |> Zoi.Context.add_parsed("  hello  ")

      assert {:error, %{parsed: "HELLO", errors: [%Zoi.Error{} = error]}} =
               Meta.run_effects(ctx)

      assert Exception.message(error) == "transform error"
    end
  end

  describe "required?/1" do
    test "returns true if the meta is marked as required" do
      meta = %Meta{required: true}
      assert Meta.required?(meta) == true
    end

    test "returns false if the meta is not marked as required" do
      meta = %Meta{required: false}
      assert Meta.required?(meta) == false
    end

    test "returns false if the meta's required field is nil" do
      meta = %Meta{required: nil}
      assert Meta.required?(meta) == false
    end
  end

  describe "optional?/1" do
    test "returns true if the meta is marked as optional" do
      meta = %Meta{required: false}
      assert Meta.optional?(meta) == true
    end

    test "returns false if the meta is marked as required" do
      meta = %Meta{required: true}
      assert Meta.optional?(meta) == false
    end

    test "returns true if the meta's required field is nil" do
      meta = %Meta{required: nil}
      assert Meta.optional?(meta) == true
    end
  end
end
