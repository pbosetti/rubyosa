# Quick inspection of iTunes' sources, playlists and tracks.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

app = OSA.app('iTunes')
OSA.utf8_strings = true
app.sources.each do |source|
    puts source.name
    source.playlists.each do |playlist|
        puts " -> #{playlist.name}"
        playlist.tracks.each do |track|
            puts "     -> #{track.name}" if track.enabled?
        end
    end
end
