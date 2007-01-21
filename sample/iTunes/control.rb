# Simple iTunes controller.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'
require 'curses'
include Curses

app = OSA.app('iTunes')
OSA.utf8_strings = true

if app.current_track.nil?
    # We don't support write access now, so...
    puts "Please select a track in iTunes and retry again."
    exit 1
end

init_screen

addstr <<EOS
Keys available:
  SPACE     toggle play/pause
  p         go to previous song
  n         go to next song
  f         toggle fast forward
  r         toggle rewind
  m         toggle mute
  q         exit the program

On track:
EOS

begin
    noecho
    while true
        setpos(9, 2)
        addstr "#{app.player_state.to_s.capitalize} : #{app.current_track.name}".ljust(cols - 3)
        refresh
        x = getch
        case x.chr
        when ' '
            app.playpause
        when 'p'
            app.previous_track
        when 'n'
            app.next_track
        when 'f'
            if app.player_state == OSA::ITunes::EPLS::FAST_FORWARDING
                app.resume
            else
                app.fast_forward
            end
        when 'r'
            if app.player_state == OSA::ITunes::EPLS::REWINDING
                app.resume
            else
                app.rewind
            end
        when 'm'
            app.mute = !app.mute?
        when 'q' 
            break
        end 
    end
ensure
    echo
end
