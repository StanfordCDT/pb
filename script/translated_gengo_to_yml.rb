#!/usr/bin/env ruby
# This file contains code that was developed with AI assistance (Claude 3.5 Sonnet)

# =============================================================================
# Translated Gengo to YAML Converter
# =============================================================================
# 
# This script takes a translated Gengo CSV file and updates the corresponding
# YAML locale file with only the newly translated entries. It preserves the
# existing YAML structure and only changes the locations specified in the
# Gengo file.
# 
# Usage: ruby script/translated_gengo_to_yml.rb <lang> <translated_csv>
# Where <lang> is the language code (e.g., 'hi' for Hindi, 'es' for Spanish)
# and <translated_csv> is the path to the translated Gengo CSV file
# 
# The script will:
# 1. Load the existing <lang>.yml file as the base
# 2. Parse the translated Gengo CSV file to extract key-value pairs
# 3. Update only the specified keys in the YAML structure
# 4. Save the updated YAML file
# 
# Examples:
#   ruby script/translated_gengo_to_yml.rb hi translated_hi.csv
#   ruby script/translated_gengo_to_yml.rb es translated_es.csv
#   ruby script/translated_gengo_to_yml.rb fr translated_fr.csv
# =============================================================================

require "yaml"
require "csv"

# =============================================================================
# COMMAND LINE ARGUMENT VALIDATION
# =============================================================================

# Validate that exactly 2 command line arguments are provided
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

# Store command line arguments for later use
lang_code = ARGV[0]           # Target language code (e.g., 'hi', 'es', 'fr')
translated_csv = ARGV[1]      # Path to the translated Gengo CSV file

# =============================================================================
# FILE PATH CONSTRUCTION AND VALIDATION
# =============================================================================

# Construct file paths for the locale files
LANG_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", lang_code + ".yml")

# Validate that both required files exist before proceeding
unless File.exist?(translated_csv)
  puts "Error: Translated CSV file not found at #{translated_csv}"
  exit(-1)
end

unless File.exist?(LANG_PATH)
  puts "Error: Locale file not found at #{LANG_PATH}"
  exit(-1)
end

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# unescape_value(s)
# -----------------------------------------------------------------------------
# Unescapes HTML tags and Ruby placeholders by removing triple brackets.
# This reverses the escaping done in the Gengo format.
# 
# Example:
#   Input:  "[[[<b>]]]Hello[[[</b>]]] [[[%{name}]]]"
#   Output: "<b>Hello</b> %{name}"
# -----------------------------------------------------------------------------
def unescape_value(s)
  return s if s.nil? || !s.is_a?(String)
  
  # Remove triple brackets around HTML tags and Ruby placeholders
  s.gsub(/\[\[\[(.*?)\]\]\]/, '\1')
end

# -----------------------------------------------------------------------------
# set_nested_value(hash, keys, value)
# -----------------------------------------------------------------------------
# Sets a value in a nested hash structure, creating intermediate hashes as needed.
# This is the reverse of get_nested_value - it creates the path if it doesn't exist.
# 
# Example:
#   hash = {}
#   set_nested_value(hash, ["a", "b", "c"], "value")
#   # Result: {"a" => {"b" => {"c" => "value"}}}
# -----------------------------------------------------------------------------
def set_nested_value(hash, keys, value)
  current = hash
  keys[0...keys.length-1].each do |key|
    current[key] = {} unless current[key].is_a?(Hash)
    current = current[key]
  end
  current[keys.last] = value
end

# -----------------------------------------------------------------------------
# parse_gengo_csv(file_path)
# -----------------------------------------------------------------------------
# Parses a Gengo CSV file and extracts key-value pairs.
# The Gengo format uses special markers like [[[+key]]] to indicate keys
# and the following lines contain the translated values.
# 
# Returns:
#   Hash with keys as strings and values as translated strings
# -----------------------------------------------------------------------------
def parse_gengo_csv(file_path)
  translations = {}
  current_key = nil
  current_value = ""
  
  File.readlines(file_path, encoding: 'UTF-8').each do |line|
    line = line.strip
    
    # Skip empty lines
    next if line.empty?
    
    # Check if this line is a key marker (starts with [[[+ and ends with ]]])
    if line.match(/^\[\[\[\+(.+)\]\]\]$/)
      # Save previous key-value pair if we have one
      if current_key && !current_value.empty?
        translations[current_key] = current_value.strip
      end
      
      # Start new key
      current_key = $1  # Extract the key from the match
      current_value = ""
    elsif current_key
      # This is a value line for the current key
      if current_value.empty?
        current_value = line
      else
        # Append to existing value (for multi-line values)
        current_value += "\n" + line
      end
    end
  end
  
  # Don't forget the last key-value pair
  if current_key && !current_value.empty?
    translations[current_key] = current_value.strip
  end
  
  translations
end

# -----------------------------------------------------------------------------
# update_yaml_with_translations(yaml_data, translations)
# -----------------------------------------------------------------------------
# Updates the YAML data structure with the new translations.
# Only updates the keys that are present in the translations hash.
# 
# Parameters:
#   yaml_data    - The existing YAML data structure
#   translations - Hash of key-value pairs from the Gengo CSV
# 
# Returns:
#   Updated YAML data structure
# -----------------------------------------------------------------------------
def update_yaml_with_translations(yaml_data, translations)
  updated_data = yaml_data.dup  # Create a copy to avoid modifying the original
  
  translations.each do |key, translated_value|
    # Split the key into parts (e.g., "navigation.brand" -> ["navigation", "brand"])
    key_parts = key.split('.')
    
    # Unescape the translated value to restore HTML tags and placeholders
    unescaped_value = unescape_value(translated_value)
    
    # Set the value in the nested structure
    set_nested_value(updated_data, key_parts, unescaped_value)
  end
  
  updated_data
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Load the existing YAML file with error handling
begin
  yaml_data = YAML.load_file(LANG_PATH)
rescue => e
  puts "Error loading YAML file: #{e.message}"
  exit(-1)
end

# Validate that the expected language key exists in the loaded data
if yaml_data.nil? || yaml_data[lang_code].nil?
  puts "Error: Could not find '#{lang_code}' key in locale file"
  exit(-1)
end

# Parse the translated Gengo CSV file
puts "Parsing translated Gengo CSV file: #{translated_csv}"
begin
  translations = parse_gengo_csv(translated_csv)
rescue => e
  puts "Error parsing CSV file: #{e.message}"
  exit(-1)
end

# Handle the case where no translations are found
if translations.empty?
  puts "No translations found in the CSV file."
  exit(0)
end

# Report findings
puts "Found #{translations.length} translations to apply."

# Update the YAML data with the new translations
puts "Updating YAML structure with translations..."
updated_data = update_yaml_with_translations(yaml_data[lang_code], translations)

# Create the final YAML structure
final_yaml = { lang_code => updated_data }

# Write the updated YAML file
puts "Writing updated YAML file to #{LANG_PATH}..."
begin
  File.write(LANG_PATH, final_yaml.to_yaml, encoding: 'UTF-8')
rescue => e
  puts "Error writing YAML file: #{e.message}"
  exit(-1)
end

# Provide success message and summary
puts "Success! Updated #{LANG_PATH} with #{translations.length} translations."
puts "Updated keys:"
translations.each do |key, value|
  # Show truncated value for user reference
  value_preview = value.to_s[0..50]
  value_preview += "..." if value.to_s.length > 50
  puts "  - #{key}: #{value_preview}"
end
