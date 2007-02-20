# For each selected track in iTunes, retrieve the genre from Last.fm and accordingly tag the track.

begin require 'rubygems'; rescue LoadError; end
require 'rbosa'
require 'net/http'
require 'cgi'
require 'rexml/document'
include REXML

itunes = OSA.app('iTunes')
selection = itunes.selection.get
if selection.empty?
  $stderr.puts "Please select some tracks."
  exit 1
end
selection.each do |track|
  feed = "http://ws.audioscrobbler.com/1.0/artist/#{CGI::escape(track.artist)}/toptags.xml"
  doc = Document.new(Net::HTTP.get(URI(feed)))
  track.genre = doc.root[1][1].text
end
