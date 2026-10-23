# frozen_string_literal: true

require "test_helper"

class OauthProviderTest < Minitest::Test
  SECRET = "dropbox-client-secret-fixture"

  def test_register_oauth_provider_uses_oauth_public_api
    assert_respond_to RecordingStudioOauth, :register_outbound_provider
    assert_respond_to RecordingStudioOauth, :connection_for
    assert_respond_to RecordingStudioDropbox, :register_oauth_provider

    provider = RecordingStudioDropbox.register_oauth_provider(
      client_id: "id",
      client_secret: SECRET,
      http: ->(_url, _params) { [200, {}] }
    )

    assert_equal "dropbox", provider.key
    assert_equal RecordingStudioDropbox::OauthProvider::AUTHORIZE_URL, provider.authorize_url
    assert_equal RecordingStudioDropbox::OauthProvider::TOKEN_URL, provider.token_url
    assert_equal RecordingStudioDropbox::OauthProvider::SCOPES, provider.scopes
    assert_equal %w[files.metadata.read files.content.read], provider.scopes
    assert provider.refresh?
    assert provider.pkce?
    assert_equal "offline", provider.extra_authorize_params["token_access_type"]
    refute_includes provider.inspect, SECRET
  end

  def test_register_oauth_provider_allows_a_test_http_stub
    provider = RecordingStudioDropbox.register_oauth_provider(
      authorize_url: "/fake_oauth/authorize",
      token_url: "/fake_oauth/token",
      revoke_url: "/fake_oauth/revoke",
      client_id: "id",
      client_secret: SECRET,
      http: ->(_url, _params) { [200, {}] }
    )

    assert_equal "/fake_oauth/authorize", provider.authorize_url
    assert_equal "/fake_oauth/token", provider.token_url
  end

  def test_configure_scopes_override_is_used_when_registering
    original = RecordingStudioDropbox.configuration.scopes
    RecordingStudioDropbox.configuration.scopes = %w[
      files.metadata.read
      files.content.read
      files.content.write
    ]

    provider = RecordingStudioDropbox.register_oauth_provider(
      client_id: "id",
      client_secret: SECRET,
      http: ->(_url, _params) { [200, {}] }
    )

    assert_equal %w[files.metadata.read files.content.read files.content.write], provider.scopes
    assert_equal RecordingStudioDropbox::OauthProvider::SCOPES, RecordingStudioDropbox::Client::SCOPES
    refute_includes RecordingStudioDropbox::OauthProvider::SCOPES, "files.content.write"
  ensure
    RecordingStudioDropbox.configuration.scopes = original
  end
end
