# frozen_string_literal: true

module RecordingStudioDropbox
  class Error < StandardError; end

  class ReconnectRequired < Error; end

  class RequestError < Error
    attr_reader :status, :code

    def initialize(message = nil, status: nil, code: nil)
      @status = status
      @code = code
      super(message)
    end
  end

  def self.file_too_large_message
    I18n.t(
      "recording_studio_dropbox.file_too_large",
      default: "That Dropbox file is over the size limit"
    )
  end
end
