# frozen_string_literal: true

module RecordingStudioDropbox
  module OauthProvider
    KEY = :dropbox
    AUTHORIZE_URL = "https://www.dropbox.com/oauth2/authorize"
    TOKEN_URL = "https://api.dropboxapi.com/oauth2/token"
    REVOKE_URL = "https://api.dropboxapi.com/2/auth/token/revoke"
    TOKEN_ACCESS_TYPE = "offline"

    module_function

    def register!(**overrides)
      RecordingStudioOauth.register_outbound_provider(**defaults, **overrides)
    end

    def defaults
      {
        key: KEY,
        authorize_url: AUTHORIZE_URL,
        token_url: TOKEN_URL,
        revoke_url: REVOKE_URL,
        scopes: Client::SCOPES,
        pkce: true,
        refresh: true,
        extra_authorize_params: { "token_access_type" => TOKEN_ACCESS_TYPE }
      }
    end
  end
end
