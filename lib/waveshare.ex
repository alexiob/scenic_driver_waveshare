defmodule Scenic.Driver.Nerves.Waveshare do
  use Scenic.ViewPort.Driver

  require Logger

  @sku_config %{
    sku138191: %{
      name: "Waveshare 128x128, 1.44inch LCD display HAT",
      input: Waveshare.Driver.Input.SKU138191,
      display: Waveshare.Driver.Display.ST7735S,
      lcd_x: 1,
      lcd_y: 2
    }
  }

  @impl true
  def init(viewport, size, config) do
    vp_supervisor = vp_supervisor(viewport)

    Logger.info("Scenic.Driver.Nerves.Waveshare: initializing SKU '#{config[:device_sku]}'...")
    Logger.info("Scenic.Driver.Nerves.Waveshare: config=#{inspect(config)}")

    state =
      %{
        viewport: viewport
      }
      |> init_display(viewport, size, config, vp_supervisor)
      |> init_input(viewport, size, config, vp_supervisor)

    send(self(), :refresh)

    {:ok, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    state = state.display.refresh.(state)

    Process.send_after(self(), :refresh, state.display.refresh_interval)

    {:noreply, state}
  end

  defp init_display(state, viewport, size, config, vp_supervisor) do
    init_driver(state, :display, viewport, size, config, vp_supervisor)
  end

  defp init_input(state, viewport, size, config, vp_supervisor) do
    init_driver(state, :input, viewport, size, config, vp_supervisor)
  end

  defp init_driver(state, driver_type, viewport, size, config, vp_supervisor) do
    sku = config[:device_sku]

    sku_config = @sku_config[sku]

    driver = Map.get(sku_config, driver_type, nil)

    case driver do
      nil -> state
      _ -> driver.init(state, viewport, size, config, vp_supervisor, sku_config)
    end
  end

  defp vp_supervisor(viewport) do
    [supervisor_pid | _] =
      viewport
      |> Process.info()
      |> get_in([:dictionary, :"$ancestors"])

    supervisor_pid
  end
end
