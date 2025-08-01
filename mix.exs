defmodule Zoi.MixProject do
  use Mix.Project

  @source_url "https://github.com/paulocurado/zoi"
  @version "0.1.0"

  def project do
    [
      app: :zoi,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      name: "Zoi",
      description:
        "Zoi is a schema validation library for Elixir, designed to provide a simple and flexible way to define and validate data.",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
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
        "Changelog" => "https://hexdocs.pm/ecto/changelog.html"
      },
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(.formatter.exs lib mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "Zoi",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"],
      groups_for_modules: [
        Types: [
          # Zoi.Type.Array,
          Zoi.Types.String,
          Zoi.Types.Integer,
          Zoi.Types.Boolean,
          Zoi.Types.Object,
          Zoi.Types.Optional,
          Zoi.Types.Default
          # Zoi.Type.DateTime,
          # Zoi.Type.Decimal,
          # Zoi.Type.Float,
          # Zoi.Type.Map,
        ]
      ]
    ]
  end
end
