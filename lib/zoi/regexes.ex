defmodule Zoi.Regexes do
  @moduledoc false

  @email ~r/^(?!\.)(?!.*\.\.)([a-z0-9_'+\-\.]*)[a-z0-9_+\-]@([a-z0-9][a-z0-9\-]*\.)+[a-z]{2,}$/i

  @doc """
  Regex pattern to match a valid email address.
  """
  def email() do
    @email
  end

  @html5_email ~r/^[\w.!#$%&'*+\/=?^`{|}~-]+@[a-z\d](?:[a-z\d-]{0,61}[a-z\d])?(?:\.[a-z\d](?:[a-z\d-]{0,61}[a-z\d])?)*$/i

  @doc """
  Regex pattern based on on https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/email
  """
  def html5_email() do
    @html5_email
  end

  @rfc5322_email ~r/^(?:"[^"]+"|[!#-'*+\/-9=?A-Z^_`a-z{|}~]+)@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$/

  @doc """
  Regex pattern based on RFC 5322 official standard
  """
  def rfc5322_email() do
    @rfc5322_email
  end

  @simple_email ~r/^[^@,;\s]+@[^@,;\s]+$/

  @doc """
  Regex pattern based on phoenix implementation: https://github.com/phoenixframework/phoenix/blob/main/priv/templates/phx.gen.auth/schema.ex#L38C34-L38C59
  """
  def simple_email() do
    @simple_email
  end

  @upcase ~r/^[^a-z]*$/

  @doc """
  Regex pattern to match only uppercase letters.
  """
  def upcase() do
    @upcase
  end

  @downcase ~r/^[^A-Z]*$/

  @doc """
  Regex pattern to match only lowercase letters.
  """
  def downcase() do
    @downcase
  end

  @uuid ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/

  @doc """
  Regex pattern to match a valid UUID.
  """
  def uuid(opts \\ []) do
    uuid_versions = ["v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8"]
    version = opts[:version]

    cond do
      version == nil ->
        @uuid

      version in uuid_versions ->
        ~r/^([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[#{version}][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$/

      true ->
        raise ArgumentError, "Invalid UUID version: #{version}"
    end
  end

  @ipv4 ~r/^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$/

  @doc """
  Regex pattern to match a valid IPv4 address.

  from https://stackoverflow.com/questions/5284147/validating-ipv4-addresses-with-regexp
  """
  def ipv4() do
    @ipv4
  end

  @ipv6 ~r/(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))/

  @doc """
  Regex pattern to match a valid IPv6 address.

  from https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses
  """
  def ipv6() do
    @ipv6
  end

  @hex ~r/^[0-9a-fA-F]*$/

  @doc """
  Regex pattern to match hexadecimal
  """
  def hex() do
    @hex
  end

  @doc """
  Reuses a built-in pattern when its source and options match.
  Compiles all other patterns with `Regex.compile!/2`.
  """
  def compile!(source, opts)

  for {name, regex} <- [
        email: @email,
        html5_email: @html5_email,
        rfc5322_email: @rfc5322_email,
        simple_email: @simple_email,
        upcase: @upcase,
        downcase: @downcase,
        uuid: @uuid,
        ipv4: @ipv4,
        ipv6: @ipv6,
        hex: @hex
      ] do
    def compile!(unquote(regex.source), unquote(Macro.escape(regex.opts))) do
      unquote(name)()
    end
  end

  def compile!(source, opts), do: Regex.compile!(source, opts)
end
