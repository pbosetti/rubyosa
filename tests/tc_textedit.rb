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
    @textedit = OSA.app_with_name('TextEdit')
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

  def test_new_doc_set_text3
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
      doc.save('RTF', '/tmp/foo.rtf')
      @textedit.documents.each { |d| d.close }
      assert_equal(0, @textedit.documents.size)
      @textedit.open('/tmp/foo.rtf')
      doc = @textedit.documents[0]
      assert_equal('foo bar', doc.text.get)
    ensure
      @textedit.documents.each { |d| d.close }
    end
  end
  
  def test_doc_save_open2
    doc = @textedit.make(OSA::TextEdit::Document)
    begin
      doc.text = 'foo bar'
      FileUtils.rm_rf('/tmp/foo.rtf')
      doc.save(:as => 'RTF', :in => '/tmp/foo.rtf')
      @textedit.documents.each { |d| d.close }
      assert_equal(0, @textedit.documents.size)
      @textedit.open('/tmp/foo.rtf')
      doc = @textedit.documents[0]
      assert_equal('foo bar', doc.text.get)
    ensure
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
end
