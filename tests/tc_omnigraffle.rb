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

class TC_OmniGraffle < Test::Unit::TestCase
  def setup
    @omnigraffle = OSA.app('OmniGraffle Professional')
  end

  def test_smart_get
    begin
      @omnigraffle.open(File.join(Dir.pwd, 'data/test.graffle'))
      obj = @omnigraffle.documents[0].canvases[0].groups[0]
      assert_kind_of(OSA::OmniGraffleProfessional::Group, obj)
      resolved_obj = obj.get
      assert_kind_of(OSA::OmniGraffleProfessional::Table, resolved_obj)
    ensure
      @omnigraffle.documents.each { |d| d.close }
    end
  end

  def test_create_shape
    begin
      @omnigraffle.open(File.join(Dir.pwd, 'data/test.graffle'))

      origin, size = [87.0, 68.0], [102.0, 102.0]
      g = @omnigraffle.make(OSA::OmniGraffleProfessional::Shape, 
        :at => @omnigraffle.windows[0].canvas.graphics[0], 
        :with_properties => {:origin => origin, :size => size})
      assert_kind_of(OSA::OmniGraffleProfessional::Graphic, g)
  
      assert_kind_of(OSA::OmniGraffleProfessional::Point, g.origin)
      assert_equal(origin[0], g.origin.x)
      assert_equal(origin[1], g.origin.y)
      assert_equal(origin, g.origin.get)
  
      assert_kind_of(OSA::OmniGraffleProfessional::Point, g.size)
      assert_equal(size[0], g.size.x)
      assert_equal(size[1], g.size.y)
      assert_equal(size, g.size.get)
    ensure
      @omnigraffle.documents.each { |d| d.close }
    end
  end
end
