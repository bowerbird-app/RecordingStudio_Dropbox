# frozen_string_literal: true

module RecordingStudioDropbox
  class AccessToken
    def initialize(provider)
      raise ArgumentError, "Dropbox access tokens cannot be a raw string" if string_provider?(provider)
      unless provider.respond_to?(:call) || provider.respond_to?(:access_token)
        raise ArgumentError, "Dropbox access token provider must respond to call or access_token"
      end

      @provider = provider
    end

    def to_s
      token = @provider.respond_to?(:call) ? @provider.call : @provider.access_token
      raise ReconnectRequired, "Dropbox access token is blank" if token.nil? || token.to_s.strip.empty?

      token.to_s
    end

    private

    def string_provider?(provider)
      provider.instance_of?(String)
    end
  end
end
