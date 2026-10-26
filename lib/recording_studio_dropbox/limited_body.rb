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
        raise ArgumentError, RecordingStudioDropbox.file_too_large_message
      end

      @buffer << incoming
    end

    def to_s
      @buffer
    end
  end
end
