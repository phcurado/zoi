defmodule Zoi.ISO.Test do
  use ExUnit.Case
  doctest Zoi.ISO

  describe "time/1" do
    test "time with correct value" do
      assert {:ok, "23:50:07"} == Zoi.parse(Zoi.ISO.time(), "23:50:07")
      assert {:ok, "23:50:07,0123456"} == Zoi.parse(Zoi.ISO.time(), "23:50:07,0123456")
      assert {:ok, "23:50:07.123Z"} == Zoi.parse(Zoi.ISO.time(), "23:50:07.123Z")
    end

    test "time with incorrect value" do
      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "23:50:07.123456789A01:00"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.ISO.time(), value)
        assert Exception.message(error) == "invalid type: must be an ISO time"
      end
    end
  end

  describe "date/1" do
    test "date with correct value" do
      assert {:ok, "2025-08-07"} == Zoi.parse(Zoi.ISO.date(), "2025-08-07")
      assert {:ok, "2015-01-23"} == Zoi.parse(Zoi.ISO.date(), "2015-01-23")
    end

    test "date with incorrect value" do
      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "2025-02-30"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.ISO.date(), value)
        assert Exception.message(error) == "invalid type: must be an ISO date"
      end
    end
  end

  describe "datetime/1" do
    test "datetime with correct value" do
      assert {:ok, "2025-08-07T10:04:22+03:00"} ==
               Zoi.parse(Zoi.ISO.datetime(), "2025-08-07T10:04:22+03:00")

      assert {:ok, "2025-08-07T10:04:22Z"} ==
               Zoi.parse(Zoi.ISO.datetime(), "2025-08-07T10:04:22Z")

      assert {:ok, "2025-08-07T10:04:22.123456789+03:00"} ==
               Zoi.parse(Zoi.ISO.datetime(), "2025-08-07T10:04:22.123456789+03:00")
    end

    test "datetime with incorrect value" do
      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "23:50:07,0123456"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.ISO.datetime(), value)
        assert Exception.message(error) == "invalid type: must be an ISO datetime"
      end
    end
  end

  describe "naive_datetime/1" do
    test "naive_datetime with correct value" do
      assert {:ok, "2025-08-07T10:04:22"} ==
               Zoi.parse(Zoi.ISO.naive_datetime(), "2025-08-07T10:04:22")

      assert {:ok, "2015-01-23T23:50:07"} ==
               Zoi.parse(Zoi.ISO.naive_datetime(), "2015-01-23T23:50:07")

      assert {:ok, "2025-08-07T10:04:22.123456789"} ==
               Zoi.parse(Zoi.ISO.naive_datetime(), "2025-08-07T10:04:22.123456789")
    end

    test "naive_datetime with incorrect value" do
      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "23:50:07,0123456"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(Zoi.ISO.naive_datetime(), value)
        assert Exception.message(error) == "invalid type: must be an ISO naive datetime"
      end
    end
  end

  describe "to_time_struct/2" do
    test "transforms to Time with correct values" do
      schema = Zoi.ISO.time() |> Zoi.ISO.to_time_struct()

      assert {:ok, ~T[23:50:07]} == Zoi.parse(schema, "23:50:07")
      assert {:ok, ~T[23:50:07.0123456]} == Zoi.parse(schema, "23:50:07,0123456")
      assert {:ok, ~T[23:50:07.123]} == Zoi.parse(schema, "23:50:07.123Z")
    end

    test "transforms to Time with incorrect values" do
      schema = Zoi.ISO.time() |> Zoi.ISO.to_time_struct()

      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "23:50:07.123456789A01:00"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, value)
        assert Exception.message(error) == "invalid type: must be an ISO time"
      end
    end
  end

  describe "to_date_struct/2" do
    test "transforms to Date with correct values" do
      schema = Zoi.ISO.date() |> Zoi.ISO.to_date_struct()

      assert {:ok, ~D[2025-08-07]} == Zoi.parse(schema, "2025-08-07")
      assert {:ok, ~D[2015-01-23]} == Zoi.parse(schema, "2015-01-23")
    end

    test "transforms to Date with incorrect values" do
      schema = Zoi.ISO.date() |> Zoi.ISO.to_date_struct()

      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "2025-02-30"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, value)
        assert Exception.message(error) == "invalid type: must be an ISO date"
      end
    end
  end

  describe "to_datetime_struct/2" do
    test "transforms to DateTime with correct values" do
      schema = Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct()

      assert {:ok, ~U[2025-08-07 07:04:22Z]} ==
               Zoi.parse(schema, "2025-08-07T10:04:22+03:00")

      assert {:ok, ~U[2015-01-23 23:50:07Z]} ==
               Zoi.parse(schema, "2015-01-23T23:50:07Z")
    end

    test "transforms to DateTime with incorrect values" do
      schema = Zoi.ISO.datetime() |> Zoi.ISO.to_datetime_struct()

      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "23:50:07,0123456"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, value)
        assert Exception.message(error) == "invalid type: must be an ISO datetime"
      end
    end
  end

  describe "to_naive_datetime_struct/2" do
    test "transforms to NaiveDateTime with correct values" do
      schema = Zoi.ISO.naive_datetime() |> Zoi.ISO.to_naive_datetime_struct()

      assert {:ok, ~N[2025-08-07 10:04:22]} == Zoi.parse(schema, "2025-08-07T10:04:22")
      assert {:ok, ~N[2015-01-23 23:50:07]} == Zoi.parse(schema, "2015-01-23T23:50:07")
    end

    test "transforms to NaiveDateTime with incorrect values" do
      schema = Zoi.ISO.naive_datetime() |> Zoi.ISO.to_naive_datetime_struct()

      wrong_values = ["2015:01:23 23-50-07", nil, 1_200_000, :atom, "23:50:07,0123456"]

      for value <- wrong_values do
        assert {:error, [%Zoi.Error{} = error]} = Zoi.parse(schema, value)
        assert Exception.message(error) == "invalid type: must be an ISO naive datetime"
      end
    end
  end
end
