# Print the given application's sdef(5).

begin require 'rubygems' rescue LoadError end
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

msg = case ARGV.first
    when '--name'
        :app_with_name
    when '--path'
        :app_with_path
    when '--bundle_id'
        :app_with_bundle_id
    when '--signature'
        :app_with_signature
    else
        usage
end

app = OSA.send(msg, ARGV.last)
doc = REXML::Document.new(app.sdef)
doc.write(STDOUT, 0)
puts ""
