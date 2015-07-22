module Grape
  module Formatter
    module ActiveModelSerializers
      ADAPTER_OPTION_KEYS = [
          :include,
          :fields,
          :adapter,
          # :root, no longer supported
      ].freeze

      class << self
        def call(resource, env)
          endpoint = env['api.endpoint']
          options = options_from_endpoint(endpoint).merge(ams_meta(env))
          adapter_options, serializer_options =
              options.partition { |k, _| ADAPTER_OPTION_KEYS.include? k }.map { |h| Hash[h] }
          serialized = fetch_serialized(resource, endpoint, serializer_options)
          adapter = fetch_adapter(serialized, adapter_options)

          if adapter
            adapter.serializable_hash.to_json
          else
            if serialized
              serialized.object.to_json
            else
              Grape::Formatter::Json.call resource, env
            end
          end
        end

        def fetch_serialized(resource, endpoint, options)
          serializer = options.fetch(:serializer, ActiveModel::Serializer.serializer_for(resource))
          return nil unless serializer

          if options.key?(:each_serializer)
            options[:serializer] = options.delete :each_serializer
          end

          options[:scope] = endpoint unless options.key?(:scope)
          # ensure we have an root to fallback on
          # options[:resource_name] = default_root(endpoint) if resource.respond_to?(:to_ary)

          begin
            serializer.new(resource, options)
          rescue # ActiveModel::Serializer::ArraySerializer::NoSerializerError
            nil
          end
        end

        def fetch_adapter(serialized, options)
          use_adapter = !(options.key?(:adapter) && !options[:adapter])
          return nil unless use_adapter && serialized

          adapter = options.fetch(:adapter, ActiveModel::Serializer.config.adapter)
          return nil unless adapter

          ActiveModel::Serializer::Adapter.create(serialized, options)
        end

        def ams_meta(env)
          env['ams_meta'] || {}
        end

        def options_from_endpoint(endpoint)
          [
              endpoint.default_serializer_options || {},
              endpoint.default_adapter_options || {},
              endpoint.namespace_options,
              endpoint.route_options,
              endpoint.options,
              endpoint.options.fetch(:route_options)
          ].reduce(:merge)
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
