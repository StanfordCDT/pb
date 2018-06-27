# Be sure to restart your server when you modify this file.

# Rails wraps fields with error with <div class="field_with_errors">...</div>
# This messes up Bootstrap layout.
# This code prevents this.
ActionView::Base.field_error_proc = Proc.new do |html_tag, instance| 
  html_tag
end
