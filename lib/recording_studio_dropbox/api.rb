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
        Registration.register!(api: api)
      end
    end
  end
end
