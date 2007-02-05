# Print the given application's sdef(5).

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'
require 'rexml/document'

def usage
    STDERR.puts <<-EOS
Usage: #{$0} [--name | --path | --bundle_id | --signature] ...
Examples:
    #{$0} --name iTunes
    #{$0} --path /Applications/iTunes.app 
    #{$0} --bundle_id com.apple.iTunes 
    #{$0} --signature hook
EOS
    exit 1
end

usage unless ARGV.length == 2 

key = case ARGV.first
    when '--name'
        :name
    when '--path'
        :path
    when '--bundle_id'
        :bundle_id
    when '--signature'
        :signature
    else
        usage
end

app = OSA.app(key => ARGV.last)
doc = REXML::Document.new(app.sdef)
doc.write(STDOUT, 0)
puts ""
