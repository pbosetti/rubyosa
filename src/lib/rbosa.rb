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

$KCODE = 'u' # we will use UTF-8 strings

require 'osa'
require 'date'
require 'uri'
require 'iconv'

# Try to load RubyGems first, libxml-ruby may have been installed by it.
begin require 'rubygems'; rescue LoadError; end

# If libxml-ruby is not present, switch to REXML.
USE_LIBXML = begin
  require 'xml/libxml'

  # libxml-ruby bug workaround.
  class XML::Node
    alias_method :old_cmp, :==
    def ==(x)
      (x != nil and old_cmp(x))
    end
  end
  true
rescue LoadError
  require 'rexml/document'

  # REXML -> libxml-ruby compatibility layer.
  class REXML::Element
    alias_method :old_find, :find
    def find(path=nil, &block)
      if path.nil? and block
        old_find { |*x| block.call(*x) }
      else
        list = []
        ::REXML::XPath.each(self, path) { |e| list << e }
        list
      end
    end
    def [](attr)
      attributes[attr]
    end
    def find_first(path)
      ::REXML::XPath.first(self, path)
    end
  end
  false
end

class String
  def to_4cc
    OSA.__four_char_code__(Iconv.iconv('MACROMAN', 'UTF-8', self).to_s)
  end
end

class OSA::Enumerator
  attr_reader :code, :name, :group_code
  
  def initialize(const, name, code, group_code)
    @const, @name, @code, @group_code = const, name, code, group_code
    self.class.instances[code] = self 
  end
   
  def self.enum_for_code(code)
    instances[code]
  end

  def to_s
    @name
  end

  def inspect
    "<#{@const}>"
  end

  #######
  private
  #######

  def self.instances
    (@@instances rescue @@instances = {})
  end
end

class OSA::Element
  REAL_NAME = CODE = nil
  def to_rbobj
    unless __type__ == 'null'
    val = OSA.convert_to_ruby(self)
    val == 'msng' ? nil : val == nil ? self : val
    end
  end
  
  def self.from_rbobj(requested_type, value, enum_group_codes)
    obj = OSA.convert_to_osa(requested_type, value, enum_group_codes)
    obj.is_a?(OSA::Element) ? obj : self.__new__(*obj)
  end
end

class OSA::ElementList
  include Enumerable
  def each
    self.size.times { |i| yield(self[i]) }
  end
end

class OSA::ElementRecord
  def self.from_hash(hash)
    value = {}
    hash.each do |code, val| 
      key = OSA.sym_to_code(code)
      if key.nil?
        raise ArgumentError, "invalid key `#{code}'" if code.to_s.length != 4
        key = code
      end
      value[key] = OSA::Element.from_rbobj(nil, val, nil)
    end
    OSA::ElementRecord.__new__(value)
  end

  def to_hash
    h = {}
    self.to_a.each do |code, val|
      key = (OSA.code_to_sym(code) or code)
      h[key] = val.to_rbobj
    end 
    return h
  end
end

module OSA::ObjectSpecifier
  def get
    new_obj = @app.__send_event__('core', 'getd', [['----', self]], true).to_rbobj
    if !new_obj.is_a?(self.class) and new_obj.is_a?(OSA::Element) and self.respond_to?(:properties) and (klass = self.properties[:class])
      klass.__duplicate__(new_obj)
    else
      new_obj
    end
  end
end

class OSA::ObjectSpecifierList
  include Enumerable
  
  def initialize(app, desired_class, container)
    @app, @desired_class, @container = app, desired_class, container
  end
   
  def length
    @app.__send_event__(
      'core', 'cnte', 
      [['----', @container], ['kocl', OSA::Element.__new__('type', @desired_class::CODE.to_4cc)]], 
      true).to_rbobj
  end
  alias_method :size, :length

  def empty?
    length == 0
  end

  def [](idx)
    idx += 1 # AE starts counting at 1.
    o = obj_spec_with_key(OSA::Element.__new__('long', [idx].pack('l')))
    o.instance_variable_set(:@app, @app)
    o.extend OSA::ObjectSpecifier
  end

  def first
    self[0]
  end

  def last
    self[-1]
  end

  def each
    self.length.times { |i| yield(self[i]) }
  end

  def get
    o = obj_spec_with_key(OSA::Element.__new__('abso', 'all '.to_4cc))
    o.instance_variable_set(:@app, @app)
    o.extend OSA::ObjectSpecifier
    o.get
  end
  alias_method :to_a, :get

  def ==(other)
    other.kind_of?(self.class) \
    and other.length == self.length \
    and (0..other.length).all? { |i| other[i] == self[i] }
  end

  def inspect
    super.scan(/^([^ ]+)/).to_s << " desired_class=#{@desired_class}>"
  end

  def every(sym)
    if @desired_class.method_defined?(sym) and code = OSA.sym_to_code(sym)
      o = obj_spec_with_key(OSA::Element.__new__('abso', 'all '.to_4cc))
      pklass = @app.classes[code]
      if pklass.nil? or !OSA.lazy_events
        @app.__send_event__('core', 'getd', 
          [['----', OSA::Element.__new_object_specifier__('prop', o,
          'prop', OSA::Element.__new__('type', code.to_4cc))]],
          true).to_rbobj
      else
        OSA::ObjectSpecifierList.new(@app, pklass, o)
      end
    else
      raise ArgumentError, "desired class `#{@desired_class}' does not have a attribute named `#{sym.to_s}'"
    end
  end

  #######
  private
  #######

  def obj_spec_with_key(element)
    @desired_class.__new_object_specifier__(@desired_class::CODE, @container,
                        'indx', element)
  end
end

module OSA::EventDispatcher

  SCRIPTING_ADDITIONS_DIR = [
    '/System/Library/ScriptingAdditions',
    '/Library/ScriptingAdditions'
  ]
  if home = ENV['HOME']
    SCRIPTING_ADDITIONS_DIR << File.join(home, '/Library/ScriptingAdditions')
  end

  def merge(args)
    args = { :name => args } if args.is_a?(String)
    by_name = args[:name]
    begin
      name, target, sdef = OSA.__scripting_info__(args)
    rescue RuntimeError => excp
      # If an sdef bundle can't be find by name, let's be clever and look in the ScriptingAdditions locations.
      if by_name 
        args = SCRIPTING_ADDITIONS_DIR.each do |dir|
          path = ['.app', '.osax'].map { |e| File.join(dir, by_name + e) }.find { |p| File.exists?(p) }
          if path
            break { :path => path }
          end
        end 
        if args.is_a?(Hash)
          by_name = nil
          retry
        end
      end
      raise excp
    end
    app_module_name = self.class.name.scan(/^OSA::(.+)::.+$/).flatten.first
    app_module = OSA.const_get(app_module_name) 
    OSA.__load_sdef__(sdef, target, app_module, true, self.class)
    (self.__send_event__('ascr', 'gdut', [], true) rescue nil) # Don't ask me why...
    return self 
  end
end

module OSA
  def self.app_with_name(name)
    STDERR.puts "OSA.app_with_name() has been deprecated and its usage is now discouraged. Please use OSA.app('name') instead."
    self.__app__(*OSA.__scripting_info__(:name => name))
  end

  def self.app_with_path(path)
    STDERR.puts "OSA.app_by_path() has been deprecated and its usage is now discouraged. Please use OSA.app(:path => 'path') instead."
    self.__app__(*OSA.__scripting_info__(:path => path))
  end

  def self.app_by_bundle_id(bundle_id)
    STDERR.puts "OSA.app_by_bundle_id() has been deprecated and its usage is now discouraged. Please use OSA.app(:bundle_id => 'bundle_id') instead."
    self.__app__(*OSA.__scripting_info__(:bundle_id => bundle_id))
  end

  def self.app_by_signature(signature)
    STDERR.puts "OSA.app_by_signature() has been deprecated and its usage is now discouraged. Please use OSA.app(:signature => 'signature') instead."
    self.__app__(*OSA.__scripting_info__(:signature => signature))
  end

  def self.app(*args)
    if args.size == 2
      if args.first.is_a?(String) and args.last.is_a?(Hash)
        hash = args.last
        if hash.has_key?(:name)
          warn "Given Hash argument already has a :name key, ignoring the first String argument `#{args.first}'"
        else
          hash[:name] = args.first
        end
        args = hash
      else
        raise ArgumentError, "when called with 2 arguments, the first is supposed to be a String and the second a Hash"
      end
    else
      if args.size != 1
        raise ArgumentError, "wrong number of arguments (#{args.size} for at least 1)"
      end
      args = args.first
    end
    args = { :name => args } if args.is_a?(String)
    self.__app__(*OSA.__scripting_info__(args))
  end

  @conversions_to_ruby = {}
  @conversions_to_osa = {}

  def self.add_conversion(hash, types, block, max_arity, replace=false)
    raise "Conversion block has to accept either #{(1..max_arity).to_a.join(', ')} arguments" unless (1..max_arity) === block.arity
    types.each do |type|
      next if !replace and hash.has_key?(type)
      hash[type] = block 
    end
  end

  def self.replace_conversion_to_ruby(*types, &block)
    add_conversion(@conversions_to_ruby, types, block, 3, true)
  end
  
  def self.add_conversion_to_ruby(*types, &block)
    add_conversion(@conversions_to_ruby, types, block, 3)
  end

  def self.replace_conversion_to_osa(*types, &block)
    add_conversion(@conversions_to_osa, types, block, 2, true)
  end
  
  def self.add_conversion_to_osa(*types, &block)
    add_conversion(@conversions_to_osa, types, block, 2)
  end
  
  def self.convert_to_ruby(osa_object)
    osa_type = osa_object.__type__
    osa_data = osa_object.__data__(osa_type) if osa_type and osa_type != 'null'
    if conversion = @conversions_to_ruby[osa_type]
      args = [osa_data, osa_type, osa_object]
      conversion.call(*args[0..(conversion.arity - 1)])
    end
  end

  def self.__convert_to_osa__(requested_type, value, enum_group_codes=nil)
    return value if value.is_a?(OSA::Element)
    if conversion = @conversions_to_osa[requested_type]
      args = [value, requested_type]
      conversion.call(*args[0..(conversion.arity - 1)])
    elsif enum_group_codes and enum_group_codes.include?(requested_type)
      if value.is_a?(Array)
        ary = value.map { |x| OSA::Element.__new__('enum', x.code.to_4cc) } 
        ElementList.__new__(ary)
      else
        ['enum', value.code.to_4cc]
      end
    elsif md = /^list_of_(.+)$/.match(requested_type)
      ary = value.to_a.map do |elem| 
        obj = convert_to_osa(md[1], elem, enum_group_codes) 
        obj.is_a?(OSA::Element) ? obj : OSA::Element.__new__(*obj)
      end
      ElementList.__new__(ary)
    else
      STDERR.puts "unrecognized type #{requested_type}" if $VERBOSE
      ['null', nil]
    end
  end

  def self.convert_to_osa(requested_type, value, enum_group_codes=nil)
    ary = __convert_to_osa__(requested_type, value, enum_group_codes)
    if ary == ['null', nil]
      new_type = case value
        when String then 'text'
        when Array then 'list'
        when Hash then 'record'
        when Integer then 'integer'
        when Float then 'double'
      end
      if new_type
        ary = __convert_to_osa__(new_type, value, enum_group_codes)
      end
    end
    ary
  end
  
  def self.set_params(hash)
    previous_values = {}
    hash.each do |key, val|
      unless OSA.respond_to?(key)
        raise ArgumentError, "Invalid key value (no parameter named #{key} was found)"
      end
      ivar_key = '@' + key.to_s
      previous_val = self.instance_variable_get(ivar_key)
      previous_values[ivar_key] = previous_val;
      self.instance_variable_set(ivar_key, hash[key])
    end
    if block_given?
      yield
      previous_values.each { |key, val| self.instance_variable_set(key, val) }
    end
    nil
  end

  #######
  private
  #######

  class DocItem
    attr_reader :name, :description
    def initialize(name, description, optional=false)
      @name = name
      @description = description
      @optional = optional
    end
    def optional?
      @optional
    end
  end

  class DocMethod < DocItem
    attr_reader :result, :args
    def initialize(name, description, result, args)
      super(name, description)
      @result = result
      @args = args
    end
    def inspect
      "<Method #{name} (#{description})>"
    end
  end
 
  def self.__app__(name, target, sdef)
    @apps ||= {}
    app = @apps[target]
    return app if app

    # Creates a module for this app, we will define the scripting interface within it.
    app_module = Module.new
    self.const_set(rubyfy_constant_string(name), app_module)

    @apps[target] = __load_sdef__(sdef, target, app_module)
  end

  def self.__load_sdef__(sdef, target, app_module, merge_only=false, app_class=nil)
    # Load the sdef.
    doc = if USE_LIBXML
      parser = XML::Parser.new
      parser.string = sdef
      parser.parse
    else
      REXML::Document.new(sdef)
    end

    # Retrieves and creates enumerations.
    enum_group_codes = {} 
    doc.find('/dictionary/suite/enumeration').each do |element|
      enum_group_code = element['code']
      enum_module_name = rubyfy_constant_string(element['name'], true)
      enum_module = Module.new
      enum_group_codes[enum_group_code] = enum_module
      
      documentation = [] 
      enum_module.const_set(:DESCRIPTION, documentation)
 
      element.find('enumerator').each do |element|
        name = element['name']
        enum_name = rubyfy_constant_string(name, true)
        enum_code = element['code']
        enum_const = app_module.name + '::' + enum_module_name + '::' + enum_name

        enum = OSA::Enumerator.new(enum_const, name, enum_code, enum_group_code)
        enum_module.const_set(enum_name, enum)

        documentation << DocItem.new(enum_name, englishify_sentence(element['description']))
      end
 
      app_module.const_set(enum_module_name, enum_module) unless app_module.const_defined?(enum_module_name)
    end

    # Retrieves and creates classes.
    classes = {}
    class_elements = {}
    doc.find('/dictionary/suite/class').each do |element|
      key = (element['id'] or element['name'])
      (class_elements[key] ||= []) << element
    end
    class_elements.values.flatten.each do |element| 
      klass = add_class_from_xml_element(element, class_elements, classes, app_module)
      methods_doc = []
      description = englishify_sentence(element['description'])
      if klass.const_defined?(:DESCRIPTION)
        klass.const_set(:DESCRIPTION, description) if klass.const_get(:DESCRIPTION).nil?
      else
        klass.const_set(:DESCRIPTION, description)
      end
      if klass.const_defined?(:METHODS_DESCRIPTION)
        methods_doc = klass.const_get(:METHODS_DESCRIPTION)
      else
        methods_doc = []
        klass.const_set(:METHODS_DESCRIPTION, methods_doc)
      end

      # Creates properties. 
      # Add basic properties that might be missing to the Item class (if any).
      props = {}
      element.find('property').each do |x| 
        props[x['name']] = [x['code'], type_of_parameter(x), x['access'], x['description']]
      end
      if klass.name[-6..-1] == '::Item'
        unless props.has_key?('id')
          props['id'] = ['ID  ', 'integer', 'r', 'the unique ID of the item']
        end
      end
      props.each do |name, pary|
        code, type, access, description = pary
        setter = (access == nil or access.include?('w'))

        if type == 'reference'
          pklass = OSA::Element 
        else
          pklass = classes[type]
          if pklass.nil?
            pklass_elements = class_elements[type]
            unless pklass_elements.nil?
              pklass = add_class_from_xml_element(pklass_elements.first, class_elements, classes, app_module)
            end
          end 
        end

        # Implicit 'get' if the property class is primitive (not defined in the sdef),
        # otherwise just return an object specifier.
        method_name = rubyfy_method(name, klass, type)
        method_proc = if pklass.nil?
          proc do 
            @app.__send_event__('core', 'getd', 
              [['----', Element.__new_object_specifier__('prop', @app == self ? Element.__new__('null', nil) : self, 
              'prop', Element.__new__('type', code.to_4cc))]],
              true).to_rbobj
          end
        else
          proc do  
            o = pklass.__new_object_specifier__('prop', @app == self ? Element.__new__('null', nil) : self, 
                                  'prop', Element.__new__('type', code.to_4cc))
            unless OSA.lazy_events?
              @app.__send_event__('core', 'getd', [['----', o]], true).to_rbobj
            else
              o.instance_variable_set(:@app, @app)
              o.extend(OSA::ObjectSpecifier)
            end
          end
        end

        klass.class_eval { define_method(method_name, method_proc) }
        ptypedoc = if pklass.nil?
          type_doc(type, enum_group_codes, app_module)
        else
          "a #{pklass} object"
        end
        if description
          description[0] = description[0].chr.downcase
          description = '-- ' << description
        end 
        methods_doc << DocMethod.new(method_name, englishify_sentence("Gets the #{name} property #{description}"), DocItem.new('result', englishify_sentence("the property value, as #{ptypedoc}")), nil)

        # For the setter, always send an event.
        if setter
          method_name = rubyfy_method(name, klass, type, true)
          method_proc = proc do |val|
            @app.__send_event__('core', 'setd', 
              [['----', Element.__new_object_specifier__('prop', @app == self ? Element.__new__('null', nil) : self, 
                                     'prop', Element.__new__('type', code.to_4cc))],
               ['data', val.is_a?(OSA::Element) ? val : Element.from_rbobj(type, val, enum_group_codes.keys)]],
              true)
            return nil
          end
          klass.class_eval { define_method(method_name, method_proc) }
          methods_doc << DocMethod.new(method_name, englishify_sentence("Sets the #{name} property #{description}"), nil, [DocItem.new('val', englishify_sentence("the value to be set, as #{ptypedoc}"))])
        end 

        OSA.add_property(name.intern, code)
      end

      # Creates elements.
      element.find('element').each do |eelement|
        type = eelement['type']
        
        eklass = classes[type]
        if eklass.nil?
          eklass_elements = class_elements[type]
          unless eklass_elements.nil?
            eklass = add_class_from_xml_element(eklass_elements.first, class_elements, classes, app_module)
          end
        end 

        if eklass.nil?
          STDERR.puts "Cannot find class '#{type}', skipping element '#{eelement}'" if $DEBUG
          next
        end

        method_name = rubyfy_method(eklass::PLURAL, klass)
        method_proc = proc do
          unless OSA.lazy_events?
            @app.__send_event__('core', 'getd', 
              [['----', Element.__new_object_specifier__(
                eklass::CODE.to_4cc, @app == self ? Element.__new__('null', nil) : self,
                'indx', Element.__new__('abso', 'all '.to_4cc))]],
              true).to_rbobj
          else
            ObjectSpecifierList.new(@app, eklass, @app == self ? Element.__new__('null', nil) : self)
          end
        end
        klass.class_eval { define_method(method_name, method_proc) }
        methods_doc << DocMethod.new(method_name, englishify_sentence("Gets the #{eklass::PLURAL} associated with this object"), DocItem.new('result', englishify_sentence("an Array of #{eklass} objects")), nil)
      end
    end

    unless merge_only
      # Having an 'application' class is required.
      app_class = classes['application']
      raise "No application class defined." if app_class.nil?
      all_classes_but_app = classes.values.reject { |x| x.ancestors.include?(OSA::EventDispatcher) }
    else
      all_classes_but_app = classes.values
    end

    # Maps commands to the right classes.
    doc.find('/dictionary/suite/command').each do |element|
      name = element['name']
      next if /NOT AVAILABLE/.match(name) # Finder's sdef (Tiger) names some commands with this 'tag'.
      description = element['description']
      direct_parameter = element.find_first('direct-parameter')
      result = element.find_first('result')       
      has_result = result != nil
 
      code = element['code']
      begin
        code = Iconv.iconv('MACROMAN', 'UTF-8', code).to_s
      rescue Iconv::IllegalSequence
        # We can't do more...
        STDERR.puts "unrecognized command code encoding '#{code}', skipping..." if $DEBUG
        next
      end

      classes_to_define = []
      forget_direct_parameter = true
      direct_parameter_optional = false

      if direct_parameter.nil?
        # No direct parameter, this is for the application class.
        classes_to_define << app_class
      else
        # We have a direct parameter:
        # - map it to the right class if it's a class defined in our scripting dictionary
        # - map it to all classes if it's a 'reference' and to the application class if it's optional
        # - otherwise, just map it to the application class.
        type = type_of_parameter(direct_parameter)
        direct_parameter_optional = parameter_optional?(direct_parameter)

        if type == 'reference'
          classes_to_define = all_classes_but_app
          classes_to_define << app_class if direct_parameter_optional
        else 
          klass = classes[type]
          if klass.nil?
            forget_direct_parameter = false
            classes_to_define << app_class
          else
            classes_to_define << klass
          end
        end
      end

      # Reject classes which are already represented by an ancestor.
      if classes_to_define.length > 1
        classes_to_define.uniq!
        classes_to_define.reject! do |x|
          classes_to_define.any? { |y| x != y and x.ancestors.include?(y) } 
        end
      end

      params = []
      params_doc = []
      unless direct_parameter.nil?
        pdesc = direct_parameter['description']
        params << [
          'direct',
          '----',
          direct_parameter_optional,
          type_of_parameter(direct_parameter)
        ]
        unless forget_direct_parameter
          params_doc << DocItem.new('direct', englishify_sentence(pdesc))
        end
      end 

      element.find('parameter').to_a.each do |element|
        poptional = parameter_optional?(element) 
        params << [
          rubyfy_string(element['name']),
          element['code'],
          poptional,
          type_of_parameter(element)
        ]
        params_doc << DocItem.new(rubyfy_string(element['name'], true), englishify_sentence(element['description']), poptional) 
      end

      method_proc = proc do |*args_ary|
        args = []
        min_argc = i = 0
        already_has_optional_args = false # Once an argument is optional, all following arguments should be optional.
        optional_hash = nil 
        params.each do |pname, pcode, optional, ptype|
          self_direct = (pcode == '----' and forget_direct_parameter)
          if already_has_optional_args or (optional and !self_direct)
            already_has_optional_args = true
          else
            if args_ary.size < i
              raise ArgumentError, "wrong number of arguments (#{args_ary.size} for #{i})"
            end
          end
          val = if self_direct
            self.is_a?(OSA::EventDispatcher) ? [] : ['----', self]
          else
            arg = args_ary[i]
            min_argc += 1 unless already_has_optional_args
            i += 1
            if arg.is_a?(Hash) and already_has_optional_args and i >= args_ary.size and min_argc + 1 == i
              optional_hash = arg
            end
            if optional_hash
              arg = optional_hash.delete(pname.intern)
            end 
            if arg.nil?
              if already_has_optional_args
                []
              end
            else
              [pcode, arg.is_a?(OSA::Element) ? arg : OSA::Element.from_rbobj(ptype, arg, enum_group_codes.keys)]
            end
          end
          args << val
        end
        if args_ary.size > params.size or args_ary.size < min_argc
          raise ArgumentError, "wrong number of arguments (#{args_ary.size} for #{min_argc})"
        end
        if optional_hash and !optional_hash.empty?
          raise ArgumentError, "inappropriate optional argument(s): #{optional_hash.keys.join(', ')}"
        end
        wait_reply = (OSA.wait_reply != nil ? OSA.wait_reply : (has_result or @app.remote?)) 
        ret = @app.__send_event__(code[0..3], code[4..-1], args, wait_reply)
        wait_reply ? ret.to_rbobj : ret
      end

      unless has_result
        result_type = result_doc = nil
      else
        result_type = type_of_parameter(result)
        result_klass = classes[result_type]
        result_doc = DocItem.new('result', englishify_sentence(result['description']))
      end

      classes_to_define.each do |klass|
        method_name = rubyfy_method(name, klass, result_type)
        klass.class_eval { define_method(method_name, method_proc) }
        methods_doc = klass.const_get(:METHODS_DESCRIPTION)
        methods_doc << DocMethod.new(method_name, englishify_sentence(description), result_doc, params_doc)
      end
      
      # Merge some additional commands, if necessary.
      unless app_class.method_defined?(:activate)
        app_class.class_eval do
          define_method(:activate) do 
            __send_event__('misc', 'actv', [], true)
            nil
          end
        end
        methods_doc = app_class.const_get(:METHODS_DESCRIPTION)
        methods_doc << DocMethod.new('activate', 'Activate the application.', nil, []) 
      end
    end

    unless merge_only
      # Returns an application instance, that's all folks!
      hash = {}
      classes.each_value { |klass| hash[klass::CODE] = klass } 
      app_class.class_eval do 
        attr_reader :sdef, :classes
        define_method(:remote?) { @is_remote == true }
      end
      is_remote = target.length > 4
      app = is_remote ? app_class.__new__('aprl', target) : app_class.__new__('sign', target.to_4cc)
      app.instance_variable_set(:@is_remote, is_remote)
      app.instance_variable_set(:@sdef, sdef)
      app.instance_variable_set(:@classes, hash)
      app.extend OSA::EventDispatcher
    end
  end

  def self.parameter_optional?(element)
    element['optional'] == 'yes'
  end

  def self.add_class_from_xml_element(element, class_elements, repository, app_module)
    real_name = element['name']
    key = (element['id'] or real_name)
    klass = repository[key]
    if klass.nil?
      code = element['code']
      inherits = element['inherits']
      plural = element['plural']
   
      if real_name == inherits
        # Inheriting from itself is a common idiom when adding methods 
        # to a class that has already been defined, probably to avoid
        # mentioning the subclass name more than once.
        inherits = nil
      end

      if inherits.nil?
        klass = Class.new(OSA::Element)
      else
        super_elements = class_elements[inherits]
        super_class = if super_elements.nil?
          STDERR.puts "sdef bug: class '#{real_name}' inherits from '#{inherits}' which is not defined - fall back inheriting from OSA::Element" if $DEBUG
          OSA::Element
        else
          add_class_from_xml_element(super_elements.first, class_elements, repository, app_module)
        end
        klass = Class.new(super_class)
      end

      klass.class_eval { include OSA::EventDispatcher } if real_name == 'application'

      klass.const_set(:REAL_NAME, real_name) unless klass.const_defined?(:REAL_NAME)
      klass.const_set(:PLURAL, plural == nil ? real_name + 's' : plural) unless klass.const_defined?(:PLURAL)
      klass.const_set(:CODE, code) unless klass.const_defined?(:CODE)
      
      app_module.const_set(rubyfy_constant_string(real_name), klass)

      repository[key] = klass
    end 

    return klass
  end
  
  def self.type_doc(type, enum_group_codes, app_module)
    if mod = enum_group_codes[type]
      mod.to_s 
    elsif md = /^list_of_(.+)$/.match(type)
      "list of #{type_doc(md[1], enum_group_codes, app_module)}"
    else
      up_type = type.upcase
      begin
        app_module.const_get(up_type).to_s
      rescue 
        type
      end
    end
  end

  def self.type_of_parameter(element)
    type = element['type']
    if type.nil?
      etype = element.find_first('type')
      if etype
        type = etype['type']
        if type.nil? and (etype2 = etype.find_first('type')) != nil
          type = etype2['type']
        end
        type = "list_of_#{type}" if etype['list'] == 'yes'
      end
    end
    raise "Parameter #{element} has no type." if type.nil?
    return type
  end

  def self.escape_string(string)
    string.gsub(/[\$\=\s\-\.\/]/, '_').gsub(/&/, 'and')
  end

  def self.rubyfy_constant_string(string, upcase=false)
    string = string.gsub(/[^\w\s]/, '')
    first = string[0]
    if (?a..?z).include?(first)
      string[0] = first.chr.upcase
    elsif !(?A..?Z).include?(first)
      string.insert(0, 'C')
    end
    escape_string(upcase ? string.upcase : string.gsub(/\s(.)/) { |s| s[1].chr.upcase })
  end

  RUBY_RESERVED_KEYWORDS = ['for', 'in', 'class']
  def self.rubyfy_string(string, handle_ruby_reserved_keywords=false)
    # Prefix with '_' parameter names to avoid possible collisions with reserved Ruby keywords (for, etc...).
    if handle_ruby_reserved_keywords and RUBY_RESERVED_KEYWORDS.include?(string)
      '_' + string
    else
      escape_string(string).downcase
    end
  end
  
  def self.rubyfy_method(string, klass, return_type=nil, setter=false)
    base = rubyfy_string(string)
    s, i = base.dup, 1
    loop do
      if setter
        # Suffix setters with '='.
        s << '='
      elsif return_type == 'boolean'
        # Suffix predicates with '?'. 
        s << '?'
      end
      break unless klass.method_defined?(s)
      # Suffix with an integer if the class already has a method with such a name.
      i += 1
      s = base + i.to_s
    end
    return s
  end

  def self.englishify_sentence(string)
    return '' if string.nil? or string.empty?
    string[0] = string[0].chr.upcase
    string.strip!
    last = string[-1].chr
    string << '.' if last != '.' and last != '?' and last != '!'
    return string
  end
end

# String, for unicode stuff force utf8 type if specified.
OSA.add_conversion_to_ruby('TEXT') { |value, type, object| object.__data__('TEXT') }
OSA.add_conversion_to_ruby('utxt', 'utf8') { |value, type, object| object.__data__(OSA.utf8_strings ? 'utf8' : 'TEXT') }
OSA.add_conversion_to_osa('string', 'text') { |value| ['TEXT', value.to_s] }
OSA.add_conversion_to_osa('Unicode text') { |value| [OSA.utf8_strings ? 'utf8' : 'TEXT', value.to_s] }

# Signed/unsigned integer. 
OSA.add_conversion_to_ruby('shor', 'long') { |value| value.unpack('l').first }
OSA.add_conversion_to_ruby('comp') { |value| value.unpack('q').first }
OSA.add_conversion_to_osa('integer', 'double integer') { |value| ['magn', [value].pack('l')] }

# Float
OSA.add_conversion_to_ruby('sing') { |value| value.unpack('f').first }
OSA.add_conversion_to_ruby('magn', 'doub') { |value| value.unpack('d').first }
OSA.add_conversion_to_osa('double') { |value| ['doub', [value].pack('d')] }

# Boolean.
OSA.add_conversion_to_ruby('bool') { |value| value.unpack('c').first != 0 }
OSA.add_conversion_to_osa('boolean') { |value| [(value ? 'true'.to_4cc : 'fals'.to_4cc), nil] }
OSA.add_conversion_to_ruby('true') { |value| true }
OSA.add_conversion_to_ruby('fals') { |value| false }

# Date.
OSA.add_conversion_to_ruby('ldt ') { |value| 
  Date.new(1904, 1, 1) + Date.time_to_day_fraction(0, 0, value.unpack('q').first)
}

# Array.
OSA.add_conversion_to_osa('list') do |value|
  # The `list_of_XXX' types are not handled here.
  if value.is_a?(Array)
    elements = value.map { |x| OSA::Element.from_rbobj(nil, x, nil) }
    OSA::ElementList.__new__(elements)
  else
    value
  end
end
OSA.add_conversion_to_ruby('list') { |value, type, object| 
  object.is_a?(OSA::ElementList) ? object.to_a.map { |x| x.to_rbobj } : object
}

# File name.
# Let's use the 'furl' type here instead of 'alis', as we don't have a way to produce an alias for a file that does not exist yet.
OSA.add_conversion_to_osa('alias', 'file') { |value| ['furl', value.to_s] }
OSA.add_conversion_to_ruby('alis') do |value, type, object| 
  URI.unescape(URI.parse(object.__data__('furl')).path)
end 

# Hash.
OSA.add_conversion_to_ruby('reco') { |value, type, object| object.is_a?(OSA::ElementRecord) ? object.to_hash : value }
OSA.add_conversion_to_osa('record') do |value| 
  if value.is_a?(Hash)
    OSA::ElementRecord.from_hash(value)
  else
    value 
  end 
end

# Enumerator.
OSA.add_conversion_to_ruby('enum') { |value, type, object| OSA::Enumerator.enum_for_code(object.__data__('TEXT')) or object }

# Class.
OSA.add_conversion_to_osa('type class', 'type') { |value| value.is_a?(Class) and value.ancestors.include?(OSA::Element) ? ['type', value::CODE.to_4cc] : value } 
OSA.add_conversion_to_ruby('type') do |value, type, object| 
  if value == 'msng' 
    # Missing values.
    value 
  else
    hash = object.instance_variable_get(:@app).instance_variable_get(:@classes)
    hash[value] or value
  end
end

# QuickDraw Rectangle, aka "bounding rectangle".
OSA.add_conversion_to_ruby('qdrt') { |value| value.unpack('S4') }
OSA.add_conversion_to_osa('bounding rectangle') { |value| ['qdrt', value.pack('S4')] }

# Pictures (just return the raw data).
OSA.add_conversion_to_ruby('PICT') { |value, type, object| value[222..-1] } # Removing trailing garbage.
OSA.add_conversion_to_osa('picture') { |value| ['PICT', value.to_s] }
OSA.add_conversion_to_ruby('imaA') { |value, type, object| value }
OSA.add_conversion_to_ruby('TIFF') { |value, type, object| value }
OSA.add_conversion_to_osa('Image') { |value| ['imaA', value.to_s] }
OSA.add_conversion_to_osa('TIFF picture') { |value| ['TIFF', value.to_s] }

# RGB color.
OSA.add_conversion_to_ruby('cRGB') { |value| value.unpack('S3') }
OSA.add_conversion_to_osa('color') do |values| 
  ary = values.map { |i| OSA::Element.__new__('long', [i].pack('l')) }
  OSA::ElementList.__new__(ary)
end

require 'rbosa_properties'
