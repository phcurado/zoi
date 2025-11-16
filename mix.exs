defmodule Zoi.MixProject do
  use Mix.Project

  @source_url "https://github.com/phcurado/zoi"
  @version "0.10.7"

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
      groups_for_modules: groups_for_modules(),
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: extras(),
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/mermaid@11.6.0/dist/mermaid.min.js"></script>
    <script>
      let initialized = false;

      window.addEventListener("exdoc:loaded", () => {
        if (!initialized) {
          mermaid.initialize({
            startOnLoad: false,
            theme: document.body.className.includes("dark") ? "dark" : "default"
          });
          initialized = true;
        }

        let id = 0;
        for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
          const graphDefinition = codeEl.textContent;
          const graphId = "mermaid-graph-" + id++;
          mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
            codeEl.innerHTML = svg;
            bindFunctions?.(codeEl);
          });
        }
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""

  defp extras do
    [
      "CHANGELOG.md",
      "README.md"
    ] ++ Enum.flat_map(groups_for_extras(), fn {_group, guides} -> guides end)
  end

  defp groups_for_extras do
    [
      Setup: [
        "guides/quickstart_guide.md",
        "guides/recipes.md"
      ],
      Integrations: [
        "guides/rendering_forms_with_phoenix.md",
        "guides/using_zoi_to_generate_openapi_specs.md",
        "guides/validating_controller_parameters.md"
      ],
      Utilities: [
        "guides/converting_keys_from_object.md",
        "guides/generating_schemas_from_json_example.md",
        "guides/localizing_errors_with_gettext.md"
      ]
    ]
  end

  defp groups_for_modules do
    [
      "Main API": [Zoi, Zoi.ISO],
      Schema: [Zoi.Schema, Zoi.Struct, Zoi.Describe],
      Integrations: [Zoi.JSONSchema, Zoi.Form],
      Internals: [Zoi.Context, Zoi.Type]
    ]
  end
end
