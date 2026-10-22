# frozen_string_literal: true

module RecordingStudioDropbox
  class OauthToken
    def initialize(root:, actor:, provider: OauthProvider::KEY)
      @root = root
      @actor = actor
      @provider = provider
    end

    def call
      token = lookup_connection&.access_token
      raise ReconnectRequired, "Dropbox reconnect required" if token.nil? || token.to_s.strip.empty?

      token.to_s
    end

    alias access_token call

    private

    def lookup_connection
      RecordingStudioOauth.connection_for(provider: @provider, root: @root, actor: @actor)
    end
  end
end
