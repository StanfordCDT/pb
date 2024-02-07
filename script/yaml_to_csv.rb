#!/usr/bin/env ruby

# This script converts en.yml to a CSV file.
# Run with ruby script/yaml_to_csv.rb <filename.csv>
# This file (translated) can serve as input for the script csv_to_yaml.rb 

require "yaml"
require "csv"

if ARGV.length != 1
  puts "Usage: " + File.basename(__FILE__) + " <output.csv>"
  puts ""
  puts "Example: " + File.basename(__FILE__) + " output.csv"
  puts ""
  puts "This script converts en.yml to a CSV file."
  exit(-1)
end

output_csv = ARGV[0]

ENGLISH_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", "en.yml")

root = YAML.load_file(ENGLISH_PATH)

s = File.read(ENGLISH_PATH)
cur_indent = 0
stack = []
rows = []

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

    #puts space + subkey
    #puts "[[[+" + stack[1...stack.length].join(".") + (comment.nil? ? "" : ("  " + comment)) + "]]]"
    if has_value
      text = stack.inject(root) { |memo, subkey| memo[subkey] }
      rows << [
        stack[1...stack.length].join("."),
        text,
        comment.nil? ? "" : comment[1...comment.length].strip
      ]
    else
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

csv_string = CSV.generate do |csv|
  csv << ["Key", "Text", "Description"]
  rows.each do |row|
    csv << row
  end
end

File.write(output_csv, csv_string)
