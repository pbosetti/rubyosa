# Create new TextEdit documents with a 'Hello World' text.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

textedit = OSA.app('TextEdit')

# Complex way.
textedit.make(OSA::TextEdit::Document, nil, nil, {:ctxt => 'Hello World #1'})

# Easier way.
textedit.make(OSA::TextEdit::Document).text = 'Hello World #2'

# Easiest way.
OSA::TextEdit::Document.new.text = 'Hello World #3'
