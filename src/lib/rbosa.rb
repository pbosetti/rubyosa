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
require 'rexml/document'
require 'date'

class String
    def to_4cc
        OSA.__four_char_code__(self)
    end
end

class OSA::Application
    attr_reader :sdef

    def self.new(sdef, signature, classes)
        app = self.__new__('sign', signature.to_4cc)
        app.instance_variable_set(:@sdef, sdef)
        app.instance_variable_set(:@classes, classes)
        return app
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
        type = __type__
        case type
            # Null.
            when 'null'
                nil
            # String.
            when 'TEXT', 'utxt'
                # Force TEXT type to not get Unicode.
                __data__('TEXT')
            # Signed integer. 
            when 'shor', 'long', 'comp'
                __data__(type).unpack('l').first
            # Unsigned integer.
            when 'magn'
                __data__(type).unpack('d').first
            # Boolean.
            when 'bool'
                __data__('bool').unpack('c').first != 0
            when 'true'
                true
            when 'fals'
                false
            # Date.
            when 'ldt '
     	   	    Date.new(1904, 1, 1) + Date.time_to_day_fraction(0, 0, __data__(type).unpack('q').first)
            # Array.
            when 'list'
                is_a?(OSA::ElementList) ? to_a.map { |x| x.to_rbobj } : self
            # Enumerator.
            when 'enum'
                OSA::Enumerator.enum_for_code(__data__('TEXT')) or self
            # Unrecognized type, return self.
            else
                self 
        end
    end
end

class OSA::ElementList
    include Enumerable
    def each
        self.size.times { |i| yield(self[i]) }
    end
end

module OSA
    def self.app_with_name(name)
        self.app(*OSA.__scripting_info__(:by_name, name))
    end

    def self.app_with_path(path)
        self.app(*OSA.__scripting_info__(:by_path, path))
    end

    def self.app_with_bundle_id(bundle_id)
        self.app(*OSA.__scripting_info__(:by_bundle_id, bundle_id))
    end

    def self.app_with_signature(signature)
        self.app(*OSA.__scripting_info__(:by_signature, signature))
    end

    #######
    private
    #######

    def self.app(name, signature, sdef)
        doc = REXML::Document.new(sdef)

        # Creates a module for this app, we will define the scripting interface within it.
        app_module = Module.new
        self.module_eval <<-EOC
            #{rubyfy_constant_string(name)} = app_module
        EOC

        # Retrieves and creates enumerations.
        enum_group_codes = []
        doc.elements.each('/dictionary/suite/enumeration') do |element|
            enum_group_code = element.attributes['code']
            enum_group_codes << enum_group_code
            enum_module_name = rubyfy_constant_string(element.attributes['name']).upcase
            enum_module = Module.new
            
            element.elements.each('enumerator') do |element|
                name = element.attributes['name']
                enum_name = rubyfy_constant_string(name).upcase
                enum_code = element.attributes['code']
                enum_const = app_module.name + '::' + enum_module_name + '::' + enum_name

                enum = OSA::Enumerator.new(enum_const, name, enum_code, enum_group_code)

                enum_module.module_eval <<-EOC
                    #{enum_name} = enum    
                EOC
            end
 
            app_module.module_eval <<-EOC 
                #{enum_module_name} = enum_module
            EOC
        end

        # Retrieves and creates classes.
        classes = {}
        class_elements = {}
        doc.elements.each('/dictionary/suite/class') do |element|
            class_elements[element.attributes['name']] = element
        end
        class_elements.each_value do |element| 
            klass = add_class_from_xml_element(element, class_elements, classes, app_module)
            is_app = klass.ancestors.include?(OSA::Application)
            
            # Creates properties. 
            element.elements.each('property') do |pelement|
                name = pelement.attributes['name']
                code = pelement.attributes['code']
                type = pelement.attributes['type']
                access = pelement.attributes['access']
                setter = access == nil or access == 'w'

                pklass = classes[type]
                if pklass.nil?
                    pklass_element = class_elements[type]
                    unless pklass_element.nil?
                        pklass = add_class_from_xml_element(pklass_element, class_elements, classes, app_module)
                    end
                end 

                method_code = <<EOC
def #{rubyfy_method(name, type)}
    #{is_app ? "self" : "@app"}.__send_event__('core', 'getd', 
        [['----', Element.__new_object_specifier__('prop', #{is_app ? "Element.__new__('null', nil)" : "self"}, 
                                                   'prop', Element.__new__('type', '#{code}'.to_4cc))]],
        true).to_rbobj
end
EOC

                klass.class_eval(method_code)

                if setter
                    method_code = <<EOC
def #{rubyfy_method(name, type, true)}=(val)
    #{is_app ? "self" : "@app"}.__send_event__('core', 'setd', 
        [['----', Element.__new_object_specifier__('prop', #{is_app ? "Element.__new__('null', nil)" : "self"}, 
                                                   'prop', Element.__new__('type', '#{code}'.to_4cc))],
         ['data', #{new_element_code(type, 'val', enum_group_codes)}]],
        true).to_rbobj
end
EOC

puts method_code if name == 'status message'

                    klass.class_eval(method_code)
                end 
            end

            # Creates elements.
            element.elements.each('element') do |eelement|
                type = eelement.attributes['type']
                
                eklass = classes[type]
                if eklass.nil?
                    eklass_element = class_elements[type]
                    unless eklass_element.nil?
                        eklass = add_class_from_xml_element(eklass_element, class_elements, classes, app_module)
                    end
                end 

                if eklass.nil?
                    STDERR.puts "Cannot find class '#{type}', skipping element '#{eelement}'" if $VERBOSE
                    next
                end

                method_code = <<EOC
def #{rubyfy_method(eklass::PLURAL)}
    #{is_app ? "self" : "@app"}.__send_event__('core', 'getd', 
        [['----', Element.__new_object_specifier__('#{eklass::CODE}', #{is_app ? "Element.__new__('null', nil)" : "self"}, 
                                                   'indx', Element.__new__('abso', 'all '.to_4cc))]],
        true).to_rbobj
end
EOC

                klass.class_eval(method_code)
            end
        end

        # Having an 'application' class is required.
        app_class = classes['application']
        raise "No application class defined." if app_class.nil?

        # Maps commands to the right classes.
        all_classes_but_app = classes.values.reject { |x| x.ancestors.include?(OSA::Application) }
        doc.elements.each('/dictionary/suite/command') do |element|
            name = element.attributes['name']
            code = element.attributes['code']
            direct_parameter = element.elements['direct-parameter']
            result = element.elements['result']           
 
            classes_to_define = []
            forget_direct_parameter = true

            if direct_parameter.nil?
                # No direct parameter, this is for the application class.
                classes_to_define << app_class
            else
                # We have a direct parameter, map it to the right class if it's a class
                # defined in our scripting dictionary, map it to all classes if it's a reference,
                # otherwise map it to the application class.
                type = type_of_parameter(direct_parameter)

                if type == 'reference'
                    classes_to_define = all_classes_but_app
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

            method_name = rubyfy_method(name, (result != nil ? type_of_parameter(result) : nil))
 
            params = []
            unless direct_parameter.nil?
                params << ['direct', '----', false, type_of_parameter(direct_parameter)]
            end 
            element.elements.each('parameter') do |element|
                opt = element.attributes['optional']
                # Prefix with '_' parameter names to avoid possible collisions with reserved Ruby keywords (for, etc...).
                params << ['_' + rubyfy_string(element.attributes['name']),
                           element.attributes['code'],
                           (opt == nil ? false : opt == 'yes'),
                           type_of_parameter(element)]
            end

            p_dec, p_def = [], []
            params.each do |pname, pcode, optional, ptype|
                decl = pname
                self_direct = (pcode == '----' and forget_direct_parameter)
                defi = if self_direct
                    "['----', self]"
                else
                    "['#{pcode}', #{new_element_code(ptype, pname, enum_group_codes)}]"
                end
                if optional
                    decl += '=nil'
                    defi = "(#{pname} == nil ? [] : #{defi})"
                end 
                p_dec << decl
                p_def << defi
            end

            method_code = <<EOC
def #{method_name}(#{p_dec.join(', ')})
  %RECEIVER%.__send_event__('#{code[0..3]}', '#{code[4..-1]}', [#{p_def.join(', ')}], #{result != nil})#{result != nil ? '.to_rbobj' : ''}
end
EOC

            classes_to_define.each do |klass| 
                code = method_code.sub(/%RECEIVER%/, klass.ancestors.include?(OSA::Application) ? 'self' : '@app')
                klass.class_eval(code)
            end
        end

        # Returns an application instance, that's all folks!
        hash = {}
        classes.each_value { |klass| hash[klass::CODE] = klass } 
        app_class.new(sdef, signature, hash)
    end

    def self.add_class_from_xml_element(element, class_elements, repository, app_module)
        real_name = element.attributes['name']
        klass = repository[real_name]
        if klass.nil?
            code = element.attributes['code']
            inherits = element.attributes['inherits']
            plural = element.attributes['plural']
    
            if real_name == inherits
                # Inheriting from itself is a common idiom when adding methods 
                # to a class that has already been defined, probably to avoid
                # mentioning the subclass name more than once.
                inherits = nil
            end

            if inherits.nil?
                klass = Class.new(real_name == 'application' ? OSA::Application : OSA::Element)
            else
                super_element = class_elements[inherits]
                if super_element.nil?
                    STDERR.puts "sdef bug: class #{real_name} inherits from #{inherits} which is not defined - fall back inheriting from OSA::Element"
                    klass = OSA::Element
                else
                    super_class = add_class_from_xml_element(super_element, class_elements, 
                                                             repository, app_module)
                    klass = Class.new(super_class)
                end
            end
            
            klass.class_eval <<-EOC 
                REAL_NAME = '#{real_name}' unless const_defined?(:REAL_NAME)
                PLURAL = '#{plural == nil ? real_name + 's' : plural}' unless const_defined?(:PLURAL)
                CODE = '#{code}' unless const_defined?(:CODE)
            EOC

            app_module.module_eval <<-EOC 
                #{rubyfy_constant_string(real_name)} = klass
            EOC

            repository[real_name] = klass
        end 

        return klass
    end
    
    def self.type_of_parameter(element)
        type = element.attributes['type']
        if type.nil?
            type = element.elements['type']
            if type.nil? or (type = type.attributes['type']).nil?
                raise "Parameter #{element} has no type."
            end
        end
        return type
    end

    def self.new_element_code(type, varname, enum_group_codes)
        code = "#{varname}.is_a?(OSA::Element) ? #{varname} : Element.__new__("
        code << case type
            when 'boolean'
                "(#{varname} ? 'true'.to_4cc : 'fals'.to_4cc), nil"
            when 'string', 'text', 'Unicode text'
                "'TEXT', #{varname}.to_s"
            when 'alias'
                "'alis', #{varname}.to_s"    
            when 'integer', 'double integer'
                "'magn', [#{varname}].pack('l')"
            else
                if enum_group_codes.include?(type)
                    "'enum', #{varname}.code.to_4cc"
                else     
                    STDERR.puts "unrecognized type #{type}" if $VERBOSE
                    "'null', nil"
                end
        end
        code << ')'
        return code
    end

    def self.rubyfy_constant_string(string)
        string = 'C' << string if /^\d/.match(string)
        rubyfy_string(string).capitalize.gsub(/\s(.)/) { |s| s[1].chr.upcase }
    end

    def self.rubyfy_string(string)
        string.gsub(/\s/, '_')
    end
    
    def self.rubyfy_method(string, return_type=nil, setter=false)
        s = rubyfy_string(string) 
        # Suffix predicates with '?'. 
        if return_type == 'boolean' and !setter
            s << '?'
        end
        return s
    end
end

