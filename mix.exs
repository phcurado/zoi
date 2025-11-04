defmodule Zoi.MixProject do
  use Mix.Project

  @source_url "https://github.com/phcurado/zoi"
  @version "0.9.0"

  def project do
    [
      app: :zoi,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      name: "Zoi",
      description:
        "Zoi is a schema validation library for Elixir, designed to provide a simple and flexible way to define and validate data.",
      package: package(),
      docs: docs(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/project.plt"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 2.0", optional: true},
      {:phoenix_html, "~> 2.14.2 or ~> 3.0 or ~> 4.1", optional: true},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp package do
    [
      maintainers: ["Paulo Curado"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/zoi/changelog.html"
      },
      licenses: ["Apache-2.0"],
      files: ~w(.formatter.exs lib mix.exs README.md CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      logo: "guides/images/logo.png",
      extra_section: "GUIDES",
      source_url: @source_url,
      groups_for_extras: groups_for_extras(),
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: extras()
    ]
  end

  defp extras do
    [
      "CHANGELOG.md",
      "README.md",
      "guides/quickstart_guide.md",
      "guides/using_zoi_to_generate_openapi_specs.md",
      "guides/validating_controller_parameters.md",
      "guides/converting_keys_from_object.md",
      "guides/generating_schemas_from_json_example.md"
    ]
  end

  defp groups_for_extras do
    [
      Guides: ~r/guides\/.*\.md/
    ]
  end
end
