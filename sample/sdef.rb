# Print the given application's sdef(5).

require 'rbosa'
require 'rexml/document'

if ARGV.length != 1
    STDERR.puts "Usage: #{$0} <application-name>"
    exit 1
end

path, sdef = OSA.__scripting_info__(ARGV.first)
doc = REXML::Document.new(sdef)
doc.write(STDOUT, 1)
puts ""
