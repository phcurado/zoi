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

  @uuid_versions ["v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8"]

  Module.put_attribute(__MODULE__, :uuids, %{})

  Enum.map(@uuid_versions, fn version ->
    uuid_pattern =
      Regex.compile!(
        "^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[#{version}][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$"
      )

    Module.put_attribute(__MODULE__, :uuids, Map.put(@uuids, version, uuid_pattern))
  end)

  def uuid(opts \\ []) do
    version = opts[:version]

    cond do
      version == nil ->
        ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/

      regex = Map.get(@uuids, version) ->
        regex

      true ->
        raise ArgumentError, "Invalid UUID version: #{version}"
    end
  end

  @doc """
  Regex pattern to match a valid URL.
  """
  @url ~r/^(https?|mailto):\/\/(([\w-]+\.)+[\w-]+|localhost|127(?:\.\d{1,3}){3})(:\d+)?(\/[\w\-._~:\/?#[\]@!$&'()*+,;=]*)?$/i
  def url, do: @url

  @doc """
  Regex pattern to match a valid IPv4 address.

  from https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
  """
  @ipv4 ~r/^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$/
  def ipv4, do: @ipv4

  @doc """
  Regex pattern to match a valid IPv6 address.

  from https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses
  """
  @ipv6 ~r/(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))/
  def ipv6, do: @ipv6
end
