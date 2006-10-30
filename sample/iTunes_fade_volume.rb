# Start playing, then fade the volume from 0 to the original setting.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

app = OSA.app('iTunes')

original_volume = app.sound_volume

if original_volume == 0 or app.current_track.nil?
    puts "Please select a track and/or set a higher volume."
    exit 1
end

app.sound_volume = 0
app.play

0.step(original_volume, original_volume / 8.0) do |volume|
    app.sound_volume = volume
    sleep(0.1)
end

app.sound_volume = original_volume
