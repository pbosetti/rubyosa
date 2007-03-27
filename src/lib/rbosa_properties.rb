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

require 'enumerator'

module OSA
  @sym_to_code = {}
  @code_to_sym = {}

  def self.add_property(sym, code, override=false)
    unless override
      return if @sym_to_code.has_key?(sym) or @code_to_sym.has_key?(code)
    end
    @sym_to_code[sym] = code
    @code_to_sym[code] = sym
  end

  def self.sym_to_code(sym)
    @sym_to_code[sym]
  end

  def self.code_to_sym(code)
    @code_to_sym[code]
  end
end

[
  # pArcAngle
  :arc_angle, 'parc',
  :background_color, 'pbcl',
  :background_pattern, 'pbpt',
  :best_type, 'pbst',
  :bounds, 'pbnd',
  :class, 'pcls',
  :clipboard, 'pcli',
  :color, 'colr',
  :color_table, 'cltb',
  :contents, 'pcnt',
  :corner_curve_height, 'pchd',
  :corner_curve_width, 'pcwd',
  :dash_style, 'pdst',
  :default_type, 'deft',
  :definition_rect, 'pdrt',
  :enabled, 'enbl',
  :end_point, 'pend',
  :fill_color, 'flcl',
  :fill_pattern, 'flpt',
  :font, 'font',

  # pFormula
  :formula, 'pfor',
  :graphic_objects, 'gobs',
  :has_close_box, 'hclb',
  :has_title_bar, 'ptit',
  :id, 'ID  ',
  :index, 'pidx',
  :insertion_loc, 'pins',
  :is_floating, 'isfl',
  :is_front_process, 'pisf',
  :is_modal, 'pmod',
  :is_modified, 'imod',
  :is_resizable, 'prsz',
  :is_stationery_pad, 'pspd',
  :is_zoomable, 'iszm',
  :is_zoomed, 'pzum',
  :item_number, 'itmn',
  :justification, 'pjst',
  :line_arrow, 'arro',
  :menu_id, 'mnid',
  :name, 'pnam',

  # pNewElementLoc
  :new_element_loc, 'pnel',
  :pen_color, 'ppcl',
  :pen_pattern, 'pppa',
  :pen_width, 'ppwd',
  :pixel_depth, 'pdpt',
  :point_list, 'ptlt',
  :point_size, 'ptsz',
  :protection, 'ppro',
  :rotation, 'prot',
  :scale, 'pscl',
  :script, 'scpt',
  :script_tag, 'psct',
  :selected, 'selc',
  :selection, 'sele',
  :start_angle, 'pang',
  :start_point, 'pstp',
  :text_color, 'ptxc',
  :text_font, 'ptxf',
  :text_item_delimiters, 'txdl',
  :text_point_size, 'ptps',

  # pScheme
  :scheme, 'pusc',
  :host, 'HOST',
  :path, 'FTPc',
  :user_name, 'RAun',
  :user_password, 'RApw',
  :dns_form, 'pDNS',
  :url, 'pURL',
  :text_encoding, 'ptxe',
  :ftp_kind, 'kind',

  # pTextStyles
  :text_styles, 'txst',
  :transfer_mode, 'pptm',
  :translation, 'ptrs',
  :uniform_styles, 'ustl',
  :update_on, 'pupd',
  :user_selection, 'pusl',
  :version, 'vers',
  :visible, 'pvis'

].each_slice(2) { |sym, code| OSA.add_property(sym, code) }

# A convenience shortcut to :point_size
OSA.add_property(:size, 'ptsz', true)
