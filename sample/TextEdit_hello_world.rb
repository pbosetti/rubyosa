# Create a new TextEdit document, with the 'Hello World' text.

require 'rbosa'

OSA.app('TextEdit').make(OSA::TextEdit::Document).text = 'Hello World'
