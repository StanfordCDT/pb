#!/usr/bin/env ruby

# This script converts <lang>.yml to a Gengo file.
# Run with ruby script/yaml_to_gengo.rb <lang>
# Where <lang> is the language code of the language you want to convert for.
# This file (translated) can serve as input for the script gengo_to_yaml.rb 

require "yaml"

if ARGV.length != 1
  puts "Usage: " + File.basename(__FILE__) + " <lang>"
  puts ""
  puts "Example: " + File.basename(__FILE__) + " zh"
  puts ""
  puts "This script converts zh.yml to a Gengo file zh_current.csv."
  exit(-1)
end

lang_gengo = ARGV[0]
yml_in = lang_gengo + ".yml"
output_gengo = lang_gengo + "_current.csv"

LANG_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", yml_in)

# Escape HTML tags and Ruby placeholders with triple brackets.
# For example, this returns "[[[<b><u>]]]test[[[</u>]]]test[[[</b>]]] x[[[%{abc}]]]y"
# for "<b><u>test</u>test</b> x%{abc}y"
def escape_value(s)
  r = ""
  while s.length > 0 do
    m = /(?:<.+?>|%{.+?})+/.match(s)
    if !m.nil?
      r += m.pre_match + "[[[" + m[0] + "]]]"
      s = m.post_match
    else
      r += s
      break
    end
  end
  r.gsub("\\\"", "\"").gsub("\\\\", "\\")
end

def convert_yml_to_gengo()
  s = File.read(LANG_PATH)
  root = YAML.load_file(LANG_PATH)
  ret = ""
  cur_indent = 0
  stack = []
  while s.length > 0 do
    # Match strings like '  key: "value" # This is a test.'
    m = /\A( *)([a-zA-Z_]+):(?: |\n)*"(|.*?[^\\])" *(#.*?)?\n/m.match(s)
    if !m.nil?
      space = m[1]
      subkey = m[2]
      has_value = true
      comment = m[4]
      s = m.post_match
    else
      # Match strings like '  key: # This is a test.'
      m = /\A( *)([a-zA-Z_]+): *(#.*?)?\n/m.match(s)
      if !m.nil?
        space = m[1]
        subkey = m[2]
        has_value = false
        comment = m[3]
        s = m.post_match
      end
    end

    if !m.nil?
      raise "Indentation must be divisible by 2" if space.length % 2 != 0
      indent = space.length / 2
      raise "Wrong indentation" if indent > cur_indent + 1

      while stack.length > indent do
        stack.pop()
      end
      stack.push(subkey)

      key = stack[1...stack.length].join(".")
      ret += "[[[+" + key + (comment.nil? ? "" : ("  " + comment)) + "]]]\n"
      if has_value
        text = stack.inject(root) { |memo, subkey| memo[subkey] }
        ret += escape_value(text).gsub(/^ +/, "") + "\n\n"
      else
        ret += "\n"
      end

      cur_indent = indent
    else
      m = /\A *\n/m.match(s)
      if m.nil?
        m = /\A *- *:[a-zA-Z_]+\n/m.match(s)
      end
      if m.nil?
        m = /\A *#.*\n/m.match(s)
      end
      raise "Unrecognized line" if m.nil?
      s = m.post_match
    end
  end
  ret
end

File.write(output_gengo, convert_yml_to_gengo())
