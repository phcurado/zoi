defmodule Zoi.MixProject do
  use Mix.Project

  @source_url "https://github.com/phcurado/zoi"
  @version "0.3.3"

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
      test_coverage: [tool: ExCoveralls]
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
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
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
      main: "Zoi",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extra_section: "GUIDES",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: extras()
    ]
  end

  defp extras do
    [
      "README.md",
      "CHANGELOG.md",
      "guides/Validating controller parameters.md"
    ]
  end
end
