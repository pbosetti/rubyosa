# Retrieve and show every selected message content in Mail into new TextEdit documents. 

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'

OSA.utf8_strings = true
textedit = OSA.app('TextEdit')
mailApp = OSA.app('Mail')
viewers = mailApp.message_viewers
viewers.each do |viewer|
  viewer.selected_messages.each do |message|
    textedit.make(OSA::TextEdit::Document).text = message.content
  end
end
