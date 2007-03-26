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
require 'rbosa'
require 'as'
require 'fileutils'

class TC_TextEdit < Test::Unit::TestCase
  def setup
    @textedit = OSA.app('TextEdit')
    @textedit.documents.each { |x| x.close }
  end

  def do_as(str)
    AS.do_as("tell application \"TextEdit\"\n#{str}\nend tell")
  end

  def test_app_properties
    prop = @textedit.properties
    assert_kind_of(Hash, prop)
    assert_equal(prop[:name], 'TextEdit')
    assert_equal(prop[:class], OSA::TextEdit::Application)
  end

  def test_new_doc_set_text1
    doc = @textedit.make(OSA::TextEdit::Document, nil, nil, {:ctxt => 'foo'})
    begin
      assert_kind_of(OSA::TextEdit::Document, doc)
      assert_equal('foo', doc.text.get)
      assert_equal('foo', do_as('get text of document 1'))
    ensure
      doc.close
    end
  end

  def test_new_doc_set_text2
    doc = @textedit.make(OSA::TextEdit::Document, :with_properties => {:ctxt => 'foo'})
    begin
      assert_kind_of(OSA::TextEdit::Document, doc)
      assert_equal('foo', doc.text.get)
      assert_equal('foo', do_as('get text of document 1'))
    ensure
      doc.close
    end
  end

  def test_new_doc_set_text2
    doc = @textedit.make(OSA::TextEdit::Document, :with_properties => {:text => 'foo'})
    begin
      assert_kind_of(OSA::TextEdit::Document, doc)
      assert_equal('foo', doc.text.get)
      assert_equal('foo', do_as('get text of document 1'))
    ensure
      doc.close
    end
  end

  def test_new_doc_set_text4
    doc = @textedit.make(OSA::TextEdit::Document)
    begin
      assert_kind_of(OSA::TextEdit::Document, doc)
      doc.text = 'foo'
      assert_equal('foo', doc.text.get)
      assert_equal('foo', do_as('get text of document 1'))
    ensure
      doc.close
    end
  end

  def test_doc_save_open1
    doc = @textedit.make(OSA::TextEdit::Document)
    begin
      doc.text = 'foo bar'
      FileUtils.rm_rf('/tmp/foo.rtf')
      doc.close(OSA::TextEdit::SAVO::YES, '/tmp/foo.rtf')
      assert_equal(0, @textedit.documents.size)
      @textedit.open('/tmp/foo.rtf')
      doc = @textedit.documents[0]
      assert_equal('foo bar', doc.text.get)
    ensure
      FileUtils.rm_rf('/tmp/foo.rtf')
      @textedit.documents.each { |d| d.close }
    end
  end
  
  def test_doc_save_open2
    doc = @textedit.make(OSA::TextEdit::Document)
    begin
      doc.text = 'foo bar'
      FileUtils.rm_rf('/tmp/foo.rtf')
      doc.close(:saving => OSA::TextEdit::SAVO::YES, :saving_in => '/tmp/foo.rtf')
      assert_equal(0, @textedit.documents.size)
      @textedit.open('/tmp/foo.rtf')
      doc = @textedit.documents[0]
      assert_equal('foo bar', doc.text.get)
    ensure
      FileUtils.rm_rf('/tmp/foo.rtf')
      @textedit.documents.each { |d| d.close }
    end
  end

  def test_duplicate_delete_words
    doc = @textedit.make(OSA::TextEdit::Document)
    begin
      assert_kind_of(OSA::TextEdit::Document, doc)
      doc.text = 'a c b'
      w = doc.text.paragraphs[0].words
      assert_equal(3, w.size)
      assert_equal(%w{a c b}, w.get)
      w[2].duplicate(w[0].after)
      w[0].duplicate(w[1].before)
      assert_equal(%w{a abc b}, w.get)
      w[0].delete
      assert_equal(2, w.size)
      assert_equal(%w{abc b}, w.get)
      w[1].delete
      assert_equal(1, w.size)
      assert_equal(%w{abc}, w.get)
      assert_equal(' abc ', doc.text.get)
    ensure
      doc.close
    end
  end

  def test_get_font_and_color_of_words
    doc = @textedit.make(OSA::TextEdit::Document)
    begin
      assert_kind_of(OSA::TextEdit::Document, doc)
      ary = %w{a b c d e f}
      doc.text = ary.join(' ')
      assert_equal(doc.text.words.size, ary.size)
      ary2 = doc.text.words.every(:font)
      assert_equal(ary.size, ary2.size)
      ary2.each { |f| assert_kind_of(String, f) }
      ary3 = doc.text.words.every(:color)
      assert_equal(ary.size, ary3.size)
      ary3.each { |c| assert_kind_of(OSA::TextEdit::Color, c) }
      ary4 = doc.text.words.every(:color).get
      assert_equal(ary.size, ary4.size)
      ary4.each do |v|
        assert_kind_of(Array, v)
        assert_equal([0, 0, 0], v)
      end
      blue = [0, 0, 65535]
      doc.text.words[0].color = blue
      assert_equal(blue, doc.text.words[0].color.get)
    ensure
      doc.close
    end 
  end

  def test_system_events_keystrokes
    se = OSA.app('System Events')
    @textedit.activate
    
    doc = @textedit.make(OSA::TextEdit::Document)
    doc.text = 'foo'
    assert_equal('foo', doc.text.get)

    begin
      OSA.wait_reply = true
      se.keystroke('a', :using => OSA::SystemEvents::EMDS::COMMAND_DOWN) # select all
      se.keystroke('x', :using => OSA::SystemEvents::EMDS::COMMAND_DOWN) # cut
      assert_equal('', doc.text.get)
      se.keystroke('z', :using => OSA::SystemEvents::EMDS::COMMAND_DOWN) # undo
      assert_equal('foo', doc.text.get)
      se.keystroke('z', :using => [OSA::SystemEvents::EMDS::COMMAND_DOWN,
                                   OSA::SystemEvents::EMDS::SHIFT_DOWN]) # redo
      assert_equal('', doc.text.get)
      doc.close(:saving => OSA::TextEdit::SAVO::NO)
    ensure
      OSA.wait_reply = false
    end
  end

  def test_make_document_arg_errors
    assert_raises(ArgumentError) { @textedit.make }
    assert_raises(ArgumentError) { @textedit.make(:with_properties => {}) }
    assert_raises(ArgumentError) { @textedit.make(OSA::TextEdit::Document, :with_properties => {}, :invalid_parameter => 42) }
  end
end
