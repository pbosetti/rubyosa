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

first = selection.first.artist 
feed = "http://ws.audioscrobbler.com/1.0/artist/#{CGI::escape(first)}/toptags.xml"
doc = Document.new(Net::HTTP.get(URI(feed))) 

selection.each do |track|
  if doc.root.attributes['artist'] == track.artist
    genre = doc.root[1][1].text.capitalize
  else
    puts 'Querying Last.fm again...' 
    feed = "http://ws.audioscrobbler.com/1.0/artist/#{CGI::escape(track.artist)}/toptags.xml"
    doc = Document.new(Net::HTTP.get(URI(feed)))
    genre = doc.root[1][1].text.capitalize
  end
  track.genre = genre
end
