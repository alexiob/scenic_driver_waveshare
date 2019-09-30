defmodule Waveshare.Driver.Display.ST7735S do
  require Logger
  require Bitwise
  import Bitwise

  # MADCTL(0x36): Memory Data Access Control
  @madctl 0x36
  @madctl_my 0x80
  @madctl_mx 0x40
  @madctl_mv 0x20
  @madctl_ml 0x10
  @madctl_mh 0x04
  @madctl_rgb_order 0xF7
  @madctl_bgr_order 0x08
  @color_order [
    rgb: @madctl_rgb_order,
    bgr: @madctl_bgr_order
  ]

  @madctl_default_color_order @madctl_bgr_order

  @colmod 0x3A
  @colmod_12bit 0x03
  @colmod_16bit 0x05
  @colmod_18bit 0x06

  @color_depth [
    color12bit: @colmod_12bit,
    color16bit: @colmod_16bit,
    color18bit: @colmod_18bit
  ]

  # @gamset 0x26
  @invctr 0xB4
  @invoff 0x20
  @invon 0x21

  @default_scan_dir :u2d_r2l
  @valid_scan_directions [
    :l2r_u2d,
    :l2r_d2u,
    :r2l_u2d,
    :r2l_d2u,
    :u2d_l2r,
    :u2d_r2l,
    :d2u_l2r,
    :d2u_r2l
  ]
  @default_capture_format :rgb24

  @default_refresh_interval 50
  @lcd_start_x 0
  @lcd_start_y 0

  @clear_color 0x0000
  # if bigger it messes with the display
  @chunk_size 2048

  @lcd_cs 8
  @lcd_rst 27
  @lcd_dc 25
  @lcd_bl 24

  @spi_bus_name "spidev0.0"
  @spi_mode 0
  @spi_bits_per_word 8
  @default_spi_speed_hz 20_000_000
  @spi_delay_us 0

  @spec init(map, any, any, any, any, any) :: any
  def init(state, _viewport, size, config, vp_supervisor, sku_config) do
    Logger.info(
      "Waveshare.Driver.Display.ST7735S: initializing '#{sku_config[:name]}' display with size #{
        inspect(size)
      }..."
    )

    {lcd_width, lcd_height} = size

    {:ok, lcd_cs} = Circuits.GPIO.open(@lcd_cs, :output)
    {:ok, lcd_rst} = Circuits.GPIO.open(@lcd_rst, :output)
    {:ok, lcd_dc} = Circuits.GPIO.open(@lcd_dc, :output)
    {:ok, lcd_bl} = Circuits.GPIO.open(@lcd_bl, :output)

    {:ok, _} =
      Scenic.ViewPort.Driver.start_link({
        vp_supervisor,
        size,
        %{module: Scenic.Driver.Nerves.Rpi}
      })

    {:ok, spi} =
      Circuits.SPI.open(
        @spi_bus_name,
        mode: @spi_mode,
        bits_per_word: @spi_bits_per_word,
        speed_hz: Keyword.get(config, :spi_speed_hz, @default_spi_speed_hz),
        delay_us: @spi_delay_us
      )

    {:ok, cap} =
      RpiFbCapture.start_link(
        width: lcd_width,
        height: lcd_height,
        display: 0
      )

    display_state = %{
      refresh: &Waveshare.Driver.Display.ST7735S.refresh/1,
      refresh_interval: Keyword.get(config, :refresh_interval, @default_refresh_interval),
      capture_format: Keyword.get(config, :capture_format, @default_capture_format),
      color_order:
        Keyword.get(
          @color_order,
          Keyword.get(config, :color_order, nil),
          @madctl_default_color_order
        ),
      lcd_width: lcd_width,
      lcd_height: lcd_height,
      lcd_cs: lcd_cs,
      lcd_rst: lcd_rst,
      lcd_dc: lcd_dc,
      lcd_bl: lcd_bl,
      spi: spi,
      cap: cap,
      scan_dir: Keyword.get(config, :scan_dir, @default_scan_dir),
      lcd_x: sku_config[:lcd_x],
      lcd_y: sku_config[:lcd_y],
      info: nil,
      last_crc: -1
    }

    state = Map.put_new(state, :display, display_state)

    state = init_lcd(state, config)

    clear(state)

    state
  end

  def refresh(state) do
    {:ok, frame} =
      RpiFbCapture.capture(
        state.display.cap,
        state.display.capture_format
      )

    crc = :erlang.crc32(frame.data)

    state =
      case crc != state.display.last_crc do
        true ->
          set_windows(
            state,
            @lcd_start_x,
            @lcd_start_y,
            state.display.lcd_width,
            state.display.lcd_height
          )

          frame_data = frame.data

          write_data(state, frame_data)
          put_in(state, [:display, :last_crc], crc)

        false ->
          state
      end

    state
  end

  defp clear(state) do
    clear(state, @clear_color)
  end

  defp clear(state, clear_color) do
    lcd_size = state.display.lcd_width * state.display.lcd_height
    data = String.duplicate(<<clear_color::size(16)>>, lcd_size)

    set_windows(
      state,
      @lcd_start_x,
      @lcd_start_y,
      state.display.lcd_width,
      state.display.lcd_height
    )

    write_data(state, data)

    state
  end

  defp init_lcd(state, config) do
    hardware_reset(state, config)

    {dis_column, dis_page, x_adjust, y_adjust} = set_gram_scan_way(state, state.display.scan_dir)

    :timer.sleep(200)

    # sleep out
    select_register(state, 0x11)

    :timer.sleep(120)

    # turn on LCD display
    select_register(state, 0x29)

    %{
      state
      | display:
          Map.merge(state.display, %{
            dis_column: dis_column,
            dis_page: dis_page,
            x_adjust: x_adjust,
            y_adjust: y_adjust
          })
    }
  end

  defp hardware_reset(state, config) do
    # turn on backlight
    set_lcd_bl(state, 1)

    # reset sequence
    set_lcd_rst(state, 1)
    :timer.sleep(100)
    set_lcd_rst(state, 0)
    :timer.sleep(100)
    set_lcd_rst(state, 1)
    :timer.sleep(100)

    # frame rate control: normal mode
    write_register(state, 0xB1, <<0x01, 0x2C, 0x2D>>)
    # frame rate control: idle mode
    write_register(state, 0xB2, <<0x01, 0x2C, 0x2D>>)
    # frame rate control: partial mode dot inversion mode
    write_register(state, 0xB3, <<0x01, 0x2C, 0x2D, 0x01, 0x2C, 0x2D>>)

    # display inversion: none
    write_register(state, @invctr, <<0b111>>)
    # power control 1: -4.6V auto mode
    write_register(state, 0xC0, <<0xA2, 0x02, 0x84>>)
    # power control 2: VGH
    write_register(state, 0xC1, <<0xC5>>)
    # power control 3: OpAmp current small, boost freq
    write_register(state, 0xC2, <<0x0A, 0x00>>)
    # power control 4: BCLK/2, Opamp current small & Medium low
    write_register(state, 0xC3, <<0x8A, 0x2A>>)
    # power control 5: partial mode/full-color
    write_register(state, 0xC4, <<0x8A, 0xEE>>)

    # VCOM Control 1
    write_register(state, 0xC5, <<0x0E>>)

    # write_register(state, @gamset, <<0x02>>)

    # display inversion off
    select_register(state, @invoff)

    # color mode
    color_depth = Keyword.get(config, :color_depth, :color18bit)

    case Keyword.get(@color_depth, color_depth, nil) do
      nil -> raise "unknown color depth #{inspect(color_depth)}"
      colmod -> write_register(state, @colmod, <<colmod>>)
    end

    # partial off (normal)
    select_register(state, 0x13)

    # enable test command
    write_register(state, 0xF0, <<0x01>>)
    # disable ram power save mode
    write_register(state, 0xF6, <<0x00>>)

    # gamma adjustment (+ polarity)
    write_register(
      state,
      0xE0,
      <<0x0F, 0x1A, 0x0F, 0x18, 0x2F, 0x28, 0x20, 0x22, 0x1F, 0x1B, 0x23, 0x37, 0x00, 0x07, 0x02,
        0x10>>
    )

    # gamma adjustment (- polarity)
    write_register(
      state,
      0xE1,
      <<0x0F, 0x1B, 0x0F, 0x17, 0x33, 0x2C, 0x29, 0x2E, 0x30, 0x30, 0x39, 0x3F, 0x00, 0x07, 0x03,
        0x10>>
    )
  end

  defp set_gram_scan_way(state, scan_dir) when scan_dir in @valid_scan_directions do
    {memory_access_reg, dis_column, dis_page} =
      case scan_dir do
        :l2r_u2d ->
          {0, state.display.lcd_height, state.display.lcd_width}

        :l2r_d2u ->
          {@madctl_my, state.display.lcd_height, state.display.lcd_width}

        :r2l_u2d ->
          {@madctl_mx, state.display.lcd_height, state.display.lcd_width}

        :r2l_d2u ->
          {@madctl_mx ||| @madctl_my, state.display.lcd_height, state.display.lcd_width}

        # switch widht/height
        :u2d_l2r ->
          {@madctl_mv, state.display.lcd_width, state.display.lcd_height}

        :u2d_r2l ->
          {@madctl_mv ||| @madctl_mx, state.display.lcd_width, state.display.lcd_height}

        :d2u_l2r ->
          {@madctl_mv ||| @madctl_my, state.display.lcd_width, state.display.lcd_height}

        :d2u_r2l ->
          {@madctl_mv ||| @madctl_mx ||| @madctl_my, state.display.lcd_width,
           state.display.lcd_height}
      end

    case state.display.color_order do
      @madctl_rgb_order ->
        Logger.debug(
          "set_gram_scan_way: #{memory_access_reg} &&& #{state.display.color_order} = #{
            memory_access_reg &&& state.display.color_order
          }"
        )

        write_register(state, @madctl, <<memory_access_reg &&& state.display.color_order>>)

      @madctl_bgr_order ->
        Logger.debug(
          "set_gram_scan_way: #{memory_access_reg} ||| #{state.display.color_order} = #{
            memory_access_reg ||| state.display.color_order
          }"
        )

        write_register(state, @madctl, <<memory_access_reg ||| state.display.color_order>>)
    end

    {x_adjust, y_adjust} =
      case memory_access_reg &&& @madctl_mv do
        1 -> {state.display.lcd_y, state.display.lcd_x}
        _ -> {state.display.lcd_x, state.display.lcd_y}
      end

    {dis_column, dis_page, x_adjust, y_adjust}
  end

  defp write_register(state, register, data) do
    select_register(state, register)
    write_data(state, data)
  end

  defp select_register(state, register) do
    set_lcd_dc(state, 0)
    spi_transfer(state, <<register>>)
  end

  defp set_windows(state, x_start, y_start, x_end, y_end) do
    x = <<
      # Set the horizontal starting point to the high octet
      0x00,
      # Set the horizontal starting point to the low octet
      (x_start &&& 0xFF) + state.display.x_adjust,
      # Set the horizontal end to the high octet
      0x00,
      # Set the horizontal end to the low octet
      (x_end - 1 &&& 0xFF) + state.display.x_adjust
    >>

    y = <<
      0x00,
      (y_start &&& 0xFF) + state.display.y_adjust,
      0x00,
      (y_end - 1 &&& 0xFF) + state.display.y_adjust
    >>

    write_register(state, 0x2A, x)
    write_register(state, 0x2B, y)
    select_register(state, 0x2C)
  end

  defp write_data(state, data) do
    set_lcd_dc(state, 1)

    Stream.unfold(data, fn data ->
      case String.split_at(data, @chunk_size) do
        {"", ""} -> nil
        tuple -> tuple
      end
    end)
    |> Enum.each(fn chunk ->
      spi_transfer(state, chunk)
    end)
  end

  defguard is_pin_level(value) when value in [0, 1]

  defp set_lcd_cs(state, value) when is_pin_level(value) do
    Circuits.GPIO.write(state.display.lcd_cs, value)
  end

  defp set_lcd_rst(state, value) when is_pin_level(value) do
    Circuits.GPIO.write(state.display.lcd_rst, value)
  end

  defp set_lcd_dc(state, value) when is_pin_level(value) do
    Circuits.GPIO.write(state.display.lcd_dc, value)
  end

  defp set_lcd_bl(state, value) when is_pin_level(value) do
    Circuits.GPIO.write(state.display.lcd_bl, value)
  end

  defp spi_transfer(state, data) do
    Circuits.SPI.transfer(state.display.spi, data)
  end
end
