# frozen_string_literal: true

module RecordingStudioDropbox
  class DownloadedFile
    attr_reader :body, :filename, :content_type

    def initialize(body:, filename:, content_type: nil)
      @body = body
      @filename = filename
      @content_type = content_type
    end
  end
end
