#!/usr/bin/env ruby
# This file contains code that was developed with AI assistance (Claude 3.5 Sonnet / ChatGPT)

require "yaml"
require "csv"

if ARGV.length != 2
  puts "Usage: " + File.basename(__FILE__) + " <lang> <translated_csv>"
  puts ""
  puts "Examples:"
  puts "  " + File.basename(__FILE__) + " hi translated_hi.csv"
  puts "  " + File.basename(__FILE__) + " es translated_es.csv"
  puts "  " + File.basename(__FILE__) + " fr translated_fr.csv"
  puts ""
  puts "This script updates <lang>.yml with translations from the Gengo CSV file."
  exit(-1)
end

lang_code      = ARGV[0]
translated_csv = ARGV[1]

LANG_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", lang_code + ".yml")

unless File.exist?(translated_csv)
  puts "Error: Translated CSV file not found at #{translated_csv}"
  exit(-1)
end

unless File.exist?(LANG_PATH)
  puts "Error: Locale file not found at #{LANG_PATH}"
  exit(-1)
end

# ---------- helpers ----------

def unescape_value(s)
  return s unless s.is_a?(String)
  s.gsub(/\[\[\[(.*?)\]\]\]/m, '\1')
end

# Convert single-quoted HTML attributes to double-quoted ones *inside tags only*.
# Examples:
#   <p class='lead' style='text-align:center;'>  ->  <p class="lead" style="text-align:center;">
#   <img data-x='a"b' alt='it\'s ok'>            ->  <img data-x="a\"b" alt="it\'s ok">
def normalize_html_attribute_quotes(s)
  return s unless s.is_a?(String)
  s.gsub(/<[^>]*>/m) do |tag|
    tag.gsub(/([^\s=><\/"']+)\s*=\s*'([^']*)'/, '\1="\2"')
  end
end

def set_nested_value(hash, keys, value)
  current = hash
  keys[0...keys.length-1].each do |key|
    current[key] = {} unless current[key].is_a?(Hash)
    current = current[key]
  end
  current[keys.last] = value
end

def parse_gengo_csv(file_path)
  translations = {}
  current_key = nil
  current_value = ""

  File.readlines(file_path, encoding: "UTF-8").each do |line|
    line = line.strip
    next if line.empty?

    if line.match(/^\[\[\[\+(.+)\]\]\]$/)
      translations[current_key] = current_value.strip if current_key && !current_value.empty?
      current_key = Regexp.last_match(1)
      current_value = ""
    elsif current_key
      current_value = current_value.empty? ? line : (current_value + "\n" + line)
    end
  end

  translations[current_key] = current_value.strip if current_key && !current_value.empty?
  translations
end

def update_yaml_with_translations(yaml_data, translations)
  updated_data = yaml_data.dup

  translations.each do |key, translated_value|
    key_parts = key.split(".")
    unescaped  = unescape_value(translated_value)
    normalized = normalize_html_attribute_quotes(unescaped)
    set_nested_value(updated_data, key_parts, normalized)
  end

  updated_data
end

# Recursively apply normalization to *all* strings in the YAML tree.
def deep_normalize_all_html!(obj, counters)
  case obj
  when String
    before = obj
    after  = normalize_html_attribute_quotes(before)
    if after != before
      counters[:changed_strings] += 1
    end
    after
  when Array
    obj.map { |e| deep_normalize_all_html!(e, counters) }
  when Hash
    obj.transform_values { |v| deep_normalize_all_html!(v, counters) }
  else
    obj
  end
end

# ---------- main ----------

begin
  yaml_data = YAML.load_file(LANG_PATH)
rescue => e
  puts "Error loading YAML file: #{e.message}"
  exit(-1)
end

if yaml_data.nil? || yaml_data[lang_code].nil?
  puts "Error: Could not find '#{lang_code}' key in locale file"
  exit(-1)
end

puts "Parsing translated Gengo CSV file: #{translated_csv}"
begin
  translations = parse_gengo_csv(translated_csv)
rescue => e
  puts "Error parsing CSV file: #{e.message}"
  exit(-1)
end

if translations.empty?
  puts "No translations found in the CSV file."
  # Even if no CSV updates, still normalize the whole file to fix '' in HTML attributes.
end

puts "Found #{translations.length} translations to apply."
puts "Updating YAML structure with translations..."
updated_data = update_yaml_with_translations(yaml_data[lang_code], translations)

# NEW: normalize ALL strings in the locale after updates
counters = { changed_strings: 0 }
puts "Normalizing HTML attribute quotes across the entire '#{lang_code}' locale..."
updated_data = deep_normalize_all_html!(updated_data, counters)

final_yaml = { lang_code => updated_data }

puts "Writing updated YAML file to #{LANG_PATH}..."
begin
  yaml_string = final_yaml.to_yaml
  File.write(LANG_PATH, yaml_string, encoding: "UTF-8")
rescue => e
  puts "Error writing YAML file: #{e.message}"
  exit(-1)
end

puts "Success! Updated #{LANG_PATH} with #{translations.length} translations."
puts "Strings with HTML attributes normalized: #{counters[:changed_strings]}"
puts "Updated keys:"
translations.each do |key, value|
  value_preview = value.to_s[0..50]
  value_preview += "..." if value.to_s.length > 50
  puts "  - #{key}: #{value_preview}"
end
