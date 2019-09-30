defmodule Waveshare.Driver.Input.SKU138191 do
  require Logger

  @joystick_button 13
  @joystick_up 6
  @joystick_down 19
  @joystick_left 5
  @joystick_right 26
  @key_1 21
  @key_2 20
  @key_3 16

  @gpio_config [
    # Joystick press
    %{
      pin: @joystick_button,
      pull_mode: :pullup,
      low: {:key, {:joystick_1_button, :press, 0}},
      high: {:key, {:joystick_1_button, :release, 0}}
    },
    # Joystick up
    %{
      pin: @joystick_up,
      pull_mode: :pullup,
      low: {:key, {:joystick_1_up, :press, 0}},
      high: {:key, {:joystick_1_up, :release, 0}}
    },
    # Joystick right
    %{
      pin: @joystick_right,
      pull_mode: :pullup,
      low: {:key, {:joystick_1_right, :press, 0}},
      high: {:key, {:joystick_1_right, :release, 0}}
    },
    # Joystick down
    %{
      pin: @joystick_down,
      pull_mode: :pullup,
      low: {:key, {:joystick_1_down, :press, 0}},
      high: {:key, {:joystick_1_down, :release, 0}}
    },
    # Joystick left
    %{
      pin: @joystick_left,
      pull_mode: :pullup,
      low: {:key, {:joystick_1_left, :press, 0}},
      high: {:key, {:joystick_1_left, :release, 0}}
    },
    # Key 1
    %{
      pin: @key_1,
      pull_mode: :pullup,
      low: {:key, {:button_1, :press, 0}},
      high: {:key, {:button_1, :release, 0}}
    },
    # Key 2
    %{
      pin: @key_2,
      pull_mode: :pullup,
      low: {:key, {:button_2, :press, 0}},
      high: {:key, {:button_2, :release, 0}}
    },
    # Key 3
    %{
      pin: @key_3,
      pull_mode: :pullup,
      low: {:key, {:button_3, :press, 0}},
      high: {:key, {:button_3, :release, 0}}
    }
  ]

  def init(state, _viewport, size, _config, vp_supervisor, sku_config) do
    Logger.info("Waveshare.Driver.Input.SKU138191: initializing '#{sku_config[:name]}' input...")

    {:ok, gpio} =
      Scenic.ViewPort.Driver.start_link({
        vp_supervisor,
        size,
        %{module: ScenicDriverGPIO, opts: @gpio_config}
      })

    Map.put_new(state, :input, %{
      gpio: gpio
    })
  end
end
