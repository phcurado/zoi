defmodule Zoi.ISO do
  @moduledoc """
  This module defines schemas for ISO time, date, and datetime formats,
  along with transformations to convert them into Elixir's native types.

  It includes built-in transformations to convert ISO time, date, and datetime
  strings into `%Time{}`, `%Date{}`, and `%DateTime{}` structs.
  """

  @doc """
  Defines a time type schema.

  ## Example

      iex> schema = Zoi.ISO.time()
      iex> Zoi.parse(schema, "12:34:56")
      {:ok, "12:34:56"}
      iex> Zoi.parse(schema, "25:00:00")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected ISO time",
           issue: {"invalid type: expected %{expected}", [expected: "ISO time"]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  defdelegate time(opts \\ []), to: Zoi.ISO.Time, as: :new

  @doc """
  Defines a date type schema.

  ## Example

      iex> schema = Zoi.ISO.date()
      iex> Zoi.parse(schema, "2025-08-07")
      {:ok, "2025-08-07"}
      iex> Zoi.parse(schema, "2025-02-30")
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected ISO date",
           issue: {"invalid type: expected %{expected}", [expected: "ISO date"]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  defdelegate date(opts \\ []), to: Zoi.ISO.Date, as: :new

  @doc """
  Defines a datetime type schema.

  ## Example

      iex> schema = Zoi.ISO.datetime()
      iex> Zoi.parse(schema, "2025-08-07T10:04:22+03:00")
      {:ok, "2025-08-07T10:04:22+03:00"}

      iex> schema = Zoi.ISO.datetime()
      iex> Zoi.parse(schema, 1754646043)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected ISO datetime",
           issue: {"invalid type: expected %{expected}", [expected: "ISO datetime"]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  defdelegate datetime(opts \\ []), to: Zoi.ISO.DateTime, as: :new

  @doc """
  Defines a naive datetime type schema.

  ## Example

      iex> schema = Zoi.ISO.naive_datetime()
      iex> Zoi.parse(schema, "2025-08-07T10:04:22")
      {:ok, "2025-08-07T10:04:22"}

      iex> schema = Zoi.ISO.naive_datetime()
      iex> Zoi.parse(schema, 1754646043)
      {:error,
       [
         %Zoi.Error{
           code: :invalid_type,
           message: "invalid type: expected ISO naive datetime",
           issue: {"invalid type: expected %{expected}", [expected: "ISO naive datetime"]},
           path: []
         }
       ]}
  """
  @doc group: "Basic Types"
  defdelegate naive_datetime(opts \\ []), to: Zoi.ISO.NaiveDateTime, as: :new

  # Transforms

  @doc """
  Converts `Zoi.ISO.time()` to `%Time{}` struct.

  ## Example
      iex> schema = Zoi.ISO.time() |> Zoi.ISO.to_time_struct()
      iex> Zoi.parse(schema, "12:34:56")
      {:ok, ~T[12:34:56]}
  """
  @doc group: "Transforms"
  def to_time_struct(schema) do
    schema
    |> Zoi.transform({__MODULE__, :__transform__, [[:to_time]]})
  end

  @doc """
  Converts `Zoi.ISO.date()` to `%Date{}` struct.

  ## Example
      iex> schema = Zoi.ISO.date() |> Zoi.ISO.to_date_struct()
      iex> Zoi.parse(schema, "2025-08-07")
      {:ok, ~D[2025-08-07]}
  """
  @doc group: "Transforms"
  def to_date_struct(schema) do
    schema
    |> Zoi.transform({__MODULE__, :__transform__, [[:to_date]]})
  end

  @doc """
  Converts `Zoi.ISO.datetime()` to `%DateTime{}` struct.

  ## Example
      iex> schema = Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct()
      iex> Zoi.parse(schema, "2025-08-07T10:04:22+03:00")
      {:ok, ~U[2025-08-07 07:04:22Z]}
  """
  @doc group: "Transforms"
  def to_datetime_struct(schema) do
    schema
    |> Zoi.transform({__MODULE__, :__transform__, [[:to_datetime]]})
  end

  @doc """
  Converts `Zoi.ISO.naive_datetime()` to `%NaiveDateTime{}` struct.

  ## Example
      iex> schema = Zoi.ISO.naive_datetime() |> Zoi.ISO.to_naive_datetime_struct()
      iex> Zoi.parse(schema, "2025-08-07T10:04:22")
      {:ok, ~N[2025-08-07 10:04:22]}
  """
  @doc group: "Transforms"
  def to_naive_datetime_struct(schema) do
    schema
    |> Zoi.transform({__MODULE__, :__transform__, [[:to_naive_datetime]]})
  end

  # Transforms MFAs

  @doc false
  def __transform__(input, args, ctx: ctx) do
    do_transform(ctx.schema, input, args)
  end

  def do_transform(%Zoi.ISO.Time{}, input, [:to_time]) do
    # since `Zoi.ISO.Time` already validates the input as an ISO time,
    # we can safely parse it to a Time struct
    {:ok, parsed} = Time.from_iso8601(input)
    {:ok, parsed}
  end

  def do_transform(%Zoi.ISO.Date{}, input, [:to_date]) do
    # since `Zoi.ISO.Date` already validates the input as an ISO date,
    # we can safely parse it to a Date struct
    {:ok, parsed} = Date.from_iso8601(input)
    {:ok, parsed}
  end

  def do_transform(%Zoi.ISO.DateTime{}, input, [:to_datetime]) do
    # since `Zoi.ISO.DateTime` already validates the input as an ISO datetime,
    # we can safely parse it to a DateTime struct
    {:ok, parsed, _offset} = DateTime.from_iso8601(input)
    {:ok, parsed}
  end

  def do_transform(%Zoi.ISO.NaiveDateTime{}, input, [:to_naive_datetime]) do
    # since `Zoi.ISO.NaiveDateTime` already validates the input as an ISO naive datetime,
    # we can safely parse it to a NaiveDateTime struct
    {:ok, parsed} = NaiveDateTime.from_iso8601(input)
    {:ok, parsed}
  end

  # coveralls-ignore-start
  def do_transform(_schema, input, _args) do
    # Default to the input if there is no type pattern match
    {:ok, input}
  end

  # coveralls-ignore-stop
end
