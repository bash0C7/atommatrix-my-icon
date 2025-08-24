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
  [28, 0, 0], [47, 0, 1], [39, 6, 1], [48, 0, 1], [42, 0, 0],
  [40, 27, 18], [44, 5, 2], [50, 39, 23], [43, 12, 1], [50, 46, 38],
  [47, 20, 5], [48, 16, 2], [39, 0, 0], [42, 9, 1], [39, 22, 19],
  [50, 24, 3], [49, 0, 1], [48, 0, 2], [50, 24, 3], [44, 14, 2],
  [44, 36, 27], [37, 18, 14], [40, 8, 3], [45, 37, 28], [43, 36, 27]
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
