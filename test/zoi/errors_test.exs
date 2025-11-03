defmodule Zoi.ErrorsTest do
  use ExUnit.Case, async: true
  doctest Zoi.Errors

  describe "Errors" do
    test "add_error/2" do
      assert [%Zoi.Error{message: "issue"}] = Zoi.Errors.add_error("issue")

      assert [%Zoi.Error{message: "invalid type"}] =
               errors = Zoi.Errors.add_error(%Zoi.Error{message: "invalid type"})

      assert [%Zoi.Error{}, %Zoi.Error{message: "another issue"}] =
               Zoi.Errors.add_error(errors, "another issue")

      assert [%Zoi.Error{}, %Zoi.Error{}] = Zoi.Errors.add_error(errors, %Zoi.Error{})

      assert [%Zoi.Error{message: "invalid type"}, %Zoi.Error{message: "issue 2"}] =
               Zoi.Errors.add_error(errors, [%Zoi.Error{message: "issue 2"}])
    end
  end
end
