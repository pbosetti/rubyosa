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

require 'mkmf'

$CFLAGS << ' -Wall '
$LDFLAGS = '-framework Carbon -framework ApplicationServices'

if RUBY_VERSION =~ /^1.9/ then
  $CPPFLAGS += " -DRUBY_19"
end

exit 1 unless have_func('OSACopyScriptingDefinition')
exit 1 unless have_func('LSFindApplicationForInfo')

# Avoid `ID' and `T_DATA' symbol collisions between Ruby and Carbon.
# (adapted code from RubyAEOSA - FUJIMOTO Hisakuni  <hisa@fobj.com>)
if RUBY_VERSION =~ /^1.9/ then
  ruby_h = "#{Config::CONFIG['rubyhdrdir']}/ruby.h"
  intern_h = "#{Config::CONFIG['rubyhdrdir']}/ruby/intern.h"
else
  ruby_h = "#{Config::CONFIG['archdir']}/ruby.h"
  intern_h = "#{Config::CONFIG['archdir']}/intern.h"
end
new_filename_prefix = 'osx_'
[ ruby_h, intern_h ].each do |src_path|
    dst_fname = File.join('./src', new_filename_prefix + File.basename(src_path))
    $stderr.puts "create #{File.expand_path(dst_fname)} ..."
    File.open(dst_fname, 'w') do |dstfile|
        IO.foreach(src_path) do |line|
            line = line.gsub(/\bID\b/, 'RB_ID')
            line = line.gsub(/\bT_DATA\b/, 'RB_T_DATA')
            line = line.gsub(/\bintern.h\b/, "#{new_filename_prefix}intern.h")
            dstfile.puts line
        end
    end
end

# Generate the Makefile
create_makefile('osa', 'src')

# Tweak the Makefile to add an extra install task.
text = File.read('Makefile')
text << "\n\ninstall-extras: post-install.rb\n\t@$(RUBY) post-install.rb\n\n"
File.open('Makefile', 'w') { |io| io.write(text) }
