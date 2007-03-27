# Copyright (c) 2006-2007, Apple Inc. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1.  Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer. 
# 2.  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution. 
# 3.  Neither the name of Apple Inc. ("Apple") nor the names of
#     its contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission. 
# 
# THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'test/unit'
require 'tempfile'
require 'fileutils'
require 'rbosa'
require 'as'

class TC_iTunes < Test::Unit::TestCase
  def setup
    @itunes = OSA.app('iTunes')
  end

  def do_as(str)
    AS.do_as("tell application \"iTunes\"\n#{str}\nend tell")
  end

  def test_sdef
    assert_kind_of(String, @itunes.sdef)
  end

  def test_source
    source = @itunes.sources[0]
    assert_kind_of(OSA::ITunes::Source, source)
    assert_kind_of(OSA::ITunes::Playlist, source.playlists[0])
    assert_kind_of(OSA::ITunes::LibraryPlaylist, source.library_playlists[0])
    assert_equal('Library', source.library_playlists[0].name)
  end

  def test_track_properties
    track = @itunes.current_track
    assert_kind_of(OSA::ITunes::Track, track)
    assert_kind_of(OSA::ITunes::Track, track.get)
    assert_kind_of(String, track.name)
    assert_kind_of(String, track.artist)
    assert_kind_of(Integer, track.rating)
    assert_kind_of(Integer, track.played_count)
    v = track.enabled?
    assert((v.is_a?(TrueClass) or v.is_a?(FalseClass)))
  end

  def test_track_renaming
    track = @itunes.current_track
    old_name = track.name
    begin
      track.name = 'foo'
      assert_equal('foo', track.name)
      assert_equal('foo', do_as('get name of current track')) 
      # Test unicode
      OSA.utf8_strings = true
      hiragana = "\343\201\262\343\202\211\343\201\214\343\201\252"
      track.name = hiragana
      assert_equal(hiragana, track.name)
      assert_equal(hiragana, do_as('get name of current track'))
    ensure
      track.name = old_name
    end
  end

  def test_track_rating
    track = @itunes.current_track
    old_rating = track.rating
    begin
      track.rating = 42
      assert_equal(42, track.rating)
      assert_equal('42', do_as('get rating of current track'))
    ensure
      track.rating = old_rating
    end
  end

  def test_track_artwork
    library = @itunes.sources[0].library_playlists[0]
    track_with_artwork = library.file_tracks.find do |track|
      track.artworks.size > 0
    end
    raise "No track with artwork in the iTunes library" if track_with_artwork.nil?
    f = Tempfile.new('artwork')
    begin
      f.write(track_with_artwork.artworks[0].data)
      f.close
      r = `file #{f.path}`
      raise "file(1) returned error #{$?} on #{f.path}" if $?.to_i != 0
      assert(/(PNG|JPEG|TIFF) image data/.match(r))
      # TODO: do the same thing in AppleScript and compare the generated files
    ensure
      f.unlink
    end
  end

  def test_add_track_to_playlist
    track = @itunes.sources[0].library_playlists[0].file_tracks[0]
    assert_kind_of(OSA::ITunes::FileTrack, track)
    FileUtils.cp(track.location, '/tmp/foo.mp3')
    begin
      track2 = @itunes.add('/tmp/foo.mp3')
      assert_kind_of(OSA::ITunes::FileTrack, track2)
      assert_equal(track.location, track2.location)
    ensure
      FileUtils.rm_f('/tmp/foo.mp3')
    end
  end

  def test_get_name_of_sources
    ary = @itunes.sources.every(:name)
    assert_kind_of(Array, ary)
    assert_equal(ary.length, @itunes.sources.length)
  end
end
