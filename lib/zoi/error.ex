defmodule Zoi.Error do
  @type path :: [atom() | binary() | integer()]
  @type t :: %__MODULE__{
          message: binary(),
          path: path()
        }
  defexception [:message, path: []]

  @impl true
  def exception(opts) do
    struct!(__MODULE__, opts)
  end

  def append_path(%__MODULE__{} = error, path) when is_list(path) do
    %{error | path: error.path ++ path}
  end

  def add_path(%__MODULE__{} = error, path) when is_list(path) do
    %{error | path: path ++ error.path}
  end

  def message(%__MODULE__{message: message}) do
    message
  end
end

defmodule Zoi.ParseError do
  @moduledoc false
  defexception [:errors]

  @impl true
  def exception(opts) do
    struct!(__MODULE__, opts)
  end

  @impl true
  def message(%__MODULE__{errors: errors}) when is_list(errors) do
    """
    Parsing error:

    #{Zoi.prettify_errors(errors)}
    """
  end
end
