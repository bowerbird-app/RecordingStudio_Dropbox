# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class OauthTokenTest < ActiveSupport::TestCase
  include Devise::Test::IntegrationHelpers

  SECRET_TOKEN = "sl.live-dropbox-token"
  REFRESHED_PREFIX = "refreshed-access-"

  setup do
    FakeDropboxOauth.reset!
    @user = User.create!(
      email: "oauth-token-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    Current.actor = @user
    workspace = Workspace.create!(name: "Token Workspace #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    grant_workspace_access!(@root)
  end

  teardown do
    Current.actor = nil
    FakeDropboxOauth.reset!
  end

  test "token found through connection_for" do
    create_root_connection!(access_token: SECRET_TOKEN, refresh_token: "live-refresh")

    token = RecordingStudioDropbox::OauthToken.new(root: @root, actor: @user).call

    assert_equal SECRET_TOKEN, token
  end

  test "expired token is refreshed through oauth" do
    create_root_connection!(
      access_token: SECRET_TOKEN,
      refresh_token: "live-refresh",
      expires_at: 1.minute.ago
    )

    token = RecordingStudioDropbox::OauthToken.new(root: @root, actor: @user).call

    assert token.start_with?(REFRESHED_PREFIX)
    refute_equal SECRET_TOKEN, token
  end

  test "no connection raises ReconnectRequired" do
    error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
      RecordingStudioDropbox::OauthToken.new(root: @root, actor: @user).call
    end

    assert_equal "Dropbox reconnect required", error.message
    refute_includes error.message, SECRET_TOKEN
  end

  test "revoked connection raises ReconnectRequired" do
    create_root_connection!(
      access_token: SECRET_TOKEN,
      refresh_token: "live-refresh",
      status: "revoked"
    )

    error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
      RecordingStudioDropbox::OauthToken.new(root: @root, actor: @user).call
    end

    assert_equal "Dropbox reconnect required", error.message
    refute_includes error.message, SECRET_TOKEN
  end

  test "refresh failure raises ReconnectRequired" do
    create_root_connection!(
      access_token: SECRET_TOKEN,
      refresh_token: FakeDropboxOauth::FAIL_REFRESH,
      expires_at: 1.minute.ago
    )

    error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
      RecordingStudioDropbox::OauthToken.new(root: @root, actor: @user).call
    end

    assert_equal "Dropbox reconnect required", error.message
    refute_includes error.message, SECRET_TOKEN
    refute_includes error.message, FakeDropboxOauth::FAIL_REFRESH
  end

  private

  def create_root_connection!(access_token:, refresh_token:, expires_at: 1.hour.from_now, status: "active")
    RecordingStudioOauth::OutboundConnection.create!(
      provider_key: RecordingStudioDropbox::OauthProvider::KEY.to_s,
      root_recording: @root,
      connected_by: @user,
      access_token: access_token,
      refresh_token: refresh_token,
      status: status,
      expires_at: expires_at,
      granted_scopes: RecordingStudioDropbox::Client::SCOPES
    )
  end

  def grant_workspace_access!(root, actor: @user, role: :admin)
    result = if role.to_sym == :admin
      RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: actor)
    else
      RecordingStudioAccessible.grant_access(
        recording: root,
        actor: actor,
        role: role,
        manager_actor: @user
      )
    end
    raise result.error if result.failure?
  end
end
