defmodule Zoi.BuiltinRegexPerformanceTest do
  use ExUnit.Case, async: true

  @schema Zoi.email()

  test "built-in sources and flags match fresh compilation" do
    for name <- [
          :email,
          :html5_email,
          :rfc5322_email,
          :simple_email,
          :upcase,
          :downcase,
          :uuid,
          :ipv4,
          :ipv6,
          :hex
        ],
        input <- [
          "",
          "ABC",
          "abc",
          "ADA@example.com",
          "bad@",
          "123e4567-e89b-12d3-a456-426614174000",
          "127.0.0.1",
          "::1",
          "λ"
        ] do
      regex = apply(Zoi.Regexes, name, [])
      schema = Zoi.string() |> Zoi.regex(regex)
      expected = Regex.match?(Regex.compile!(regex.source, regex.opts), input)
      assert match?({:ok, _}, Zoi.parse(schema, input)) == expected

      unless expected do
        assert {:error, [error]} = Zoi.parse(schema, input)
        assert error.code == :invalid_format
        {_message, opts} = error.issue
        assert Regex.source(opts[:pattern]) == Regex.source(regex)
        assert Regex.opts(opts[:pattern]) == Regex.opts(regex)
      end
    end
  end

  test "different flags and arbitrary patterns retain the compile fallback" do
    email = Zoi.Regexes.email()
    schema = Zoi.string() |> Zoi.regex(Regex.compile!(email.source, ""))
    assert {:error, _} = Zoi.parse(schema, "ADA@example.com")

    schema = Zoi.string() |> Zoi.regex(~r/^\p{L}+-\d+$/iu, error: "custom")
    assert Zoi.parse(schema, "λ-42") == {:ok, "λ-42"}
    assert {:error, [%Zoi.Error{message: "custom"}]} = Zoi.parse(schema, "42")
  end

  test "schemas keep the source representation and support module attributes and serialization" do
    assert [{:refine, {Zoi.Validations.Regex, :validate, [source, _flags, _opts]}}] =
             @schema.meta.effects

    assert is_binary(source)
    encoded = :erlang.term_to_binary(@schema)
    decoded = :erlang.binary_to_term(encoded)
    assert decoded == @schema
    assert Zoi.parse(decoded, "ada@example.com") == {:ok, "ada@example.com"}
    assert Zoi.to_json_schema(decoded) == Zoi.to_json_schema(@schema)
  end
end
