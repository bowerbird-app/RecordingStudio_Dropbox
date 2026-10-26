# frozen_string_literal: true

module RecordingStudioDropbox
  module OauthProvider
    KEY = :dropbox
    AUTHORIZE_URL = "https://www.dropbox.com/oauth2/authorize"
    TOKEN_URL = "https://api.dropboxapi.com/oauth2/token"
    REVOKE_URL = "https://api.dropboxapi.com/2/auth/token/revoke"
    TOKEN_ACCESS_TYPE = "offline"
    SCOPES = Configuration::DEFAULT_SCOPES

    module_function

    def register!(**overrides)
      return if credentials_blank?(overrides)

      RecordingStudioOauth.register_outbound_provider(**defaults, **overrides, kind: :root)
    end

    def defaults
      {
        key: KEY,
        authorize_url: AUTHORIZE_URL,
        token_url: TOKEN_URL,
        revoke_url: REVOKE_URL,
        scopes: RecordingStudioDropbox.configuration.scopes,
        pkce: true,
        refresh: true,
        extra_authorize_params: { "token_access_type" => TOKEN_ACCESS_TYPE }
      }
    end

    def credentials_blank?(overrides)
      client_id, client_secret = resolved_credentials(overrides)
      client_id.blank? && client_secret.blank?
    end

    def resolved_credentials(overrides)
      stored = stored_credentials
      [
        present_credential(overrides[:client_id]) || stored[:client_id],
        present_credential(overrides[:client_secret]) || stored[:client_secret]
      ]
    end

    def stored_credentials
      raw = rails_outbound_credentials
      return { client_id: nil, client_secret: nil } if raw.blank?

      {
        client_id: present_credential(raw[:client_id] || raw["client_id"]),
        client_secret: present_credential(raw[:client_secret] || raw["client_secret"])
      }
    end

    def rails_outbound_credentials
      return unless defined?(Rails) && Rails.application.respond_to?(:credentials)

      creds = Rails.application.credentials
      creds.dig(:recording_studio_oauth, :outbound, KEY).presence ||
        creds.dig(:recording_studio_oauth, :outbound, KEY.to_s)
    end

    def present_credential(value)
      stripped = value.respond_to?(:to_s) ? value.to_s.strip : ""
      stripped.empty? ? nil : stripped
    end
  end
end
