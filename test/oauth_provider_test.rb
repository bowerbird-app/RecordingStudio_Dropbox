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
    assert_equal :root, provider.kind
    assert_equal RecordingStudioDropbox::OauthProvider::AUTHORIZE_URL, provider.authorize_url
    assert_equal RecordingStudioDropbox::OauthProvider::TOKEN_URL, provider.token_url
    assert_equal RecordingStudioDropbox::OauthProvider::SCOPES, provider.scopes
    assert_equal %w[files.metadata.read files.content.read], provider.scopes
    assert provider.refresh?
    assert provider.pkce?
    assert_equal "offline", provider.extra_authorize_params["token_access_type"]
    refute_includes provider.inspect, SECRET
    assert_includes RecordingStudioOauth.outbound_providers, { key: "dropbox", kind: :root }
  end

  def test_register_oauth_provider_ignores_a_host_kind_override
    provider = RecordingStudioDropbox.register_oauth_provider(
      kind: :user,
      client_id: "id",
      client_secret: SECRET,
      http: ->(_url, _params) { [200, {}] }
    )

    assert_equal :root, provider.kind
    assert_includes RecordingStudioOauth.outbound_providers, { key: "dropbox", kind: :root }
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

  def test_register_oauth_provider_raises_when_only_one_credential_is_present
    with_blank_oauth_credentials do
      missing_secret = assert_raises(ArgumentError) do
        RecordingStudioDropbox.register_oauth_provider(
          client_id: "id",
          http: ->(_url, _params) { [200, {}] }
        )
      end
      assert_equal "client_secret is required", missing_secret.message

      missing_id = assert_raises(ArgumentError) do
        RecordingStudioDropbox.register_oauth_provider(
          client_secret: SECRET,
          http: ->(_url, _params) { [200, {}] }
        )
      end
      assert_equal "client_id is required", missing_id.message
    end
  end

  def test_register_oauth_provider_skips_when_both_credentials_are_blank
    registered = false

    with_blank_oauth_credentials do
      RecordingStudioOauth.stub(:register_outbound_provider, ->(**) { registered = true }) do
        RecordingStudioDropbox.register_oauth_provider
      end
    end

    refute registered
  end

  def test_register_oauth_provider_registers_when_credentials_are_in_rails
    captured = nil
    app = Object.new
    app.define_singleton_method(:credentials) do
      {
        recording_studio_oauth: {
          outbound: { dropbox: { client_id: "from-rails", client_secret: "from-rails-secret" } }
        }
      }
    end
    app.define_singleton_method(:respond_to?) { |name, *| name == :credentials || super(name) }

    Rails.stub(:application, app) do
      RecordingStudioOauth.stub(:register_outbound_provider, ->(**attrs) { captured = attrs }) do
        RecordingStudioDropbox.register_oauth_provider
      end
    end

    assert_equal :dropbox, captured[:key]
    assert_equal :root, captured[:kind]
  end

  def test_register_oauth_provider_registers_when_credentials_are_present
    captured = nil

    RecordingStudioOauth.stub(:register_outbound_provider, ->(**attrs) { captured = attrs }) do
      RecordingStudioDropbox.register_oauth_provider(
        kind: :user,
        client_id: "id",
        client_secret: SECRET
      )
    end

    assert_equal :dropbox, captured[:key]
    assert_equal :root, captured[:kind]
    assert_equal "id", captured[:client_id]
    assert_equal SECRET, captured[:client_secret]
  end

  def test_register_oauth_provider_does_not_swallow_oauth_errors
    error = assert_raises(ArgumentError) do
      RecordingStudioOauth.stub(
        :register_outbound_provider,
        ->(**) { raise ArgumentError, "authorize_url is required" }
      ) do
        RecordingStudioDropbox.register_oauth_provider(
          client_id: "id",
          client_secret: SECRET
        )
      end
    end

    assert_equal "authorize_url is required", error.message
  end

  def test_generated_initializer_calls_register_oauth_provider
    source = File.read(
      File.expand_path(
        "../lib/generators/recording_studio_dropbox/install/templates/recording_studio_dropbox_initializer.rb",
        __dir__
      )
    )

    assert_includes source, "RecordingStudioDropbox.register_oauth_provider"
    refute_includes source, "rescue"
  end

  private

  def with_blank_oauth_credentials(&)
    app = Object.new
    app.define_singleton_method(:credentials) { {} }
    app.define_singleton_method(:respond_to?) { |name, *| name == :credentials || super(name) }

    Rails.stub(:application, app, &)
  end
end
