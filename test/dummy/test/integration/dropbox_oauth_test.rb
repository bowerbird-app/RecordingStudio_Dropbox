# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "uri"

class DropboxOauthTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    FakeDropboxOauth.reset!
    @user = User.find_by(email: "admin@admin.com")
    if @user.blank?
      @user = User.new(
        email: "admin@admin.com",
        password: "Password",
        password_confirmation: "Password"
      )
      @user.save!
    end
    sign_in @user
    @workspace = Workspace.find_by(name: "Studio Workspace") || Workspace.find_or_create_by!(name: "Studio Workspace")
    Current.actor = @user
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_workspace_access!(@root)
  end

  teardown do
    Current.actor = nil if defined?(Current)
    FakeDropboxOauth.reset!
  end

  test "home shows connect when there is no Dropbox connection" do
    get "/"

    assert_response :success
    assert_includes response.body, "Connect Dropbox"
    assert_includes response.body, "Connect Dropbox to copy files into this workspace."
    refute_includes response.body, "Reconnect Dropbox"
    refute_includes response.body, "Disconnect"
  end

  test "connect stores a workspace connection and home shows disconnect" do
    logs = capture_logs { follow_connect! }

    connection = RecordingStudioOauth::OutboundConnection.find_by!(
      provider_key: "dropbox",
      root_recording_id: @root.id
    )
    assert_equal "active", connection.status
    assert connection.root_owned?
    refute connection.user_owned?
    assert connection.access_token.present?
    refute_includes connection.inspect, connection.access_token
    refute_includes logs, connection.access_token
    refute session.to_hash.values.flatten.compact.any? { |value| value.to_s.include?(connection.access_token) }

    visit_home!
    assert_response :success
    assert_includes response.body, "Disconnect"
    assert_includes response.body, "Dropbox is connected. Disconnect any time."
    refute_includes response.body, "Connect Dropbox"
    refute_includes response.body, connection.access_token
  end

  test "disconnect removes the connection and home shows connect again" do
    follow_connect!
    connection = live_dropbox_connection

    delete recording_studio_oauth.outbound_connection_path(connection), params: { return_to: "/" }
    assert_redirected_to "/"
    assert_equal "revoked", connection.reload.status

    visit_home!
    assert_response :success
    assert_includes response.body, "Connect Dropbox"
  end

  test "home shows reconnect when Dropbox needs another look-in" do
    follow_connect!
    connection = live_dropbox_connection
    connection.update_columns(status: "needs_reconnect", updated_at: Time.current)

    visit_home!
    assert_response :success
    assert_includes response.body, "Reconnect Dropbox"
    assert_includes response.body, "Disconnect"
    assert_includes response.body, "Dropbox needs another look-in before we can copy files."
  end

  test "reconnect through oauth restores an active connection" do
    follow_connect!
    connection = live_dropbox_connection
    connection.update_columns(status: "needs_reconnect", updated_at: Time.current)

    follow_connect!
    assert_equal "active", connection.reload.status

    visit_home!
    assert_response :success
    assert_includes response.body, "Disconnect"
    refute_includes response.body, "Reconnect Dropbox"
  end

  private

  def visit_home!
    get "/"
  end

  def live_dropbox_connection
    RecordingStudioOauth::OutboundConnection.find_by!(
      provider_key: "dropbox",
      root_recording_id: @root.id
    )
  end

  def follow_connect!
    post recording_studio_oauth.outbound_connect_path(provider: "dropbox"), params: {
      owner: "root",
      root_recording_id: @root.id,
      return_to: "/"
    }
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
  end

  def capture_logs
    io = StringIO.new
    original = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end
end
