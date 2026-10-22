# frozen_string_literal: true

require "test_helper"

class OauthTokenTest < Minitest::Test
  SECRET_TOKEN = "sl.secret-dropbox-token"

  def test_returns_token_from_oauth_connection_for
    seen = nil
    connection = token_connection(SECRET_TOKEN)

    RecordingStudioOauth.stub(:connection_for, lookup_stub(connection, seen_box: ->(kwargs) { seen = kwargs })) do
      token = RecordingStudioDropbox::OauthToken.new(root: :workspace, actor: :person).call

      assert_equal SECRET_TOKEN, token
    end

    assert_equal RecordingStudioDropbox::OauthProvider::KEY, seen[:provider]
    assert_equal :workspace, seen[:root]
    assert_equal :person, seen[:actor]
  end

  def test_expired_then_refreshed_uses_the_token_oauth_returns
    connection = token_connection("refreshed-dropbox-token")

    RecordingStudioOauth.stub(:connection_for, lookup_stub(connection)) do
      token = RecordingStudioDropbox::OauthToken.new(root: :workspace, actor: :person).call

      assert_equal "refreshed-dropbox-token", token
    end
  end

  def test_no_connection_raises_reconnect_required_without_a_token
    RecordingStudioOauth.stub(:connection_for, lookup_stub(nil)) do
      error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
        RecordingStudioDropbox::OauthToken.new(root: :workspace, actor: :person).call
      end

      assert_equal "Dropbox reconnect required", error.message
      refute_includes error.message, SECRET_TOKEN
    end
  end

  def test_refresh_failure_raises_reconnect_required_without_a_token
    RecordingStudioOauth.stub(:connection_for, lookup_stub(nil)) do
      error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
        RecordingStudioDropbox::OauthToken.new(root: :workspace, actor: :person).call
      end

      assert_equal "Dropbox reconnect required", error.message
      refute_includes error.message, SECRET_TOKEN
    end
  end

  def test_blank_access_token_raises_reconnect_required
    connection = token_connection("  ")

    RecordingStudioOauth.stub(:connection_for, lookup_stub(connection)) do
      error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
        RecordingStudioDropbox::OauthToken.new(root: :workspace, actor: :person).call
      end

      assert_equal "Dropbox reconnect required", error.message
    end
  end

  private

  def token_connection(token)
    connection = Object.new
    connection.define_singleton_method(:access_token) { token }
    connection
  end

  def lookup_stub(connection, seen_box: nil)
    lambda do |**kwargs|
      seen_box&.call(kwargs)
      connection
    end
  end
end
