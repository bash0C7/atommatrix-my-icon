require 'ws2812'
require 'gpio'

led = WS2812.new(RMTDriver.new(32))


class Button
  HIGH = 1
  LOW = 0
  
  def initialize(pin)
    @gpio = GPIO.new(pin, GPIO::IN)
    @last_state = HIGH
    @pressed = false
    @on_press_callback = Proc.new {}
  end
  
  def on_press(&block)
    @on_press_callback = block
  end
  
  def update
    current = @gpio.read
    if @last_state == HIGH && current == LOW && !@pressed
      @pressed = true
      @on_press_callback.call
    elsif current == HIGH
      @pressed = false
    end
    @last_state = current
  end
end

bash_pattern = [
  [14, 0, 0], [23, 0, 0], [19, 3, 0], [24, 0, 0], [21, 0, 0],
  [20, 13, 9], [22, 2, 1], [25, 19, 11], [21, 6, 0], [25, 23, 19],
  [23, 10, 2], [24, 8, 1], [19, 0, 0], [21, 4, 0], [19, 11, 9],
  [25, 12, 1], [24, 0, 0], [24, 0, 1], [25, 12, 1], [22, 7, 1],
  [22, 18, 13], [18, 9, 7], [20, 4, 1], [22, 18, 14], [21, 18, 13]
].map do |rgb|
  r, g, b = rgb
  ((r << 16) | (g << 8) | b)
end

button = Button.new(39)
button.on_press do
  puts "Button pressed! Dimming LEDs..."  # デバッグ用
  bash_pattern.map! do |hex|
    r = (hex >> 16) & 0xff
    g = (hex >> 8) & 0xff
    b = hex & 0xff
    r = (r * 30) / 100  # 30%でさらに明確に
    g = (g * 30) / 100
    b = (b * 30) / 100
    (r << 16) | (g << 8) | b
  end
end

buffer = Array.new(bash_pattern.size) { 0x000000 }

patterns = [
  [[true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true,
    true, true, true, true, true], 1000],
  [[false, false, false, true, true,
    false, false, false, true, true,
    false, true, true, true, true,
    true, false, false, true, true,
    false, true, true, true, true], 500],
  [[false, true, true, true, false,
    true, false, false, true, true,
    true, true, true, true, true,
    true, false, false, true, true,
    true, false, false, true, true], 500],
  [[false, true, true, true, false,
    false, false, false, true, true,
    false, true, true, true, false,
    true, true, false, false, false,
    false, true, true, true, false], 500],
  [[false, false, false, true, true,
    false, false, false, true, true,
    false, true, true, true, true,
    true, false, false, true, true,
    true, false, false, true, true], 500]
].map do |bits, time|
  [bits.map { |x| x ? 0xffffff : 0x000000 }, time]
end

loop do
  button.update

  patterns.each do |pattern, duration|
    bash_pattern.each_with_index do |b, i|
      buffer[i] = b & pattern[i]
    end
    
    led.show_hex(*buffer)
    
    sleep_ms duration

    bash_pattern.each_with_index do |b, i|
      buffer[i] = 0x000000
    end
    
    led.show_hex(*buffer)
    
    sleep_ms 100
  end
end
