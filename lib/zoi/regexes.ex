defmodule Zoi.Regexes do
  @moduledoc false

  @doc """
  Regex pattern to match a valid email address.
  """
  @email ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i
  def email, do: @email

  @doc """
  Regex pattern to match a valid URL.
  """
  @url ~r/^(https?|mailto):\/\/(([\w-]+\.)+[\w-]+|localhost|127(?:\.\d{1,3}){3})(:\d+)?(\/[\w\-._~:\/?#[\]@!$&'()*+,;=]*)?$/i
  def url, do: @url
end
