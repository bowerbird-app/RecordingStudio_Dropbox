# frozen_string_literal: true

require_relative "api/access"
require_relative "api/errors"
require_relative "api/page"
require_relative "api/import"
require_relative "api/list"
require_relative "api/search"
require_relative "api/endpoints"
require_relative "api/registration"

module RecordingStudioDropbox
  module Api
    class << self
      def register!(api: :public)
        return unless recording_studio_api_available?
        return unless attachable_available?

        Registration.register!(api: api)
        true
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) && RecordingStudioApi.respond_to?(:register_endpoint)
      end

      def attachable_available?
        defined?(RecordingStudioAttachable) && defined?(RecordingStudioDropbox::Attachable::Import)
      end
    end
  end
end
