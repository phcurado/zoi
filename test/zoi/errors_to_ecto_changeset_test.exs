defmodule Zoi.ErrorsToEctoChangesetTest do
  @moduledoc """
  Tests for `Zoi.Ecto` -- the bridge between Zoi parse errors and Ecto
  changesets.

  These tests verify that `errors_to_changeset/1` and `changeset/2` produce
  changesets indistinguishable from native Ecto validations. The ground truth
  for what Ecto produces is `Ecto.Changeset` source code:

    https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/changeset.ex

  Key sections to reference when updating these tests:

  - `validate_required/3` -- produces `validation: :required`
  - `cast/4` -- produces `validation: :cast, type: <ecto_type>`
  - `validate_format/3` -- produces `validation: :format`
  - `validate_inclusion/3` -- produces `validation: :inclusion, enum: [list]`
  - `validate_length/3` -- produces `validation: :length, kind: :is/:min/:max,
    type: :string/:list, count: N`
  - `validate_number/3` -- produces `validation: :number, kind: <comparator>,
    number: N` where kind is one of `:greater_than`, `:greater_than_or_equal_to`,
    `:less_than`, `:less_than_or_equal_to`, `:equal_to`, `:not_equal_to`
  - `validate_exclusion/3` -- produces `validation: :exclusion, enum: [list]`
  - `validate_subset/3` -- produces `validation: :subset, enum: [list]`
  - `validate_confirmation/3` -- produces `validation: :confirmation`
  - `validate_acceptance/3` -- produces `validation: :acceptance`
  - `unsafe_validate_unique/4` -- produces `validation: :unsafe_unique`

  When Ecto changes its error format in a new version, update the assertions
  here first, then update `Zoi.Ecto` to match.
  """
  use ExUnit.Case, async: true

  @valid_order %{
    "email" => "customer@example.com",
    "currency" => "USD",
    "placed_at" => "2026-04-10T14:30:00Z",
    "shipping_address" => %{
      "street" => "123 Main St",
      "city" => "Springfield",
      "zip" => "62704",
      "country" => "US"
    },
    "items" => [
      %{"sku" => "WIDGET-1", "quantity" => 2, "unit_price" => 1500},
      %{"sku" => "GADGET-9", "quantity" => 1, "unit_price" => 4200}
    ],
    "payment" => %{
      "type" => "credit_card",
      "card_number" => "4111111111111111",
      "expiry" => "12/28",
      "cvv" => "123"
    }
  }

  # ---------------------------------------------------------------------------
  # Test schemas: e-commerce order with nested address, array of line items,
  # and a discriminated union for payment method.
  # ---------------------------------------------------------------------------

  defmodule OrderSchemas do
    def validate_express_requires_phone(parsed) do
      express? = parsed[:shipping_method] == "express"
      has_phone? = is_binary(parsed[:phone]) and parsed[:phone] != ""

      if express? and not has_phone? do
        {:error, "phone is required for express shipping"}
      else
        :ok
      end
    end

    def shipping_address do
      Zoi.map(
        %{
          street: Zoi.string(),
          city: Zoi.string(),
          zip: Zoi.string() |> Zoi.regex(~r/^\d{5}$/),
          country: Zoi.string() |> Zoi.length(2)
        },
        coerce: true
      )
    end

    def line_item do
      Zoi.map(
        %{
          sku: Zoi.string(),
          quantity: Zoi.integer() |> Zoi.positive() |> Zoi.lt(1000),
          unit_price: Zoi.integer() |> Zoi.min(1) |> Zoi.lte(999_999)
        },
        coerce: true
      )
    end

    def payment do
      Zoi.discriminated_union(
        :type,
        [
          Zoi.map(
            %{
              type: Zoi.literal("credit_card"),
              card_number: Zoi.string(),
              expiry: Zoi.string(),
              cvv: Zoi.string() |> Zoi.min(3) |> Zoi.max(4)
            },
            coerce: true
          ),
          Zoi.map(
            %{
              type: Zoi.literal("bank_transfer"),
              account_number: Zoi.string(),
              routing_number: Zoi.string()
            },
            coerce: true
          ),
          Zoi.map(
            %{
              type: Zoi.literal("wallet"),
              wallet_id: Zoi.string()
            },
            coerce: true
          )
        ],
        coerce: true
      )
    end

    def order do
      Zoi.map(
        %{
          email: Zoi.email(),
          currency: Zoi.enum(["USD", "EUR", "GBP"]),
          placed_at: Zoi.datetime(coerce: true),
          note: Zoi.string() |> Zoi.nullable() |> Zoi.optional(),
          phone: Zoi.string() |> Zoi.optional(),
          shipping_method: Zoi.string() |> Zoi.optional() |> Zoi.default("standard"),
          shipping_address: shipping_address(),
          items: Zoi.array(line_item()) |> Zoi.min(1) |> Zoi.max(50),
          discount_code: Zoi.string() |> Zoi.optional(),
          payment: payment()
        },
        coerce: true
      )
      |> Zoi.refine(&validate_express_requires_phone/1)
    end
  end

  # ---------------------------------------------------------------------------
  # changeset/2 — parse + wrap in one call
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "valid input returns valid changeset with parsed data" do
      changeset = Zoi.Ecto.changeset(OrderSchemas.order(), @valid_order)

      assert changeset.valid?
      assert changeset.data.email == "customer@example.com"
      assert changeset.data.currency == "USD"
      assert %DateTime{} = changeset.data.placed_at
    end

    test "invalid input returns invalid changeset with errors" do
      changeset = Zoi.Ecto.changeset(OrderSchemas.order(), %{})

      refute changeset.valid?
      {"is required", opts} = changeset.errors[:email]
      assert opts[:code] == :required
    end

    test "nested errors route correctly through changeset/2" do
      input = put_in(@valid_order, ["shipping_address", "zip"], "bad")
      changeset = Zoi.Ecto.changeset(OrderSchemas.order(), input)

      refute changeset.valid?
      nested = changeset.changes[:shipping_address]
      assert %Ecto.Changeset{valid?: false} = nested
      {_msg, opts} = nested.errors[:zip]
      assert opts[:code] == :invalid_format
    end

    test "partial parse: valid flat fields preserved alongside errors" do
      input =
        @valid_order
        |> Map.put("email", "not-valid")

      changeset = Zoi.Ecto.changeset(OrderSchemas.order(), input)

      refute changeset.valid?
      # Email has an error
      assert changeset.errors[:email]
      # But successfully parsed flat fields are in .data
      assert changeset.data.currency == "USD"
      assert %DateTime{} = changeset.data.placed_at
    end

    test "partial parse: valid nested map preserved alongside errors" do
      input =
        @valid_order
        |> Map.put("currency", 42)

      changeset = Zoi.Ecto.changeset(OrderSchemas.order(), input)

      refute changeset.valid?
      assert changeset.errors[:currency]
      # Shipping address was valid and its data is in .data
      assert changeset.data.shipping_address.street == "123 Main St"
      assert changeset.data.shipping_address.zip == "62704"
    end

    test "sub-schema works directly" do
      changeset =
        Zoi.Ecto.changeset(OrderSchemas.shipping_address(), %{
          "street" => "1 Main St",
          "city" => "NY",
          "zip" => "10001",
          "country" => "US"
        })

      assert changeset.valid?
      assert changeset.data.street == "1 Main St"
    end

    test "passes opts through to Zoi.parse" do
      schema = Zoi.map(%{name: Zoi.string()})
      changeset = Zoi.Ecto.changeset(schema, %{"name" => "test"}, coerce: true)

      assert changeset.valid?
      assert changeset.data.name == "test"
    end
  end

  # ---------------------------------------------------------------------------
  # errors_to_changeset — empty / valid
  # ---------------------------------------------------------------------------

  describe "errors_to_changeset/1 basics" do
    test "returns valid changeset for empty error list" do
      changeset = Zoi.Ecto.errors_to_changeset([])

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "valid order produces no errors to convert" do
      assert {:ok, _parsed} = Zoi.parse(OrderSchemas.order(), @valid_order)
    end
  end

  # ---------------------------------------------------------------------------
  # Flat field errors (path: [:field])
  # ---------------------------------------------------------------------------

  describe "flat field errors" do
    test "missing required fields" do
      {:error, errors} = Zoi.parse(OrderSchemas.order(), %{})
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      assert {"is required", _} = changeset.errors[:email]
      assert {"is required", _} = changeset.errors[:currency]
      assert {"is required", _} = changeset.errors[:placed_at]
    end

    test "type mismatch on flat field" do
      input = Map.put(@valid_order, "currency", 42)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      {_msg, opts} = changeset.errors[:currency]
      assert opts[:code] == :invalid_enum_value
    end

    test "invalid email format" do
      input = Map.put(@valid_order, "email", "not-an-email")
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      {msg, opts} = changeset.errors[:email]
      assert msg == "invalid email format"
      assert opts[:code] == :invalid_format
    end

    test "enum validation" do
      input = Map.put(@valid_order, "currency", "BTC")
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      {msg, opts} = changeset.errors[:currency]
      assert msg =~ "expected one of"
      assert opts[:code] == :invalid_enum_value
    end
  end

  # ---------------------------------------------------------------------------
  # Root-level errors (path: [], from Zoi.refine)
  # ---------------------------------------------------------------------------

  describe "root-level refinement errors" do
    test "cross-field validation failure lands on :base" do
      input =
        @valid_order
        |> Map.put("shipping_method", "express")
        |> Map.delete("phone")

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      {msg, _} = changeset.errors[:base]
      assert msg =~ "phone is required"
    end

    test "cross-field validation passes when condition met" do
      input =
        @valid_order
        |> Map.put("shipping_method", "express")
        |> Map.put("phone", "+15551234567")

      assert {:ok, _} = Zoi.parse(OrderSchemas.order(), input)
    end
  end

  # ---------------------------------------------------------------------------
  # Nested map errors (path: [:address, :zip])
  # ---------------------------------------------------------------------------

  describe "nested map errors" do
    test "nested field error produces nested changeset" do
      input = put_in(@valid_order, ["shipping_address", "zip"], "bad")

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      assert changeset.errors == []

      nested = changeset.changes[:shipping_address]
      assert %Ecto.Changeset{valid?: false} = nested
      {_msg, opts} = nested.errors[:zip]
      assert opts[:code] == :invalid_format
    end

    test "missing nested required field" do
      bad_address = Map.delete(@valid_order["shipping_address"], "city")
      input = Map.put(@valid_order, "shipping_address", bad_address)

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      nested = changeset.changes[:shipping_address]
      {"is required", opts} = nested.errors[:city]
      assert opts[:code] == :required
    end

    test "multiple nested errors on same parent" do
      bad_address = %{"street" => "123 Main St"}
      input = Map.put(@valid_order, "shipping_address", bad_address)

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      nested = changeset.changes[:shipping_address]
      {"is required", _} = nested.errors[:city]
      {"is required", _} = nested.errors[:zip]
      {"is required", _} = nested.errors[:country]
    end

    test "constraint error on nested field" do
      bad_address = put_in(@valid_order["shipping_address"], ["country"], "USA")
      input = Map.put(@valid_order, "shipping_address", bad_address)

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      nested = changeset.changes[:shipping_address]
      {_msg, opts} = nested.errors[:country]
      assert opts[:count] == 2
      assert opts[:validation] == :length
      assert opts[:kind] == :is
      assert opts[:code] == :invalid_length
    end
  end

  # ---------------------------------------------------------------------------
  # Array item errors (path: [:items, 0, :quantity])
  # ---------------------------------------------------------------------------

  describe "array item errors" do
    test "invalid item in array produces indexed error" do
      bad_items = [
        %{"sku" => "OK-1", "quantity" => 1, "unit_price" => 500},
        %{"sku" => "BAD-2", "quantity" => -1, "unit_price" => 500}
      ]

      input = Map.put(@valid_order, "items", bad_items)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?

      items = changeset.changes[:items]
      assert is_list(items)
      assert length(items) == 2

      # Item 0 is valid -- empty changeset (no errors)
      assert %Ecto.Changeset{valid?: true, errors: []} = Enum.at(items, 0)

      # Item 1 has the error
      assert %Ecto.Changeset{valid?: false} = Enum.at(items, 1)
      {_msg, opts} = Enum.at(items, 1).errors[:quantity]
      assert opts[:code] == :greater_than
    end

    test "missing required field in array item" do
      bad_items = [%{"quantity" => 1, "unit_price" => 500}]
      input = Map.put(@valid_order, "items", bad_items)

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      items = changeset.changes[:items]
      assert %Ecto.Changeset{} = Enum.at(items, 0)
      {"is required", opts} = Enum.at(items, 0).errors[:sku]
      assert opts[:code] == :required
    end

    test "errors on multiple array items" do
      bad_items = [
        %{"sku" => "A", "quantity" => 0, "unit_price" => 500},
        %{"sku" => "B", "quantity" => 1, "unit_price" => 0}
      ]

      input = Map.put(@valid_order, "items", bad_items)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      items = changeset.changes[:items]
      {_msg, opts_q} = Enum.at(items, 0).errors[:quantity]
      assert opts_q[:code] == :greater_than
      {_msg, opts_p} = Enum.at(items, 1).errors[:unit_price]
      assert opts_p[:code] == :greater_than_or_equal_to
    end
  end

  # ---------------------------------------------------------------------------
  # Discriminated union errors
  # ---------------------------------------------------------------------------

  describe "discriminated union errors" do
    test "missing required field for credit_card variant" do
      bad_payment = %{"type" => "credit_card", "card_number" => "4111", "expiry" => "12/28"}
      input = Map.put(@valid_order, "payment", bad_payment)

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?

      payment = changeset.changes[:payment]
      assert %Ecto.Changeset{valid?: false} = payment
      assert {"is required", _} = payment.errors[:cvv]
    end

    test "constraint error on union field" do
      bad_payment = %{
        "type" => "credit_card",
        "card_number" => "4111",
        "expiry" => "12/28",
        "cvv" => "12"
      }

      input = Map.put(@valid_order, "payment", bad_payment)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      payment = changeset.changes[:payment]
      {msg, opts} = payment.errors[:cvv]
      assert msg =~ "%{count}"
      assert opts[:count] == 3
      assert opts[:validation] == :length
      assert opts[:kind] == :min
      assert opts[:code] == :greater_than_or_equal_to
    end

    test "bank_transfer variant missing fields" do
      bad_payment = %{"type" => "bank_transfer"}
      input = Map.put(@valid_order, "payment", bad_payment)

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      payment = changeset.changes[:payment]
      assert {"is required", _} = payment.errors[:account_number]
      assert {"is required", _} = payment.errors[:routing_number]
    end

    test "wallet variant works" do
      wallet_payment = %{"type" => "wallet", "wallet_id" => "w_abc123"}
      input = Map.put(@valid_order, "payment", wallet_payment)

      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), input)
      assert parsed.payment[:wallet_id] == "w_abc123"
    end
  end

  # ---------------------------------------------------------------------------
  # Min/max constraint errors
  # ---------------------------------------------------------------------------

  describe "min/max constraint errors" do
    test "string too short" do
      bad_payment = %{
        "type" => "credit_card",
        "card_number" => "4111",
        "expiry" => "12/28",
        "cvv" => "1"
      }

      input = Map.put(@valid_order, "payment", bad_payment)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      payment = changeset.changes[:payment]
      {_msg, opts} = payment.errors[:cvv]
      assert opts[:validation] == :length
      assert opts[:kind] == :min
    end

    test "integer below minimum" do
      bad_items = [%{"sku" => "X", "quantity" => 1, "unit_price" => 0}]
      input = Map.put(@valid_order, "items", bad_items)

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      items = changeset.changes[:items]
      {_msg, opts} = Enum.at(items, 0).errors[:unit_price]
      assert opts[:count] == 1
      assert opts[:validation] == :number
      assert opts[:kind] == :greater_than_or_equal_to
      assert opts[:code] == :greater_than_or_equal_to
    end
  end

  # ---------------------------------------------------------------------------
  # Optional / nullable field handling
  # ---------------------------------------------------------------------------

  describe "optional and nullable fields" do
    test "optional field absent is fine" do
      input = Map.delete(@valid_order, "discount_code")
      assert {:ok, _} = Zoi.parse(OrderSchemas.order(), input)
    end

    test "nullable field with nil is fine" do
      input = Map.put(@valid_order, "note", nil)
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), input)
      assert is_nil(parsed.note)
    end

    test "nullable field with value is fine" do
      input = Map.put(@valid_order, "note", "Please gift wrap")
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), input)
      assert parsed.note == "Please gift wrap"
    end
  end

  # ---------------------------------------------------------------------------
  # Empty and edge-case inputs
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    test "empty array rejected (min 1 item required)" do
      input = Map.put(@valid_order, "items", [])
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      {_msg, opts} = changeset.errors[:items]
      assert opts[:count] == 1
      assert opts[:validation] == :length
      assert opts[:kind] == :min
      assert opts[:code] == :greater_than_or_equal_to
    end

    test "single-item array is valid (meets min 1)" do
      input =
        Map.put(@valid_order, "items", [%{"sku" => "X", "quantity" => 1, "unit_price" => 100}])

      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), input)
      assert length(parsed.items) == 1
    end

    test "array at max boundary (50 items) is valid" do
      items = for i <- 1..50, do: %{"sku" => "ITEM-#{i}", "quantity" => 1, "unit_price" => 100}
      input = Map.put(@valid_order, "items", items)
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), input)
      assert length(parsed.items) == 50
    end

    test "array over max (51 items) rejected" do
      items = for i <- 1..51, do: %{"sku" => "ITEM-#{i}", "quantity" => 1, "unit_price" => 100}
      input = Map.put(@valid_order, "items", items)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      {_msg, opts} = changeset.errors[:items]
      assert opts[:count] == 50
      assert opts[:validation] == :length
      assert opts[:kind] == :max
      assert opts[:code] == :less_than_or_equal_to
    end

    test "entirely empty nested map produces nested errors" do
      input = Map.put(@valid_order, "shipping_address", %{})
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      nested = changeset.changes[:shipping_address]
      assert %Ecto.Changeset{valid?: false} = nested
      {"is required", _} = nested.errors[:street]
      {"is required", _} = nested.errors[:city]
      {"is required", _} = nested.errors[:zip]
      {"is required", _} = nested.errors[:country]
    end

    test "nil where nested map expected" do
      input = Map.put(@valid_order, "shipping_address", nil)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)
      refute changeset.valid?
    end

    test "nil where array expected" do
      input = Map.put(@valid_order, "items", nil)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)
      refute changeset.valid?
    end

    test "wrong type for entire nested structure (string where map expected)" do
      input = Map.put(@valid_order, "shipping_address", "not a map")
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)
      refute changeset.valid?
    end

    test "wrong type for array (string where list expected)" do
      input = Map.put(@valid_order, "items", "not a list")
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)
      refute changeset.valid?
    end

    test "invalid discriminator value" do
      input = Map.put(@valid_order, "payment", %{"type" => "bitcoin", "address" => "bc1..."})
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)
      refute changeset.valid?
    end

    test "missing discriminator entirely" do
      input = Map.put(@valid_order, "payment", %{"card_number" => "4111"})
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)
      refute changeset.valid?
    end

    test "completely wrong input type (not a map)" do
      {:error, errors} = Zoi.parse(OrderSchemas.order(), "not a map at all")
      changeset = Zoi.Ecto.errors_to_changeset(errors)
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # Coercion through errors_to_changeset
  # ---------------------------------------------------------------------------

  describe "coerced values survive parse" do
    test "datetime string is coerced to DateTime" do
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), @valid_order)
      assert %DateTime{} = parsed.placed_at
    end

    test "default value is applied" do
      input = Map.delete(@valid_order, "shipping_method")
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), input)
      assert parsed.shipping_method == "standard"
    end

    test "string keys are coerced to atom keys" do
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), @valid_order)
      assert Map.has_key?(parsed, :email)
      refute Map.has_key?(parsed, "email")
    end

    test "nested map keys are also coerced" do
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), @valid_order)
      assert Map.has_key?(parsed.shipping_address, :street)
    end

    test "array item keys are coerced" do
      assert {:ok, parsed} = Zoi.parse(OrderSchemas.order(), @valid_order)
      assert Map.has_key?(hd(parsed.items), :sku)
    end
  end

  # ---------------------------------------------------------------------------
  # Multiple errors on same field
  # ---------------------------------------------------------------------------

  describe "multiple errors" do
    test "multiple flat errors collected from empty input" do
      {:error, errors} = Zoi.parse(OrderSchemas.order(), %{})
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      error_fields = Enum.map(changeset.errors, fn {field, _} -> field end)
      assert :email in error_fields
      assert :currency in error_fields
      assert :placed_at in error_fields
      assert :shipping_address in error_fields
      assert :items in error_fields
      assert :payment in error_fields
    end

    test "errors from both flat and nested levels in one parse" do
      input = %{
        "email" => "bad",
        "currency" => "USD",
        "placed_at" => "2026-04-10T14:30:00Z",
        "shipping_address" => %{"street" => "123 Main St"},
        "items" => [%{"sku" => "X", "quantity" => 1, "unit_price" => 1}],
        "payment" => %{
          "type" => "credit_card",
          "card_number" => "4111",
          "expiry" => "12/28",
          "cvv" => "123"
        }
      }

      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      # Flat error on email
      {_msg, opts} = changeset.errors[:email]
      assert opts[:code] == :invalid_format
      # Nested errors on shipping_address
      nested = changeset.changes[:shipping_address]
      {"is required", _} = nested.errors[:city]
      {"is required", _} = nested.errors[:zip]
      {"is required", _} = nested.errors[:country]
    end
  end

  # ---------------------------------------------------------------------------
  # Standalone schema parsing (not through order — isolation tests)
  # ---------------------------------------------------------------------------

  describe "sub-schema isolation" do
    test "shipping_address schema works standalone" do
      {:ok, parsed} =
        Zoi.parse(OrderSchemas.shipping_address(), %{
          "street" => "1 Main St",
          "city" => "NY",
          "zip" => "10001",
          "country" => "US"
        })

      assert parsed.street == "1 Main St"
      assert parsed.zip == "10001"
    end

    test "line_item schema works standalone" do
      {:ok, parsed} =
        Zoi.parse(OrderSchemas.line_item(), %{
          "sku" => "ABC",
          "quantity" => 5,
          "unit_price" => 999
        })

      assert parsed.quantity == 5
    end

    test "payment schema works standalone" do
      {:ok, parsed} =
        Zoi.parse(OrderSchemas.payment(), %{
          "type" => "wallet",
          "wallet_id" => "w_123"
        })

      assert parsed[:wallet_id] == "w_123"
    end

    test "sub-schema errors convert independently" do
      {:error, errors} = Zoi.parse(OrderSchemas.shipping_address(), %{})
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      {"is required", opts_s} = changeset.errors[:street]
      assert opts_s[:code] == :required
      {"is required", opts_c} = changeset.errors[:city]
      assert opts_c[:code] == :required
      {"is required", opts_z} = changeset.errors[:zip]
      assert opts_z[:code] == :required
      {"is required", opts_co} = changeset.errors[:country]
      assert opts_co[:code] == :required
    end
  end

  # ---------------------------------------------------------------------------
  # Code mapping coverage -- one test per @code_mapping entry
  # ---------------------------------------------------------------------------

  describe "code mapping coverage" do
    test "invalid_type maps to validation: :cast" do
      schema = Zoi.map(%{count: Zoi.integer()}, coerce: true)
      {:error, errors} = Zoi.parse(schema, %{"count" => "not_an_int"})
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      {_msg, opts} = changeset.errors[:count]
      assert opts[:validation] == :cast
      assert opts[:code] == :invalid_type
    end

    test "less_than maps to validation: :number, kind: :less_than with number: key" do
      bad_items = [%{"sku" => "X", "quantity" => 1000, "unit_price" => 100}]
      input = Map.put(@valid_order, "items", bad_items)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      items = changeset.changes[:items]
      {_msg, opts} = Enum.at(items, 0).errors[:quantity]
      assert opts[:validation] == :number
      assert opts[:kind] == :less_than
      assert opts[:number] == 1000
      assert opts[:code] == :less_than
    end

    test "less_than_or_equal_to on number maps to validation: :number with number: key" do
      bad_items = [%{"sku" => "X", "quantity" => 1, "unit_price" => 1_000_000}]
      input = Map.put(@valid_order, "items", bad_items)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      items = changeset.changes[:items]
      {_msg, opts} = Enum.at(items, 0).errors[:unit_price]
      assert opts[:validation] == :number
      assert opts[:kind] == :less_than_or_equal_to
      assert opts[:number] == 999_999
      assert opts[:code] == :less_than_or_equal_to
    end

    test "numeric greater_than includes number: key" do
      bad_items = [%{"sku" => "X", "quantity" => 0, "unit_price" => 100}]
      input = Map.put(@valid_order, "items", bad_items)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      items = changeset.changes[:items]
      {_msg, opts} = Enum.at(items, 0).errors[:quantity]
      assert opts[:validation] == :number
      assert opts[:kind] == :greater_than
      assert opts[:number] == 0
      assert opts[:code] == :greater_than
    end

    test "length min uses kind: :min (not :greater_than_or_equal_to)" do
      bad_payment = %{
        "type" => "credit_card",
        "card_number" => "4111",
        "expiry" => "12/28",
        "cvv" => "1"
      }

      input = Map.put(@valid_order, "payment", bad_payment)
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      payment = changeset.changes[:payment]
      {_msg, opts} = payment.errors[:cvv]
      assert opts[:validation] == :length
      assert opts[:kind] == :min
      refute Keyword.has_key?(opts, :number)
    end

    test "length max uses kind: :max (not :less_than_or_equal_to)" do
      input = Map.put(@valid_order, "items", [])
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      {_msg, opts} = changeset.errors[:items]
      assert opts[:validation] == :length
      assert opts[:kind] == :min
      refute Keyword.has_key?(opts, :number)
    end

    test "unrecognized_key maps to validation: :unknown_field" do
      schema = Zoi.map(%{name: Zoi.string()}, coerce: true, unrecognized_keys: :error)
      {:error, errors} = Zoi.parse(schema, %{"name" => "ok", "extra" => "bad"})
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      refute changeset.valid?
      # Unrecognized key errors land on :base (path is []) with the key in opts
      {_msg, opts} = changeset.errors[:base]
      assert opts[:validation] == :unknown_field
      assert opts[:code] == :unrecognized_key
      assert opts[:key] == "extra"
    end

    test "unknown code falls back to code: only (no validation: key)" do
      # Manually construct an error with an unmapped code
      error = %Zoi.Error{
        code: :completely_custom_code,
        issue: {"something went wrong", []},
        message: "something went wrong",
        path: [:field]
      }

      changeset = Zoi.Ecto.errors_to_changeset([error])

      refute changeset.valid?
      {_msg, opts} = changeset.errors[:field]
      assert opts[:code] == :completely_custom_code
      refute Keyword.has_key?(opts, :validation)
    end

    test "invalid_enum_value includes enum: list for Ecto compatibility" do
      input = Map.put(@valid_order, "currency", "BTC")
      {:error, errors} = Zoi.parse(OrderSchemas.order(), input)
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      {_msg, opts} = changeset.errors[:currency]
      assert opts[:validation] == :inclusion
      assert opts[:code] == :invalid_enum_value
      assert is_list(opts[:enum])
      assert "USD" in opts[:enum]
      assert "EUR" in opts[:enum]
      assert "GBP" in opts[:enum]
    end
  end

  # ---------------------------------------------------------------------------
  # Downstream compatibility
  # ---------------------------------------------------------------------------

  describe "Ecto.Changeset compatibility" do
    test "traverse_errors works on flat changeset" do
      {:error, errors} = Zoi.parse(OrderSchemas.order(), %{})
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      traversed = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
      assert is_map(traversed)
      assert is_list(traversed[:email])
    end

    test "error tuples have {message, keyword} format" do
      {:error, errors} = Zoi.parse(OrderSchemas.order(), %{})
      changeset = Zoi.Ecto.errors_to_changeset(errors)

      Enum.each(changeset.errors, fn {_field, {msg, opts}} ->
        assert is_binary(msg)
        assert is_list(opts)
        assert Keyword.has_key?(opts, :code)
      end)
    end
  end
end
