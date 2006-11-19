# Lists the content of the Finder desktop.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

ary = OSA.app('Finder').desktop.entire_contents.get
ary.each do |x|
    next unless x.is_a?(OSA::Finder::Item)
    puts "#{x.class.name.sub(/^.+::/, '').sub(/_/, ' ').ljust(25)} #{x.name}"
end
