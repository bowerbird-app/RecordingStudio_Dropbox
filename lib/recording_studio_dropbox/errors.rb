# frozen_string_literal: true

module RecordingStudioDropbox
  class Error < StandardError; end

  class ReconnectRequired < Error; end

  class ApiError < Error
    attr_reader :status, :tag

    def initialize(message = nil, status:, tag: nil)
      @status = status
      @tag = tag
      super(message)
    end
  end
end
