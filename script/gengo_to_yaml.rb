#!/usr/bin/env ruby

# This script converts a Gengo file to a .yml file to be used in config/locales.
# Run with ruby script/gengo_to_yaml.rb <filename.csv> <language code>
# Make sure that the csv has only the original column, but with translated text instead of English.

require "yaml"

ENGLISH_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", "en.yml")

def convert_gengo_to_yml(s, prefix)
  root = YAML.load_file(ENGLISH_PATH)["en"]

  def add(root, key, value)
    return if key.nil?
    m = /\A[ \n]*(.*?)[ \n]*\Z/m.match(value)
    value = m[1]
    return if value == ""

    subkeys = key.split(".")

    o = root
    subkeys[0...subkeys.length - 1].each do |subkey|
      raise "key error" if !o.key?(subkey)
      o = o[subkey]
    end
    raise "key error" if !o.key?(subkeys.last)
    o[subkeys.last] = value.gsub("[[[", "").gsub("]]]", "")
  end

  key = nil
  value = ""

  s.gsub("\r", "").lines.each do |line|
    if line.start_with?("[[[+")
      if !key.nil?
        add(root, key, value)
      end

      m = /\A\[\[\[\+(.+?)(?: |\])/.match(line)
      key = m[1]
      value = ""
    elsif !key.nil?
      value += line
    end
  end
  if !key.nil?
    add(root, key, value)
  end

  # Add keys that don't exist in en.yml
  root["date"] = {
    "month_names" => [nil, "January", "February", "March", "April", "May", "June", "Jul", "August", "September", "October", "November", "December"],
    "order" => [:month, :day, :year]
  }

  new_lang = {}
  new_lang[prefix] = root
  new_lang.to_yaml.sub(/^---\n/, "")
end

if ARGV.length != 2
  puts "Usage: " + File.basename(__FILE__) + " <input> <locale_code>"
  puts ""
  puts "Example: " + File.basename(__FILE__) + " hindi.txt hi"
  puts ""
  puts "This script converts a Gengo file to a .yml file to be used in config/locales."
  exit(-1)
end

input_gengo = ARGV[0]
locale_code = ARGV[1]

s = File.read(input_gengo)
output = convert_gengo_to_yml(s, locale_code)
File.write(locale_code + ".yml", output)

puts "Success. The output is at " + locale_code + ".yml\n"
puts "To complete the translation, you must update these keys:"
puts "- date.month_names"
puts "- date.order"
puts "- errors.message.blank (copy from en.yml)"
puts "- errors.message.invalid (copy from en.yml)"
puts "Use https://github.com/svenfuchs/rails-i18n/tree/master/rails/locale for reference of these keys."
puts "Add the new language to available_locales in config_editor.jsx"
puts "Add the new language name to locale_names.rb"
puts "Once you are done, copy the YML file to [Rails root]/config/locales"
