# frozen_string_literal: true

module RecordingStudioDropbox
  class AccessToken
    def initialize(provider)
      raise ArgumentError if provider.is_a?(String)

      @provider = provider
    end

    def to_s
      token = read_token
      raise ReconnectRequired if token.nil? || token.to_s.strip.empty?

      token.to_s
    end

    private

    def read_token
      return @provider.call if @provider.respond_to?(:call)
      return @provider.access_token if @provider.respond_to?(:access_token)

      raise ArgumentError
    end
  end
end
