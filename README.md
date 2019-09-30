# Scenic render and input driver for Waveshare display HAT for Raspberry PI

A library to provide a Scenic framework driver implementation for the display HAT for Raspberry PI from Waveshare.

Currently supports:

- 128x128, 1.44inch LCD display HAT for Raspberry Pi
    - SKU: 13891
    - Part Number: 1.44inch LCD HAT
    - Brand: Waveshare

This driver only runs on RPi devices as far as we know as it is based on the scenic rpi driver generating a frame buffer we can use.

## Installation

The package can be installed
by adding `scenic_driver_waveshare` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:scenic_driver_waveshare, "~> 1.0.0"}
  ]
end
```

## Usage

This library provides the `Scenic.Driver.Nerves.Waveshare` driver module.

An usage example is provided in [alexiob/sample_scenic_waveshare](https://github.com/alexiob/sample_scenic_waveshare).

The driver configuration, to be placed in `config/target.exs`:

```elixir
config :waveshare, :viewport, %{
  name: :main_viewport,
  default_scene: {Waveshare.Scene.Main, nil},
  # Match these to your display
  size: {128, 128},
  opts: [scale: 1.0],
  drivers: [
    %{
      module: Scenic.Driver.Nerves.Waveshare,
      opts: [
        # only :sku138191 at the moment
        device_sku: :sku138191,
        # :color18bit (default) | :color16bit | :color12bit
        color_depth: :color18bit,
        # :rgb | :bgr (default)
        color_order: :bgr,
        # :l2r_u2d | :l2r_d2u | :r2l_u2d | :r2l_d2u | :u2d_l2r | :u2d_r2l (default) | :d2u_l2r | :d2u_r2l
        scan_dir: :u2d_r2l,
        # :ppm | :rgb24 (default) | :rgb565 | :mono | :mono_column_scan
        capture_format: :rgb24,
        refresh_interval: 50,
        spi_speed_hz: 20_000_000
      ],
      name: :waveshare
    }
  ]
}
```

I strongly suggest to use the default values provided above.

For development on host, we recommend just using the `glfw` driver for scenic.

The HAT inputs generate Scenic `:key` events:

```elixir
def handle_input(
      {:key, {key, action, _something}} = event,
      _context,
      _state
    ) do

  Logger.debug(
    handle_input: received event #{inspect(event)} state=#{inspect(state)}"
  )

  case {key, action} do
    {:joystick_1_up, :press} -> ...
    {:joystick_1_down, :press} -> ...
    {:joystick_1_right, :press} -> ...
    {:joystick_1_left, :press} -> ...
    {:joystick_1_button, :press} -> ...
    {:button_1, :press} -> ...
    {:button_2, :press} -> ...
    {:button_3, :press} -> ...
  end
end
```
