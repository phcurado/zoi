defmodule Zoi.ErrorTest do
  use ExUnit.Case

  describe "Error" do
    test "exception/1" do
      assert %Zoi.Error{message: "An error occurred"} =
               Zoi.Error.exception(message: "An error occurred")
    end

    test "message/1" do
      error = %Zoi.Error{message: "invalid type"}
      assert Zoi.Error.message(error) == "invalid type"
      assert Exception.message(error) == "invalid type"
    end
  end
end
