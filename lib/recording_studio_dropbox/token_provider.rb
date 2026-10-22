# frozen_string_literal: true

module RecordingStudioDropbox
  class TokenProvider
    def self.wrap(source)
      return source if source.is_a?(self)

      new(source)
    end

    def initialize(source)
      @source = source
    end

    def access_token
      token = read_token
      raise ReconnectRequired if blank?(token)

      token.to_s
    end

    private

    def read_token
      source = @source
      return source.access_token if source.respond_to?(:access_token)
      return source.call if source.respond_to?(:call)

      source
    end

    def blank?(token)
      token.nil? || token.to_s.strip.empty?
    end
  end
end
