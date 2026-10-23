# frozen_string_literal: true

module RecordingStudioDropbox
  class LimitedBody
    def initialize(max_bytes)
      @limit = Integer(max_bytes)
      @buffer = +"".b
    end

    def append(chunk)
      incoming = chunk.to_s
      if (@buffer.bytesize + incoming.bytesize) > @limit
        raise ArgumentError, I18n.t(
          "recording_studio_dropbox.file_too_large",
          default: "That Dropbox file is over the size limit"
        )
      end

      @buffer << incoming
    end

    def to_s
      @buffer
    end
  end
end
