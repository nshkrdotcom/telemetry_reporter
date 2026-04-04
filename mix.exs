defmodule TelemetryReporter.MixProject do
  use Mix.Project

  def project do
    [
      app: :telemetry_reporter,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description:
        "TelemetryReporter is a transport-agnostic telemetry batching library for Elixir/BEAM apps. " <>
          "It uses Pachka for efficient size/time batch flushing, drops on overload to protect producers, " <>
          "and isolates encoding failures so a single bad event never poisons a batch.",
      source_url: "https://github.com/nshkrdotcom/telemetry_reporter",
      homepage_url: "https://github.com/nshkrdotcom/telemetry_reporter",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TelemetryReporter.Application, []}
    ]
  end

  defp package do
    [
      files: ["lib", "assets", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE*"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/nshkrdotcom/telemetry_reporter"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "docs/usage.md"
      ],
      groups_for_extras: [
        "Getting Started": ["README.md", "docs/usage.md"],
        About: ["CHANGELOG.md", "LICENSE"]
      ],
      groups_for_modules: [
        Core: [TelemetryReporter],
        Behaviours: [TelemetryReporter.Transport],
        Adapters: [TelemetryReporter.TelemetryAdapter],
        "Data Types": [TelemetryReporter.Event]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:pachka, "~> 1.0.0"},
      {:telemetry, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
