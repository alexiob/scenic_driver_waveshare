defmodule Waveshare.MixProject do
  use Mix.Project

  @app :scenic_driver_waveshare
  @version "1.0.0"
  @all_targets [:rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :rpi4]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.9",
      description: description(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:scenic, "~> 0.10.2"},

      # Dependencies for all targets except :host
      {:circuits_gpio, "~> 0.4.1", targets: @all_targets},
      {:circuits_spi, "~> 0.1.3", targets: @all_targets},
      {:scenic_driver_gpio, "~> 0.2", targets: @all_targets},
      {:scenic_driver_nerves_rpi, "~> 0.10.1", targets: @all_targets},
      {:rpi_fb_capture, "~> 0.2.1", targets: @all_targets},

      # Dependencies for :host
      {:scenic_driver_glfw, "~> 0.10.1", targets: :host},

      # Dev dependencies
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    "Scenic render and input driver for Waveshare display HAT for Raspberry PI"
  end

  defp docs() do
    [
      main: Waveshare,
      extras: [
        "README.md": [
          title: "Readme"
        ]
      ]
    ]
  end

  defp package do
    %{
      name: "scenic_driver_waveshare",
      description: description(),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/alexiob/scenic_driver_waveshare"}
    }
  end
end
