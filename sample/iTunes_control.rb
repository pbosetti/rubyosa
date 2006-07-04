# Simple iTunes controller.

require 'rbosa'
require 'curses'
include Curses

app = OSA.app_with_name('iTunes')

if app.current_track.nil?
    begin
        app.sources[0].playlists[0].tracks[0].play
    rescue => e
        p e
        puts "You do not appear to have tracks in your iTunes database."
        exit 1
    end
end

init_screen

addstr <<EOS
Keys available:
  SPACE     toggle play/pause
  p         go to previous song
  n         go to next song
  f         toggle fast forward
  r         toggle rewind
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
            if app.player_state == OSA::Itunes::EPLS::FAST_FORWARDING
                app.resume
            else
                app.fast_forward
            end
        when 'r'
            if app.player_state == OSA::Itunes::EPLS::REWINDING
                app.resume
            else
                app.rewind
            end
        when 'q' 
            break
        end 
    end
ensure
    echo
end
