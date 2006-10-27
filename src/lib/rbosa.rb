# Copyright (c) 2006, Apple Computer, Inc. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1.  Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer. 
# 2.  Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution. 
# 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
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

require 'osa'
require 'date'

# Try to load RubyGems first, libxml-ruby may have been installed by it.
begin require 'rubygems' rescue LoadError end

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
        OSA.__four_char_code__(self)
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
        val == nil ? self : val
      end
    end
    
    def self.from_rbobj(requested_type, value, enum_group_codes)
      self.__new__(*OSA.convert_to_osa(requested_type, value, enum_group_codes))
    end
end

class OSA::ElementList
    include Enumerable
    def each
        self.size.times { |i| yield(self[i]) }
    end
end

class OSA::ElementRecord
    def to_hash
        h = {}
        self.to_a.each { |key, val| h[key] = val.to_rbobj }
        return h
    end
end

module OSA::ObjectSpecifier
    def get
        @app.__send_event__('core', 'getd', [['----', self]], true).to_rbobj
    end
end

class OSA::ObjectSpecifierList
    include Enumerable
    
    def initialize(app, desired_class, container)
        @app, @desired_class, @container = app, desired_class, container
    end
   
    def length
        @length ||= @app.__send_event__(
            'core', 'cnte', 
            [['----', @container], ['kocl', OSA::Element.__new__('type', @desired_class::CODE.to_4cc)]], 
            true).to_rbobj
    end
    alias_method :size, :length

    def [](idx)
        idx += 1 # AE starts counting at 1.
        o = obj_spec_with_key(OSA::Element.__new__('long', [idx].pack('l')))
        o.instance_variable_set(:@app, @app)
        o.extend OSA::ObjectSpecifier
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

    #######
    private
    #######

    def obj_spec_with_key(element)
        @desired_class.__new_object_specifier__(@desired_class::CODE, @container,
                                                'indx', element)
    end
end

module OSA
    def self.app_with_name(name)
        self.__app__(*OSA.__scripting_info__(:by_name, name))
    end

    def self.app_with_path(path)
        self.__app__(*OSA.__scripting_info__(:by_path, path))
    end

    def self.app_with_bundle_id(bundle_id)
        self.__app__(*OSA.__scripting_info__(:by_bundle_id, bundle_id))
    end

    def self.app_with_signature(signature)
        self.__app__(*OSA.__scripting_info__(:by_signature, signature))
    end

    def self.app(name)
        self.app_with_name(name)
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
        osa_type = osa_object.__type__.to_s
        osa_data = osa_object.__data__(osa_type) if osa_type and osa_type != 'null'
        if conversion = @conversions_to_ruby[osa_type]
            args = [osa_data, osa_type, osa_object]
            conversion.call(*args[0..(conversion.arity - 1)])
        end
    end

    def self.convert_to_osa(requested_type, value, enum_group_codes=nil)
        if conversion = @conversions_to_osa[requested_type]
            args = [value, requested_type]
            conversion.call(*args[0..(conversion.arity - 1)])
        elsif enum_group_codes and enum_group_codes.include?(requested_type)
            ['enum', value.code.to_4cc]
        else     
            STDERR.puts "unrecognized type #{requested_type}" if $VERBOSE
            ['null', nil]
        end
    end
    
    def self.set_params(hash)
        previous_values = {}
        hash.each do |key, val|
            ivar_key = '@' + key.to_s
            previous_val = self.instance_variable_get(ivar_key)
            if previous_val.nil?
                raise ArgumentError, "Invalid key value (no parameter named #{key} was found)"
            end
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
        def initialize(name, description)
            @name = name
            @description = description
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
 
    def self.__app__(name, signature, sdef)
        @apps ||= {}
        app = @apps[signature]
        return app if app
        doc = if USE_LIBXML
            parser = XML::Parser.new
            parser.string = sdef
            parser.parse
        else
            REXML::Document.new(sdef)
        end

        # Creates a module for this app, we will define the scripting interface within it.
        app_module = Module.new
        self.const_set(rubyfy_constant_string(name), app_module)

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
 
            app_module.const_set(enum_module_name, enum_module)
        end

        # Retrieves and creates classes.
        classes = {}
        class_elements = {}
        doc.find('/dictionary/suite/class').each do |element|
            (class_elements[element['name']] ||= []) << element
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
            element.find('property').each do |pelement|
                name = pelement['name']
                code = pelement['code']
                type = pelement['type']
                access = pelement['access']
                description = pelement['description']
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
                method_code = if pklass.nil?
                    <<EOC
def #{method_name}
    @app.__send_event__('core', 'getd', 
        [['----', Element.__new_object_specifier__('prop', @app == self ? Element.__new__('null', nil) : self, 
                                                   'prop', Element.__new__('type', '#{code}'.to_4cc))]],
        true).to_rbobj
end
EOC
                else
                    <<EOC
def #{method_name}
    o = #{pklass.name}.__new_object_specifier__('prop', @app == self ? Element.__new__('null', nil) : self, 
                                                'prop', Element.__new__('type', '#{code}'.to_4cc))
    unless OSA.lazy_events?
        @app.__send_event__('core', 'getd', [['----', o]], true).to_rbobj
    else
        o.instance_variable_set(:@app, @app)
        o.extend(OSA::ObjectSpecifier)
    end
end
EOC
                end
 
                klass.class_eval(method_code)
                ptypedoc = if pklass.nil?
                    if mod = enum_group_codes[type]
                        "a #{mod} enumeration"
                    else
                        type
                    end
                else
                    "a #{pklass} object"
                end
                description[0] = description[0].chr.downcase if description
                methods_doc << DocMethod.new(method_name, englishify_sentence("Gets the #{name} property -- #{description}"), DocItem.new('result', englishify_sentence("the property value, as #{ptypedoc}")), nil)

                # For the setter, always send an event.
                if setter
                    method_name = rubyfy_method(name, klass, type, true)
                    method_code = <<EOC
def #{method_name}(val)
    @app.__send_event__('core', 'setd', 
        [['----', Element.__new_object_specifier__('prop', @app == self ? Element.__new__('null', nil) : self, 
                                                   'prop', Element.__new__('type', '#{code}'.to_4cc))],
         ['data', #{new_element_code(type, 'val', enum_group_codes)}]],
        true)
    return nil
end
EOC

                    klass.class_eval(method_code)
                    methods_doc << DocMethod.new(method_name, englishify_sentence("Sets the #{name} property -- #{description}"), nil, [DocItem.new('val', englishify_sentence("the value to be set, as #{ptypedoc}"))])
                end 
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
                method_code = <<EOC
def #{method_name}
    unless OSA.lazy_events?
        @app.__send_event__('core', 'getd', 
            [['----', Element.__new_object_specifier__(
                '#{eklass::CODE}', @app == self ? Element.__new__('null', nil) : self,
                'indx', Element.__new__('abso', 'all '.to_4cc))]],
            true).to_rbobj
    else
        ObjectSpecifierList.new(@app, #{eklass}, @app == self ? Element.__new__('null', nil) : self)
    end
end
EOC

                klass.class_eval(method_code)
                methods_doc << DocMethod.new(method_name, englishify_sentence("Gets the #{eklass::PLURAL} associated with this object"), DocItem.new('result', englishify_sentence("an Array of #{eklass} objects")), nil)
            end
        end

        # Having an 'application' class is required.
        app_class = classes['application']
        raise "No application class defined." if app_class.nil?

        # Maps commands to the right classes.
        all_classes_but_app = classes.values.reject { |x| x.ancestors.include?(OSA::EventDispatcher) }
        doc.find('/dictionary/suite/command').each do |element|
            name = element['name']
            next if /NOT AVAILABLE/.match(name) # Finder's sdef (Tiger) names some commands with this 'tag'.
            description = element['description']
            code = element['code']
            direct_parameter = element.find_first('direct-parameter')
            result = element.find_first('result')           
 
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
            unless direct_parameter.nil?
                params << ['direct', 
                           '----',
                           direct_parameter['description'], 
                           direct_parameter_optional,
                           type_of_parameter(direct_parameter)]
            end 

            params.concat(element.find('parameter').to_a.map do |element|
                [rubyfy_string(element['name'], true),
                 element['code'],
                 element['description'],
                 parameter_optional?(element),
                 type_of_parameter(element)]
            end)
 
            p_dec, p_def, p_args_doc = [], [], []
            already_has_optional_args = false # Once an argument is optional, all following arguments should be optional.
            params.each do |pname, pcode, pdesc, optional, ptype|
                decl = pname
                self_direct = (pcode == '----' and forget_direct_parameter)
                defi = if self_direct
                    forget_direct_parameter ? "(self.is_a?(OSA::EventDispatcher) ? [] : ['----', self])" : "['----', self]"
                else
                    "['#{pcode}', #{new_element_code(ptype, pname, enum_group_codes)}]"
                end
                if already_has_optional_args or (optional and !self_direct)
                    decl += '=nil'
                    defi = "(#{pname} == nil ? [] : #{defi})"
                    already_has_optional_args = true
                end 
                unless self_direct
                    p_dec << decl 
                    p_args_doc << DocItem.new(decl, englishify_sentence(pdesc)) 
                end
                p_def << defi
            end

            method_code = <<EOC
def %METHOD_NAME%(#{p_dec.join(', ')})
  @app.__send_event__('#{code[0..3]}', '#{code[4..-1]}', [#{p_def.join(', ')}], #{result != nil})#{result != nil ? '.to_rbobj' : ''}
end
EOC

            if result.nil?
                result_type = result_doc = nil
            else
                result_type = type_of_parameter(result)
                result_klass = classes[result_type]
                result_doc = DocItem.new('result', englishify_sentence(result['description']))
            end

            classes_to_define.each do |klass|
                method_name = rubyfy_method(name, klass, result_type)
                code = method_code.sub(/%METHOD_NAME%/, method_name)
                klass.class_eval(code)
                methods_doc = klass.const_get(:METHODS_DESCRIPTION)
                methods_doc << DocMethod.new(method_name, englishify_sentence(description), result_doc, p_args_doc)
            end
        end

        # Returns an application instance, that's all folks!
        hash = {}
        classes.each_value { |klass| hash[klass::CODE] = klass } 
        app = app_class.__new__('sign', signature.to_4cc)
        app.instance_variable_set(:@sdef, sdef)
        app.instance_variable_set(:@classes, hash)
        app.instance_eval 'def sdef; @sdef; end'
        app.extend OSA::EventDispatcher
        @apps[signature] = app
    end

    def self.parameter_optional?(element)
        element['optional'] == 'yes'
    end

    def self.add_class_from_xml_element(element, class_elements, repository, app_module)
        real_name = element['name']
        klass = repository[real_name]
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
                if super_elements.nil?
                    STDERR.puts "sdef bug: class '#{real_name}' inherits from '#{inherits}' which is not defined - fall back inheriting from OSA::Element" if $DEBUG
                    klass = OSA::Element
                else
                    super_class = add_class_from_xml_element(super_elements.first, class_elements, 
                                                             repository, app_module)
                    klass = Class.new(super_class)
                end
            end

            klass.class_eval 'include OSA::EventDispatcher' if real_name == 'application'

            klass.const_set(:REAL_NAME, real_name) unless klass.const_defined?(:REAL_NAME)
            klass.const_set(:PLURAL, plural == nil ? real_name + 's' : plural) unless klass.const_defined?(:PLURAL)
            klass.const_set(:CODE, code) unless klass.const_defined?(:CODE)
            
            app_module.const_set(rubyfy_constant_string(real_name), klass)

            repository[real_name] = klass
        end 

        return klass
    end
    
    def self.type_of_parameter(element)
        type = element['type']
        if type.nil?
            etype = element.find_first('type')
            if etype.nil? or (type = etype['type']).nil?
                raise "Parameter #{element} has no type."
            end
            type = "list_of_#{type}" if etype['list'] == 'yes'
        end
        return type
    end

    def self.new_element_code(type, varname, enum_group_codes)
        if md = /^list_of_(.+)$/.match(type)
            return "#{varname}.is_a?(OSA::Element) ? #{varname} : ElementList.__new__(#{varname}.to_a.map { |x| #{new_element_code(md[1], 'x', enum_group_codes)} })"
        end
        "#{varname}.is_a?(OSA::Element) ? #{varname} : Element.from_rbobj('#{type}', #{varname}, #{enum_group_codes.keys.inspect})" 
    end

    def self.escape_string(string)
        string.gsub(/[\s\-\.\/]/, '_').gsub(/&/, 'and')
    end

    def self.rubyfy_constant_string(string, upcase=false)
        if /^\d/.match(string)
            string = 'C' << string 
        else
            string = string.dup
            string[0] = string[0].chr.upcase
        end
        escape_string(upcase ? string.upcase : string.gsub(/\s(.)/) { |s| s[1].chr.upcase })
    end

    RUBY_RESERVED_KEYWORDS = ['for', 'in']
    def self.rubyfy_string(string, handle_ruby_reserved_keywords=false)
        # Prefix with '_' parameter names to avoid possible collisions with reserved Ruby keywords (for, etc...).
        if RUBY_RESERVED_KEYWORDS.include?(string)
            '_' + string
        else
            escape_string(string).downcase
        end
    end
    
    def self.rubyfy_method(string, klass, return_type=nil, setter=false)
        s = rubyfy_string(string) 
        if setter
            # Suffix setters with '='.
            s << '='
        elsif return_type == 'boolean'
            # Suffix predicates with '?'. 
            s << '?'
        end
        # Prefix with 'osa_' in case the class already has a method with such a name.
        if klass.method_defined?(s)
            s = 'osa_' + s
        end
        return s
    end

    def self.englishify_sentence(string)
        return '' if string.nil?
        string[0] = string[0].chr.upcase
        last = string[-1].chr
        string << '.' if last != '.' and last != '?' and last != '!'
        return string
    end
end

# String, force TEXT type to not get Unicode.
OSA.add_conversion_to_ruby('TEXT', 'utxt') { |value, type, object| object.__data__('TEXT') }
OSA.add_conversion_to_osa('string', 'text', 'Unicode text') { |value| ['TEXT', value.to_s] }

# Signed/unsigned integer. 
OSA.add_conversion_to_ruby('shor', 'long', 'comp') { |value| value.unpack('l').first }
OSA.add_conversion_to_ruby('magn') { |value| value.unpack('d').first }
OSA.add_conversion_to_osa('integer', 'double integer') { |value| ['magn', [value].pack('l')] }

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
OSA.add_conversion_to_ruby('list') { |value, type, object| 
  object.is_a?(OSA::ElementList) ? object.to_a.map { |x| x.to_rbobj } : object
}

# File name.
# Let's use the 'furl' type here instead of 'alis', as we don't have a way to produce an alias for a file that does not exist yet.
OSA.add_conversion_to_osa('alias', 'file') { |value| ['furl', value.to_s] }

# Hash.
OSA.add_conversion_to_ruby('reco') { |value, type, object| object.is_a?(OSA::ElementRecord) ? object.to_hash : self }

# Enumerator.
OSA.add_conversion_to_ruby('enum') { |value, type, object| OSA::Enumerator.enum_for_code(object.__data__('TEXT')) or self }

# Class.
OSA.add_conversion_to_osa('type class') { |value| value.is_a?(Class) and value.ancestors.include?(OSA::Element) ? ['type', value::CODE.to_4cc] : self } 

# QuickDraw Rectangle, aka "bounding rectangle".
OSA.add_conversion_to_ruby('qdrt') { |value| value.unpack('S4') }
OSA.add_conversion_to_osa('bounding rectangle') { |value| ['qdrt', value.pack('S4')] }
