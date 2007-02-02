# Create new TextEdit documents with a 'Hello World' text.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

textedit = OSA.app('TextEdit')

# Complex way.
textedit.make(OSA::TextEdit::Document, :with_properties => {:text => 'Hello World #1'})

# Easier way.
textedit.make(OSA::TextEdit::Document).text = 'Hello World #2'

=begin
# Easiest way, not implemented for now.
document = OSA::TextEdit::Document.new
document.text = 'Hello World #3'
textedit << document
=end
