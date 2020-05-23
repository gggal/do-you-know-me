defmodule Server.MixProject do
  use Mix.Project

  def project do
    [
      app: :server,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:ecto, :postgrex],
      extra_applications: [:logger, :observer],
      mod: {Server.Application, []}
    ]
  end

  # Specify which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/server"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:logger_file_backend, "~> 0.0.11", runtime: false},
      {:mox, "~> 0.5.0", only: :test},
      {:ecto_sql, "~> 3.3.4"},
      {:postgrex, ">= 0.10.0"}
    ]
  end

  defp aliases do
    [test: "test --no-start"]
  end
end
