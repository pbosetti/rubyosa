# Periodically set your iChat image to one of the default images.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

ichat = OSA.app('iChat')

old_image = ichat.image
trap('INT') { ichat.image = old_image; exit 0 }

paths = Dir.glob("/Library/User Pictures/**/*.tif")

while true do
  paths.each do |path|
    ichat.image = File.read(path)
    sleep 2
  end
end
