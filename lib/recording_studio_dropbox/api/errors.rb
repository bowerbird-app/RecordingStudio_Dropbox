# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    module Errors
      module_function

      def wrap
        yield
      rescue RecordingStudioDropbox::ReconnectRequired => e
        raise RecordingStudioApi::AuthorizationError, e.message
      rescue RecordingStudioDropbox::RequestError, ArgumentError => e
        raise RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
