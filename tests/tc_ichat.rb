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
require 'fileutils'
require 'as'

class TC_iChat < Test::Unit::TestCase
  def setup
    @ichat = OSA.app('iChat')
  end

  def do_as(str)
    AS.do_as("tell application \"iChat\"\n#{str}\nend tell")
  end

  def test_accounts
    accounts = @ichat.accounts
    assert(accounts.size > 0)
    assert_kind_of(String, accounts[0].name)
    ary = accounts[0].capabilities
    assert_kind_of(Array, ary)
    assert(ary.all? { |x| x.is_a?(OSA::Enumerator) })
  end

  def test_set_status
    old_status = @ichat.status_message
    assert_kind_of(String, old_status)
    begin
      @ichat.status_message = 'foo'
      assert_equal('foo', @ichat.status_message)
      assert_equal('foo', do_as('get status message'))
    ensure
      @ichat.status_message = old_status
    end
  end

  def test_set_image
    old_image_data = @ichat.image
    assert_kind_of(String, old_image_data)
    begin
      path = "/Library/User\ Pictures/Animals/Cat.tif"
      @ichat.image = File.read(path)
      FileUtils.rm_rf('/tmp/foo.jpg')
      code = <<EOS
set imageData to image
set filename to POSIX path of "/tmp/foo.jpg"
set fileReference to open for access filename with write permission
write imageData starting at 0 to fileReference
close access fileReference
EOS
      do_as(code)
      image2 = File.read('/tmp/foo.jpg')
      assert_equal(@ichat.image, image2)
    ensure
      @ichat.image = old_image_data
    end
  end
end
