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
require 'rbconfig'
require 'fileutils'

class TC_RDoc < Test::Unit::TestCase
  def setup
    @ruby_path = File.join(Config::CONFIG["bindir"], Config::CONFIG["RUBY_INSTALL_NAME"])
  end

  def test_app_name
    job('--name iTunes')
  end

  def test_app_path
    job('--path /Applications/iTunes.app') 
  end

  def test_app_signature
    job('--signature hook')
  end

  def test_app_bundle_id
    job('--bundle_id com.apple.iTunes')
  end

  def test_additions_name
    job('--addition --name StandardAdditions')
  end

  def test_additions_path
    job('--addition --path /System/Library/ScriptingAdditions/StandardAdditions.osax')
  end

=begin
  # This currently doesn't work :(
  def test_additions_signature
    job('--addition --signature ascr')
  end

  def test_additions_bundle_id
    job('--addition --bundle_id com.apple.osax.standardadditions')
  end
=end

  def job(arg)
    FileUtils.rm_rf('/tmp/XXX')
    line = "#{@ruby_path} -I.. -I../src/lib ../bin/rdoc-osa #{arg} --quiet -o /tmp/XXX"
    assert(system(line), "Line was: #{line}")
    assert File.exist?('/tmp/XXX/index.html')
    FileUtils.rm_rf('/tmp/XXX')
  end
end
