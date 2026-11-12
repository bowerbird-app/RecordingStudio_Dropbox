# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    module Registration
      EXCLUDED_ENDPOINT_NAMES = Endpoints::EXCLUDED_NAMES
      ENDPOINTS = Endpoints::DEFINITIONS

      module_function

      def register!(api: :public)
        ENDPOINTS.each { |endpoint| register_endpoint!(endpoint, api: api) }
      end

      def register_endpoint!(endpoint, api:)
        name = endpoint.fetch(:name)
        return unless registrable?(name, api: api)

        RecordingStudioApi.register_endpoint(name, api: api, **endpoint.except(:name))
      end

      def registrable?(name, api:)
        recording_studio_api_available? && !already_registered?(name, api: api)
      end

      def already_registered?(name, api:)
        return false unless RecordingStudioApi.respond_to?(:registered_endpoint)

        RecordingStudioApi.registered_endpoint(name, api: api).present?
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) && RecordingStudioApi.respond_to?(:register_endpoint)
      end
    end
  end
end
