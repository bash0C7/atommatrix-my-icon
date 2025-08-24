require 'ws2812'
require 'gpio'

led = WS2812.new(RMTDriver.new(32))

class Button
  HIGH = 1
  LOW = 0
  
  def initialize(pin)
    @gpio = GPIO.new(pin, GPIO::IN)
    @last_state = HIGH
    @wait_count = 0
    @on_press_callback = Proc.new {}
  end
  
  def on_press(&block)
    @on_press_callback = block
  end
  
  def update
    current = @gpio.read
    if @last_state == HIGH && current == LOW && @wait_count == 0
      @wait_count = 20
      @last_state = current
      @on_press_callback.call
    end
    @wait_count -= 1 if @wait_count > 0
    @last_state = current
  end
end

bash_pattern = [
  [56, 0, 1], [95, 0, 3], [79, 13, 2], [96, 0, 3], [85, 0, 1],
  [81, 55, 36], [88, 10, 4], [100, 78, 47], [87, 25, 2], [101, 92, 77],
  [95, 40, 11], [97, 32, 5], [79, 0, 1], [84, 19, 2], [78, 45, 38],
  [100, 49, 6], [99, 0, 3], [97, 0, 4], [101, 48, 6], [89, 29, 5],
  [89, 72, 55], [74, 37, 28], [81, 17, 7], [91, 75, 57], [87, 72, 55]
].map do |rgb|
  r, g, b = rgb
  ((r << 16) | (g << 8) | b)
end

button = Button.new(39)
button.on_press do
  bash_pattern.map! do |hex|
    r = (hex >> 16) & 0xff
    g = (hex >> 8) & 0xff
    b = hex & 0xff
    r = (r * 90) / 100
    g = (g * 90) / 100
    b = (b * 90) / 100
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
