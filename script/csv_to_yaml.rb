#!/usr/bin/env ruby

# This script converts a .csv file to a .yml file to be used in config/locales.
# Run with ruby script/csv_to_yaml.rb <filename.csv> <language code>
# Make sure that the csv has only the original column, but with translated text instead of English.


require "yaml"
require "csv"

ENGLISH_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", "en.yml")

def convert_csv_to_yml(s, locale_code)
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

  s[1...s.length].each do |line|
    # raise "error" if line.length != 6
    key = line[0]
    value = line[1]
    if value.nil?
      value = ""
    end
    add(root, key, value)
  end

  # Add keys that don't exist in en.yml
  root["date"] = {
    "month_names" => [nil, "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
    "order" => [:month, :day, :year]
  }

  new_lang = {}
  new_lang[locale_code] = root
  new_lang.to_yaml.sub(/^---\n/, "")
end

if ARGV.length != 2
  puts "Usage: " + File.basename(__FILE__) + " <input.csv> <locale_code>"
  puts ""
  puts "Example: " + File.basename(__FILE__) + " hindi.csv hi"
  puts ""
  puts "This script converts a .csv file to a .yml file to be used in config/locales."
  puts "The first row of the CSV must be the header. It is ignored."
  puts "The first column must be the keys. The second must be the values. Other columns are ignored."
  exit(-1)
end

input_csv = ARGV[0]
locale_code = ARGV[1]

s = CSV.read(input_csv)
output = convert_csv_to_yml(s, locale_code)
File.write(locale_code + ".yml", output)

puts "Success. The output is " + locale_code + ".yml."
puts "To complete the translation, you must update these keys:"
puts "- date.month_names"
puts "- date.order"
puts "- errors.message.blank (copy from en.yml)"
puts "- errors.message.invalid (copy from en.yml)"
puts "Use https://github.com/svenfuchs/rails-i18n/tree/master/rails/locale for reference of these keys."
puts "Add the new language to available_locales in config_editor.jsx"
puts "Add the new language name to locale_names.rb"
puts "Once you are done, copy the YML file to [Rails root]/config/locales"
