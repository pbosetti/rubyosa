# Create a new TextEdit document, with the 'Hello World' text.

begin require 'rubygems' rescue LoadError end
require 'rbosa'

OSA.app('TextEdit').make(OSA::TextEdit::Document).text = 'Hello World'
