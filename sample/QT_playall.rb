# Opens given movies and in QuickTime and starts playing them indefinitely in fullscreen mode.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

if ARGV.empty?
    STDERR.puts "Usage: #{$0} <movies-files>"
    exit 1
end

app = OSA.app('QuickTime Player')
ARGV.each { |p| app.open(p) }
l = app.movies.to_a
exit if l.length == 0
last = nil
loop do
    l2 = []
    l.length.times { l2 << l.slice!(rand(l.length)) }
    l2[0], l2[1] = l2[1], l2[0] if l2[0] == last and l2.length > 1 # not to have the same file playing twice consecutively
    l2.each do |m|
        m.rewind # to be sure that we start at the beginning of the movie
        m.present
        sleep 0.1 while m.playing?
        m.stop # to be sure we are not in presentation mode anymore
        # if we do not end with a stop, and the movie has been stopped by the user,
        # the next present will not play the movie because an other movie is still in presentation mode
        last = m
    end
    l = l2
end
