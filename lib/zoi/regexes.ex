defmodule Zoi.Regexes do
  @moduledoc false

  @doc """
  Regex pattern to match a valid email address.
  """
  def email() do
    ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i
  end

  @doc """
  Regex pattern to match only uppercase letters.
  """
  def upcase() do
    ~r/^[^a-z]*$/
  end

  @doc """
  Regex pattern to match only lowercase letters.
  """
  def downcase() do
    ~r/^[^A-Z]*$/
  end

  @doc """
  Regex pattern to match a valid UUID.
  """
  def uuid(opts \\ []) do
    uuid_versions = ["v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8"]
    version = opts[:version]

    cond do
      version == nil ->
        ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/

      version in uuid_versions ->
        ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[#{version}][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/

      true ->
        raise ArgumentError, "Invalid UUID version: #{version}"
    end
  end

  @doc """
  Regex pattern to match a valid URL.
  """
  def url() do
    ~r/^(https?|mailto):\/\/(([\w-]+\.)+[\w-]+|localhost|127(?:\.\d{1,3}){3})(:\d+)?(\/[\w\-._~:\/?#[\]@!$&'()*+,;=]*)?$/i
  end

  @doc """
  Regex pattern to match a valid IPv4 address.

  from https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
  """
  def ipv4() do
    ~r/^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$/
  end

  @doc """
  Regex pattern to match a valid IPv6 address.

  from https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses
  """
  def ipv6() do
    ~r/(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))/
  end

  @doc """
  Regex pattern to match hexadecimal
  """
  def hex() do
    ~r/^[0-9a-fA-F]*$/
  end
end
