defmodule Engine.MixProject do
  use Mix.Project

  def project do
    [
      app: :engine,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:ecto, :postgrex],
      extra_applications: [:logger, :observer],
      mod: {Engine.Application, []}
    ]
  end

  # Specify which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/unit/support", "test/unit"]
  defp elixirc_paths(:integration), do: ["lib", "test/unit/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specify test paths per environment.
  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(:test), do: ["test/unit"]
  defp test_paths(_), do: []

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:logger_file_backend, "~> 0.0.11", runtime: false},
      {:mox, "~> 0.5.0", only: :test},
      {:ecto_sql, "~> 3.3.4"},
      {:postgrex, ">= 0.10.0"},
      {:poison, "~> 3.1"}
    ]
  end

  def run_integration_tests(args), do: test_with_env("integration", args)
  def run_unit_tests(args), do: test_with_env("test", args)

  # got this from https://spin.atomicobject.com/2018/10/22/elixir-test-multiple-environments/
  def test_with_env(env, args) do
    args = if IO.ANSI.enabled?(), do: ["--color" | args], else: ["--no-color" | args]
    IO.puts("==> Running tests with `MIX_ENV=#{env}`")

    {_, res} =
      System.cmd("mix", ["test" | args],
        into: IO.binstream(:stdio, :line),
        env: [{"MIX_ENV", to_string(env)}]
      )

    if res > 0 do
      System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp aliases do
    [
      "test.all": ["test.unit", "test.integration"],
      "test.unit": &run_unit_tests/1,
      "test.integration": &run_integration_tests/1
    ]
  end
end
