defmodule Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :cli,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: CLI],
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:gen_state_machine],
      extra_applications: [:logger, :observer],
      mod: {CLI.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poison, "~> 3.1"},
      {:logger_file_backend, "~> 0.0.11", runtime: false},
      {:gen_state_machine, "~> 2.0"},
      {:engine, path: "../engine", runtime: false}
    ]
  end

  # Specify which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
