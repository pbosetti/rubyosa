# Open the artwork of the current iTunes track in Preview.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

artworks = OSA.app('iTunes').current_track.artworks
if artworks.size == 0
  puts "No artwork for current track."
  exit 1
end

File.open('/tmp/foo.pict', 'w') { |io| io.write(artworks[0].data) }
system("open -a Preview /tmp/foo.pict")
