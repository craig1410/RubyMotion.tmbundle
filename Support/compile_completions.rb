##!/usr/bin/env ruby -wKU

require 'rexml/document'
require 'pp'
require File.dirname(__FILE__) + "/rexml/sorting"
# require 'pry'

class RubyMotionCompletion
  def initialize
    raise unless File.exists? latest_version_path
  end

  def latest_version_path
    File.join(ruby_motion_root, latest_version)
  end

  def bridge_support_files
    Dir.glob("#{latest_version_path}/BridgeSupport/*.bridgesupport")
  end

  # Compile the RubyMotion completion plist
  def compile
    # This will hold the dict @fragments
    @fragment = []

    bridge_support_files.each do |file_path|
      doc = xml_document(file_path)

      next unless doc.root.has_elements?

      puts "Compiling: %s" % file_path.split("/").last

      doc.root.each_element do |node|
        case node.name
        when "class"
          parse_class(node)
        when "informal_protocol"
          parse_class(node)
        when "function"
          parse_function(node)
        when "constant"
          parse_constant(node)
        when "enum"
          parse_enum(node)
        when "cftype"
        when "function_alias"
        when "opaque"
        when "string_constant"
        when "struct"
        end
      end
    end
      
    # Sort the @fragment
    @fragment.sort!
      
    # Remove duplicates, not sure if this really works
    @fragment.uniq!

    return to_plist
  end

  def to_plist
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><array>%s</array></plist>"  % @fragment.to_s.gsub(/\>\</, ">\n<")
  end

  def xml_document(file_path)
    file = File.open(file_path)
    REXML::Document.new(file)
  end

  # Creates a dict element
  def create_dict(display, insert=nil, match=nil)
    elem_dict = REXML::Element.new("dict")

    # Display
    elem_display = REXML::Element.new("key", elem_dict).add_text("display")
    elem_string = REXML::Element.new("string", elem_dict).add_text(display)

    # Insert
    if insert != nil
      elem_display = REXML::Element.new("key", elem_dict).add_text("insert")
      elem_string = REXML::Element.new("string", elem_dict).add_text(insert)
    end
    
    # Match
    if match != nil
      elem_display = REXML::Element.new("key", elem_dict).add_text("match")
      elem_string = REXML::Element.new("string", elem_dict).add_text(match)
    else
      elem_display = REXML::Element.new("key", elem_dict).add_text("match")
      elem_string = REXML::Element.new("string", elem_dict).add_text(display.chomp(":"))
    end

    return elem_dict
  end
  
  # Create an argument string
  def create_insert(method_name, method)
    i = 0
    idx = 1
    insert = ""
    prefixes = []
    arguments = []

    # Create the prefixes array
    if method.get_elements("arg").length > 1
      prefixes = method_name.split(":")
      prefixes[0] = nil
    end
    
    # Create the arguments array
    method.each_element("arg") do |param|
      prefix = ""

      # Construct prefix
      prefix = prefixes[i] + ":" if prefixes[i] != nil

      # Add argument to the array
      arguments << "%s${%d:%s %s}" % [prefix, idx, param.attribute("declared_type").to_s, param.attribute("name").to_s]

      # Increase counters
      i += 1
      idx += 1
    end
    
    # Construct insert string
    insert = arguments.join(", ")
    insert = "(%s)" % insert unless insert == ""
    
    return insert
  end

  # Returns a valid class definition
  def parse_class(node)
    class_name = node.attribute("name").to_s

    # Add the main class to the @fragment
    @fragment << create_dict(class_name)

    # Traverse class methods
    node.each_element("method") do |method|
      
      # Prepend method name with class name if this is a class method
      method_name = method.attribute("selector").to_s
      method_name = "%s.%s" % [class_name, method_name] if method.attribute("class_method")

      # Check for the number of arguments
      case method.get_elements("arg").length
        
        # No arguments so strip the ':' if there is one
        when 0
          @fragment << create_dict(method_name)
        
        # A single argument
        when 1
          @fragment << create_dict(method_name, create_insert(method_name, method))

        else
          method_match = method_name.slice(0, method_name.index(":"))
          @fragment << create_dict(method_name, create_insert(method_name, method), method_name)

      end

    end
  end

  # Returns a valid class definition
  def parse_function(node)
    function_name = node.attribute("name").to_s

    # Check for the number of arguments
    case node.get_elements("arg").length
      
      # No arguments so strip the ':' if there is one
      when 0
        @fragment << create_dict(function_name)
      
      # More than one argument
      else
        @fragment << create_dict(function_name, create_insert(function_name, node))

    end
  end

  # Returns a valid constant definition
  def parse_constant(node)
    const_match = node.attribute("name").to_s
    const_type = node.attribute("declared_type").to_s

    # Make sure the first letter is always uppercase, for RubyMotion
    const_match = "%s%s" % [const_match[0,1].upcase, const_match[1..-1]]

    const_display = "%s (%s)" % [const_match, const_type]

    # Add the element
    @fragment << create_dict(const_display, nil, const_match)
  end

  # Returns a valid enum definition
  def parse_enum(node)
    enum_match = node.attribute("name").to_s
    enum_val = node.attribute("value").to_s

    # Make sure the first letter is always uppercase, for RubyMotion
    enum_match = "%s%s" % [enum_match[0,1].upcase, enum_match[1..-1]]

    enum_display = "%s (%s)" % [enum_match, enum_val]

    # Add the element
    @fragment << create_dict(enum_display, nil, enum_match)
  end

  def ruby_motion_root
    '/Library/RubyMotion/data'
  end

  def installed_versions
    (Dir.entries(ruby_motion_root) - %w[. ..]).select { |entry|
      File.directory? File.join(ruby_motion_root,entry)
    }.sort
  end

  def latest_version
    installed_versions.last
  end
end

# Compile the completion tags
RubyMotionCompletion.new().compile
