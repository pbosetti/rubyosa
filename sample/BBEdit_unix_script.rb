# Ask BBEdit to run the uptime(1) command and get the result.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

puts 'Asking for uptime...'

bbedit = OSA.app('BBEdit')

bbedit.make(OSA::BBEdit::TextDocument).text = <<EOS
#!/bin/sh
uptime
EOS

bbedit.run_unix_script

output_doc = bbedit.text_documents.find { |x| x.name == 'Unix Script Output' }

puts output_doc.text.get
