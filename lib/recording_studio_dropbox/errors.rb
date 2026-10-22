# frozen_string_literal: true

module RecordingStudioDropbox
  class Error < StandardError; end

  class ReconnectRequired < Error; end

  class RequestError < Error
    attr_reader :status, :code

    def initialize(status: nil, code: nil)
      @status = status
      @code = code
      super()
    end
  end
end
