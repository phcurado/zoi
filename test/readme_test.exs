defmodule ReadmeTest do
  use ExUnit.Case
  doctest_file("README.md")
  doctest_file("guides/converting_keys_from_object.md")
  doctest_file("guides/generating_schemas_from_json_example.md")
  doctest_file("guides/quickstart_guide.md")
  doctest_file("guides/using_zoi_to_generate_openapi_specs.md")
  doctest_file("guides/validating_controller_parameters.md")
end
