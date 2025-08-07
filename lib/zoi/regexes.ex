defmodule Zoi.Regexes do
  @moduledoc false

  @doc """
  Regex pattern to match a valid email address.
  """
  @email ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i
  def email, do: @email

  @doc """
  Regex pattern to match a valid UUID.
  """
  @uuid ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v1 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v2 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[2][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v3 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[3][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v4 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[4][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v5 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v6 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[6][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v7 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[7][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/
  @uuid_v8 ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/

  def uuid(opts \\ []) do
    case opts[:version] do
      "v1" -> @uuid_v1
      "v2" -> @uuid_v2
      "v3" -> @uuid_v3
      "v4" -> @uuid_v4
      "v5" -> @uuid_v5
      "v6" -> @uuid_v6
      "v7" -> @uuid_v7
      "v8" -> @uuid_v8
      nil -> @uuid
      _ -> raise ArgumentError, "Invalid UUID version: #{opts[:version]}"
    end
  end

  @doc """
  Regex pattern to match a valid URL.
  """
  @url ~r/^(https?|mailto):\/\/(([\w-]+\.)+[\w-]+|localhost|127(?:\.\d{1,3}){3})(:\d+)?(\/[\w\-._~:\/?#[\]@!$&'()*+,;=]*)?$/i
  def url, do: @url
end
