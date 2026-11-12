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
        return if RecordingStudioApi.registered_endpoint(name, api: api)

        RecordingStudioApi.register_endpoint(name, api: api, **endpoint.except(:name))
      end
    end
  end
end
