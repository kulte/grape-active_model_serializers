module Grape
  module Formatter
    module ActiveModelSerializers

      ADAPTER_OPTION_KEYS = [:include, :fields, :root, :adapter]

      class << self
        def call(resource, env)
          adapter_options, serializer_options =
              ams_options(env).partition { |k, _| ADAPTER_OPTION_KEYS.include? k }.map { |h| Hash[h] }
          serializer = fetch_serializer(resource, env, serializer_options)
          adapter = fetch_adapter(serializer, resource, env, adapter_options)


          if adapter
            adapter.serializable_hash.to_json
          else
            if serializer
              serializer.object.to_json
            else
              Grape::Formatter::Json.call resource, env
            end
          end
        end

        def fetch_adapter(serializer, resource, env, ams_options)
          return nil unless serializer

          endpoint = env['api.endpoint']
          options = build_adapter_options_from_endpoint(endpoint)

          adapter = options.fetch(:adapter, ActiveModel::Serializer.config.adapter)
          return nil unless adapter

          ActiveModel::Serializer::Adapter.create(serializer, options.merge(ams_options))
        end

        def fetch_serializer(resource, env, ams_options)
          endpoint = env['api.endpoint']
          options = build_options_from_endpoint(endpoint)

          serializer = options.fetch(:serializer, ActiveModel::Serializer.serializer_for(resource))
          return nil unless serializer

          if options.key?(:each_serializer)
            options[:serializer] = options.delete :each_serializer
          end

          options[:scope] = endpoint unless options.key?(:scope)
          # ensure we have an root to fallback on
          options[:resource_name] = default_root(endpoint) if resource.respond_to?(:to_ary)
          serializer.new(resource, options.merge(ams_options))
        end

        def ams_options(env)
          env['ams_meta'] || {}
        end

        def build_options_from_endpoint(endpoint)
          [endpoint.default_serializer_options || {}, endpoint.namespace_options, endpoint.route_options, endpoint.options, endpoint.options.fetch(:route_options)].reduce(:merge)
        end

        def build_adapter_options_from_endpoint(endpoint)
          endpoint.default_adapter_options || {}
        end

        # array root is the innermost namespace name ('space') if there is one,
        # otherwise the route name (e.g. get 'name')
        def default_root(endpoint)
          innermost_scope = if endpoint.respond_to?(:namespace_stackable)
                              endpoint.namespace_stackable(:namespace).last
                            else
                              endpoint.settings.peek[:namespace]
                            end

          if innermost_scope
            innermost_scope.space
          else
            endpoint.options[:path][0].to_s.split('/')[-1]
          end
        end
      end
    end
  end
end
