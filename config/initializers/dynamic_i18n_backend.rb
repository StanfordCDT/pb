# Be sure to restart your server when you modify this file.

# Modified from https://github.com/svenfuchs/i18n/blob/master/lib/i18n/backend/simple.rb
# Implement an I18n backend that looks up the given key in Thread.current[:i18n_locales] first,
# and, if not found, then finds it in locales/*.yml as usual.
# This is to allow elections to override strings in locales/*.yml.

module I18n::Backend
    # A simple backend that reads translations stored in the database first and then from
    # YAML files and stores them in
    # an in-memory hash. Relies on the Base backend.
    #
    # The implementation is provided by a Implementation module allowing to easily
    # extend Simple backend's behavior by including modules. E.g.:
    #
    # module I18n::Backend::Pluralization
    #   def pluralize(*args)
    #     # extended pluralization logic
    #     super
    #   end
    # end
    #
    # I18n::Backend::Simple.include(I18n::Backend::Pluralization)
    class DynamicSimple < Simple

      protected

        # Looks up a translation from the translations hash. Returns nil if
        # eiher key is nil, or locale, scope or key do not exist as a key in the
        # nested translations hash. Splits keys or scopes containing dots
        # into multiple keys, i.e. <tt>currency.format</tt> is regarded the same as
        # <tt>%w(currency format)</tt>.
        def lookup(locale, key, scope = [], options = {})
          init_translations unless initialized?
          keys = I18n.normalize_keys(locale, key, scope, options[:separator])
          tmp = lookup_helper(keys, Thread.current[:i18n_locales], scope, options)
          tmp = lookup_helper(keys, translations, scope, options) if tmp.nil?
          tmp
        end

        def lookup_helper(keys, ts, scope, options)
          keys.inject(ts) do |result, _key|
            _key = _key.to_sym
            return nil unless result.is_a?(Hash) && result.has_key?(_key)
            result = result[_key]
            result = resolve(locale, _key, result, options.merge(:scope => nil)) if result.is_a?(Symbol)
            result
          end
        end

    end
end

I18n.backend = I18n::Backend::DynamicSimple.new
#I18n.config.enforce_available_locales = false
