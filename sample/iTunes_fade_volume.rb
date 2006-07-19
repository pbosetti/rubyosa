require 'rbosa'

app = OSA.app_with_name('iTunes')

original_volume = app.sound_volume
track = app.current_track

if original_volume == 0 or track.nil?
    puts "Please select a track and/or set a higher volume."
    exit 1
end

app.sound_volume = 0
track.play(false)

0.step(original_volume, original_volume / 8.0) do |volume|
    app.sound_volume = volume
    sleep(0.1)
end

app.sound_volume = original_volume
