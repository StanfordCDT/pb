#!/usr/bin/env ruby
# This file contains code that was developed with AI assistance (Claude 3.5 Sonnet)

# =============================================================================
# YAML Untranslated Content Extractor for Gengo Translation
# =============================================================================
# 
# This script extracts untranslated parts from any locale YAML file and saves 
# them in Gengo format for translation. It compares the target language file 
# against en.yml to identify missing or untranslated content.
# 
# Usage: ruby script/yml_untranslated_to_gengo.rb <lang> <output.csv>
# Where <lang> is the language code (e.g., 'hi' for Hindi, 'es' for Spanish, 'fr' for French)
# 
# The script will:
# 1. Load en.yml as the reference/base locale
# 2. Load <lang>.yml as the target locale to analyze
# 3. Compare the two files to find missing or untranslated keys
# 4. Output the untranslated content in Gengo format for translation
# 
# Examples:
#   ruby script/yml_untranslated_to_gengo.rb hi untranslated_hi.csv
#   ruby script/yml_untranslated_to_gengo.rb es untranslated_es.csv
#   ruby script/yml_untranslated_to_gengo.rb fr untranslated_fr.csv
# =============================================================================

require "yaml"
require "csv"

# =============================================================================
# COMMAND LINE ARGUMENT VALIDATION
# =============================================================================

# Validate that exactly 2 command line arguments are provided
if ARGV.length != 2
  puts "Usage: " + File.basename(__FILE__) + " <lang> <output.csv>"
  puts ""
  puts "Examples:"
  puts "  " + File.basename(__FILE__) + " hi untranslated_hi.csv"
  puts "  " + File.basename(__FILE__) + " es untranslated_es.csv"
  puts "  " + File.basename(__FILE__) + " fr untranslated_fr.csv"
  puts ""
  puts "This script extracts untranslated parts from <lang>.yml and saves them in Gengo format."
  exit(-1)
end

# Store command line arguments for later use
lang_code = ARGV[0]  # Target language code (e.g., 'hi', 'es', 'fr')
output_csv = ARGV[1] # Output file path for the Gengo format results

# =============================================================================
# FILE PATH CONSTRUCTION AND VALIDATION
# =============================================================================

# Construct file paths for the locale files
# ENGLISH_PATH: Points to the English reference file (en.yml)
# LANG_PATH: Points to the target language file (<lang>.yml)
ENGLISH_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", "en.yml")
LANG_PATH = File.join(File.dirname(__FILE__), "..", "config", "locales", lang_code + ".yml")

# Validate that both required files exist before proceeding
# This prevents the script from running if files are missing
unless File.exist?(ENGLISH_PATH)
  puts "Error: English locale file not found at #{ENGLISH_PATH}"
  exit(-1)
end

unless File.exist?(LANG_PATH)
  puts "Error: Locale file not found at #{LANG_PATH}"
  exit(-1)
end

# -----------------------------------------------------------------------------
# escape_value(s)
# -----------------------------------------------------------------------------
# Escapes HTML tags and Ruby placeholders by wrapping them in triple brackets.
# This is necessary for the Gengo format to preserve formatting and variables.
# 
# Example:
#   Input:  "<b>Hello</b> %{name}"
#   Output: "[[[<b>]]]Hello[[[</b>]]] [[[%{name}]]]"
# -----------------------------------------------------------------------------
def escape_value(s)
  r = ""  # Result string to build
  while s.length > 0 do
    # Match HTML tags (<tag>) or Ruby placeholders (%{var}) individually
    m = /<.+?>|%{.+?}/.match(s)
    if !m.nil?
      # Found a tag/placeholder - add everything before it, then the escaped tag
      r += m.pre_match + "[[[" + m[0] + "]]]"
      s = m.post_match  # Continue with the rest of the string
    else
      # No more tags/placeholders found - add the remaining text
      r += s
      break
    end
  end
  # Clean up any escaped quotes and backslashes
  r.gsub("\\\"", "\"").gsub("\\\\", "\\")
end

# -----------------------------------------------------------------------------
# has_translatable_content(value)
# -----------------------------------------------------------------------------
# Checks if a value contains any translatable content after escaping HTML tags
# and Ruby placeholders. Returns true if there are words to translate, false otherwise.
# 
# Example:
#   has_translatable_content("<b>Hello</b>")     # Returns true
#   has_translatable_content("<b></b>")          # Returns false
#   has_translatable_content("%{name}")          # Returns false
#   has_translatable_content("Hello %{name}")   # Returns true
# -----------------------------------------------------------------------------
def has_translatable_content(value)
  return false if value.nil? || !value.is_a?(String)
  
  # Escape the value to get the final format
  escaped = escape_value(value)
  
  # Remove all escaped tags and placeholders to get only translatable content
  # Use a more robust approach: remove all [[[...]]] patterns
  translatable_content = escaped.gsub(/\[\[\[.*?\]\]\]/, '').strip
  
  # Check if there are any actual words (letters) left after removing escaped content
  # Look for sequences of letters (not just any non-whitespace characters)
  has_letters = translatable_content.match?(/[a-zA-Z\u00C0-\u017F\u0100-\u017F\u0180-\u024F\u1E00-\u1EFF]/)
  
  has_letters
end

# -----------------------------------------------------------------------------
# get_nested_value(hash, keys)
# -----------------------------------------------------------------------------
# Safely navigates nested hash structures without crashing if any level is missing.
# 
# Example:
#   data = {"a" => {"b" => {"c" => "value"}}}
#   get_nested_value(data, ["a", "b", "c"])  # Returns "value"
#   get_nested_value(data, ["a", "x"])       # Returns nil (safe)
# -----------------------------------------------------------------------------
def get_nested_value(hash, keys)
  keys.inject(hash) { |memo, key| memo && memo[key] }
end

# -----------------------------------------------------------------------------
# set_nested_value(hash, keys, value)
# -----------------------------------------------------------------------------
# Sets a value in a nested hash structure, creating intermediate hashes as needed.
# This function is defined but not used in the current script - kept for completeness.
# -----------------------------------------------------------------------------
# def set_nested_value(hash, keys, value)
#   current = hash
#   keys[0...keys.length-1].each do |key|
#     current[key] = {} unless current[key].is_a?(Hash)
#     current = current[key]
#   end
#   current[keys.last] = value
# end

# -----------------------------------------------------------------------------
# normalize_text(text)
# -----------------------------------------------------------------------------
# Normalizes text for comparison by removing extra whitespace, converting to lowercase,
# and handling common formatting differences that don't affect meaning.
# -----------------------------------------------------------------------------
def normalize_text(text)
  return "" if text.nil?
  
  # Convert to string and normalize
  text.to_s
      .strip                    # Remove leading/trailing whitespace
      .downcase                 # Convert to lowercase
      .gsub(/\s+/, ' ')         # Replace multiple spaces with single space
      .gsub(/\s*([.,!?;:])\s*/, '\1')  # Remove spaces around punctuation
end

# -----------------------------------------------------------------------------
# calculate_similarity(text1, text2)
# -----------------------------------------------------------------------------
# Calculates similarity between two texts using the amatch library.
# Returns a value between 0.0 (completely different) and 1.0 (identical).
# 
# Uses Jaro-Winkler distance which is excellent for detecting similar strings
# with minor differences like capitalization, spacing, etc.
# -----------------------------------------------------------------------------
def calculate_similarity(text1, text2)
  return 1.0 if text1 == text2  # Exact match
  return 0.0 if text1.nil? || text2.nil? || text1.empty? || text2.empty?
  
  # Normalize both texts for fair comparison
  norm1 = normalize_text(text1)
  norm2 = normalize_text(text2)
  
  return 1.0 if norm1 == norm2  # Identical after normalization
  
  # Use Jaro-Winkler distance for similarity calculation
  # This is particularly good for detecting strings that are almost identical
  begin
    require 'amatch'
    
    # Jaro-Winkler gives higher scores for strings that start the same way
    # Perfect for detecting copy-paste with minor modifications
    jaro_winkler = Amatch::JaroWinkler.new(norm1)
    jaro_winkler.match(norm2)
  rescue LoadError
    # Show error if amatch gem is not available
    puts "Error: amatch gem is required for similarity calculation."
    puts "Please install with: gem install amatch"
    exit(-1)
  end
end

# -----------------------------------------------------------------------------
# is_untranslated_value(en_value, lang_value, threshold = 0.9)
# -----------------------------------------------------------------------------
# Checks if a value is untranslated by comparing it with the English version.
# A value is considered untranslated if:
# 1. It doesn't exist (nil)
# 2. It's empty
# 3. It's very similar to the English value (above threshold)
# 
# The similarity threshold (default 0.9) means 90% similar or more is considered untranslated.
# This accounts for small differences like capitalization, spacing, etc.
# -----------------------------------------------------------------------------
def is_untranslated_value(en_value, lang_value, threshold = 0.9)
  return true if lang_value.nil?                    # Key doesn't exist
  return true if lang_value.to_s.strip.empty?      # Empty value
  
  # Calculate similarity between English and target language values
  similarity = calculate_similarity(en_value, lang_value)
  
  # If similarity is above threshold, it's likely untranslated (just copied with minor changes)
  similarity >= threshold
end

# =============================================================================
# CORE ANALYSIS FUNCTIONS
# =============================================================================

# -----------------------------------------------------------------------------
# find_missing_keys(en_data, lang_data, prefix = [])
# -----------------------------------------------------------------------------
# Recursively compares English data with target language data to find missing
# or untranslated keys. This is the heart of the script.
# 
# Parameters:
#   en_data   - Hash containing English locale data
#   lang_data - Hash containing target language locale data  
#   prefix    - Array of keys representing current path (for recursion)
# 
# Returns:
#   Array of hashes containing missing key information
# -----------------------------------------------------------------------------
def find_missing_keys(en_data, lang_data, prefix = [])
  missing_keys = []  # Array to collect all missing keys
  
  # Iterate through each key-value pair in the English data
  en_data.each do |key, value|
    # Build the current path and key for this iteration
    current_path = prefix + [key]
    current_key = current_path.join(".")  # e.g., "navigation.home"
    
    if value.is_a?(Hash)
      # Current value is a nested hash - need to check recursively
      lang_value = get_nested_value(lang_data, [key])
      
      if lang_value.nil? || !lang_value.is_a?(Hash)
        # The entire section is missing from target language
        # Add all keys from this section as missing
        missing_keys.concat(flatten_hash(value, current_path))
      else
        # Section exists - recursively check nested keys
        missing_keys.concat(find_missing_keys(value, lang_value, current_path))
      end
    else
      # Current value is a leaf (string/number) - check if it's translated
      lang_value = get_nested_value(lang_data, [key])
      
      # Determine if this key is untranslated by comparing with English
      is_untranslated = is_untranslated_value(value, lang_value)
      
      if is_untranslated
        # Add this key to the missing keys list
        missing_keys << {
          key: current_key,      # Full key path (e.g., "navigation.home")
          value: value,         # English value to translate
          comment: nil          # No comment for now
        }
      end
    end
  end
  
  missing_keys  # Return all found missing keys
end

# -----------------------------------------------------------------------------
# flatten_hash(hash, prefix = [])
# -----------------------------------------------------------------------------
# Converts a nested hash structure into a flat list of key-value pairs.
# Used when an entire section is missing from the target language.
# 
# Example:
#   hash = {"a" => {"b" => "value1", "c" => "value2"}}
#   flatten_hash(hash, ["x"])
#   # Returns: [{"key" => "x.a.b", "value" => "value1"}, {"key" => "x.a.c", "value" => "value2"}]
# -----------------------------------------------------------------------------
def flatten_hash(hash, prefix = [])
  result = []
  hash.each do |key, value|
    current_path = prefix + [key]
    current_key = current_path.join(".")
    
    if value.is_a?(Hash)
      # Recursively flatten nested hashes
      result.concat(flatten_hash(value, current_path))
    else
      # Add leaf values to the result
      result << {
        key: current_key,
        value: value,
        comment: nil
      }
    end
  end
  result
end

# convert_to_gengo_format(missing_keys)
# Converts the missing keys into the Gengo format used by other scripts in the project.
# This format is compatible with the existing translation workflow.
def convert_to_gengo_format(missing_keys)
  gengo_content = ""  # String to build the Gengo format content
  
  missing_keys.each do |item|
    key = item[:key]      # Full key path
    value = item[:value]   # English value
    comment = item[:comment]  # Optional comment
    
    # Skip values that don't have any translatable content
    next unless has_translatable_content(value)
    
    # Add the key header in Gengo format
    gengo_content += "[[[+" + key + (comment.nil? ? "" : ("  " + comment)) + "]]]\n"
    
    # Add the escaped value (if it's a string)
    if value.is_a?(String)
      gengo_content += escape_value(value).gsub(/^ +/, "") + "\n\n"
    else
      gengo_content += "\n"
    end
  end
  
  gengo_content
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Load the YAML files with error handling
begin
  # Load English data from en.yml file
  en_data = YAML.load_file(ENGLISH_PATH)["en"]
  # Load target language data from <lang>.yml file
  lang_data = YAML.load_file(LANG_PATH)[lang_code]
rescue => e
  puts "Error loading YAML files: #{e.message}"
  exit(-1)
end

# Validate that the expected keys exist in the loaded data
if en_data.nil?
  puts "Error: Could not find 'en' key in English locale file"
  exit(-1)
end

if lang_data.nil?
  puts "Error: Could not find '#{lang_code}' key in locale file"
  exit(-1)
end

# =============================================================================
# ANALYSIS AND OUTPUT
# =============================================================================

# Find missing/untranslated keys by comparing the two locale files
puts "Analyzing #{lang_code}.yml for untranslated content..."
missing_keys = find_missing_keys(en_data, lang_data)

# Handle the case where everything is already translated
if missing_keys.empty?
  puts "No untranslated keys found. The locale file appears to be fully translated."
  exit(0)
end

# Report findings
puts "Found #{missing_keys.length} untranslated keys."

# Convert the missing keys to Gengo format (filtering out non-translatable content)
gengo_content = convert_to_gengo_format(missing_keys)

# Count how many keys actually made it to the output after filtering
translatable_keys = missing_keys.select { |item| has_translatable_content(item[:value]) }
filtered_count = missing_keys.length - translatable_keys.length

# Write the results to the output file
File.write(output_csv, gengo_content)

# Provide success message and helpful instructions
puts "Success! Untranslated content saved to #{output_csv}"
puts "Found #{missing_keys.length} untranslated keys (#{filtered_count} filtered out for having no translatable content)."
puts "Including #{translatable_keys.length} keys with translatable content:"
translatable_keys.each do |item|
  # Show truncated key and value for user reference
  value_preview = item[:value].to_s[0..50]
  value_preview += "..." if item[:value].to_s.length > 50
  puts "  - #{item[:key]}: #{value_preview}"
end