defmodule Etiquette.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/matiascr/etiquette"

  def project do
    [
      app: :etiquette,
      name: "Etiquette",
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      description: "A library to streamline creating and following protocols"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:styler, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib LICENSE.md mix.exs README.md .formatter.exs)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "overview",
      assets: %{"notebooks/files" => "files"},
      extra_section: "GUIDES",
      formatters: ["html", "epub"],
      groups_for_modules: groups_for_modules(),
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_docs: [
        Reflection: &(&1[:type] == :reflection)
      ]
    ]
  end

  defp extras do
    [
      "guides/introduction/getting_started.md",
      "guides/introduction/overview.md",
      "guides/how_tos/length_of.md",
      "guides/how_tos/validating_packet_formats.md",
      "guides/how_tos/packet_types_and_subtypes.md",
      "notebooks/error_handling.livemd"
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      "How-To's": ~r/guides\/how_tos\/.?/,
      "Example notebooks": ~r/notebooks\/.?/
    ]
  end

  defp groups_for_modules do
    [
      Library: [
        Etiquette,
        Etiquette.Spec
      ]
    ]
  end
end
