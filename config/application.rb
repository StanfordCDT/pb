require_relative 'boot'

require 'rails/all'
##require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

##config.active_record.yaml_column_permitted_classes = [ActiveSupport::HashWithIndifferentAccess]
##config.active_record.yaml_column_permitted_classes = [Symbol, Hash, Array, ActiveSupport::HashWithIndifferentAccess]


module Pb
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2
    ##config.active_record.yaml_column_permitted_classes = [Symbol]
    
    ##config.active_record.yaml_column_permitted_classes = [Symbol, Hash, Array, Date,ActiveSupport::HashWithIndifferentAccess]
    ##config.active_record.use_yaml_unsafe_load = true

    ##config.active_record.yaml_column_permitted_classes = [Symbol, ActiveSupport::HashWithIndifferentAccess,ActionController::Parameters]

    ##config.autoload_paths += %W(#{config.root}/lib)
    ##config.enable_dependency_loading = true

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # See https://stackoverflow.com/q/42016113
    config.action_view.automatically_disable_submit_tag = false
  end
end
