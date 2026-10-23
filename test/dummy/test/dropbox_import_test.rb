# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DropboxImportTest < ActionDispatch::IntegrationTest
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
    @workspace = Workspace.first || Workspace.find_or_create_by!(name: "Studio Workspace")
    Current.actor = @user
    @root = RecordingStudio.root_recording_for(@workspace)
    grant_workspace_access!(@root)
  end

  teardown do
    Current.actor = nil if defined?(Current)
    FakeDropboxOauth.reset!
  end

  test "dropbox is registered and mounts under the attachable engine" do
    provider = RecordingStudioAttachable.configuration.upload_provider(:dropbox)

    assert_equal "Dropbox", provider.label
    assert_equal :client_picker, provider.strategy
    assert_equal "recording_studio_dropbox/dropbox_picker_launcher", provider.launcher_module
    assert Rails.application.routes.recognize_path(
      "/recording_studio_attachable/dropbox/recordings/#{@root.id}/bootstrap",
      method: :get
    )
  end

  test "dummy dropbox oauth uses the fake provider when credentials are absent" do
    provider = RecordingStudioOauth::Outbound.provider(:dropbox)

    assert_equal "/fake_oauth/authorize", provider.authorize_url
    assert_equal "/fake_oauth/token", provider.token_url
    assert_equal FakeDropboxOauth::CLIENT_ID, provider.client_id
    assert_equal FakeDropboxOauth, provider.http
    assert_equal "offline", provider.extra_authorize_params.fetch("token_access_type")
    assert_equal RecordingStudioDropbox::OauthProvider::SCOPES, provider.scopes
  end

  test "imports index shows connect when there is no Dropbox connection" do
    get dropbox_imports_path

    assert_response :success
    assert_includes response.body, "Connect Dropbox"
    assert_includes response.body, oauth_outbound_connect_path
    refute_includes response.body, "fake-access-"
    assert_nil session["recording_studio_attachable_dropbox"]
  end

  test "file-list page uses the generic remote file browser" do
    follow_connect!

    with_dropbox_client(listing_client) do
      get dropbox_imports_path
    end

    assert_response :success
    assert_includes response.body, "Brief.pdf"
    assert_includes response.body, "Import selected"
    refute_includes response.body, "Connect Dropbox"
  end

  test "connected import lists files and copies a selected file into storage" do
    follow_connect!

    with_dropbox_client(import_client) do
      get dropbox_imports_path
      assert_response :success
      assert_includes response.body, "Brief.pdf"

      post dropbox_imports_path, params: { file_ids: ["id:file-1"] }
    end

    assert_response :redirect
    imported = RecordingStudio::Recording.unscoped.where(
      parent_recording_id: @root.id,
      recordable_type: "RecordingStudioAttachable::Attachment"
    )
    assert imported.any? { |recording| recording.recordable.original_filename == "Brief.pdf" }
    assert_nil session["recording_studio_attachable_dropbox"]
    refute_includes response.body, "fake-access-"
  end

  test "imports index shows reconnect when the Dropbox gem requires it" do
    follow_connect!
    client = Object.new
    client.define_singleton_method(:list) do |**|
      raise RecordingStudioDropbox::ReconnectRequired, "Reconnect Dropbox"
    end

    with_dropbox_client(client) do
      get dropbox_imports_path
    end

    assert_response :success
    assert_includes response.body, "Reconnect Dropbox"
    assert_includes response.body, oauth_outbound_connect_path
  end

  test "create returns json unauthorized with connect payload when reconnect is required" do
    follow_connect!
    client = Object.new
    client.define_singleton_method(:fetch_file) do |*_args, **|
      raise RecordingStudioDropbox::ReconnectRequired, "Reconnect Dropbox"
    end

    with_dropbox_client(client) do
      post dropbox_imports_path, params: { file_ids: ["file-1"] }, as: :json
    end

    assert_response :unauthorized
    payload = JSON.parse(response.body)
    assert_includes payload.fetch("error"), "Reconnect"
    assert_equal "dropbox", payload.fetch("provider_key")
    assert payload.dig("connect", "url").present?
    assert_equal oauth_outbound_connect_path, payload.dig("connect", "url")
    assert_includes payload.dig("connect", "fields", "return_to").to_s, dropbox_connected_path
  end

  test "bootstrap returns chooser client_id when connected" do
    follow_connect!

    RecordingStudioDropbox::Attachable::Integration.stub(:chooser_access, "token-1") do
      get dropbox_bootstrap_path, as: :json
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "test-dropbox-app-key", payload.fetch("client_id")
    assert_equal "dropbox", payload.fetch("provider_key")
    refute payload.key?("connect")
    assert_nil payload["access_token"]
  end

  test "bootstrap returns a connect payload when reconnect is required" do
    follow_connect!

    RecordingStudioDropbox::Attachable::Integration.stub(
      :chooser_access,
      ->(*) { raise RecordingStudioDropbox::ReconnectRequired, "Reconnect Dropbox" }
    ) do
      get dropbox_bootstrap_path, as: :json
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert payload.fetch("needs_auth")
    assert payload.fetch("reconnect")
    assert_equal oauth_outbound_connect_path, payload.dig("connect", "url")
    assert_includes payload.dig("connect", "fallback_url").to_s, dropbox_connect_path
    assert_includes payload.dig("connect", "fallback_url").to_s, "popup=1"
    assert_nil payload["access_token"]
  end

  test "remote import reconnect maps through the shared imports endpoint" do
    follow_connect!
    client = Object.new
    client.define_singleton_method(:fetch_file) do |*_args, **|
      raise RecordingStudioDropbox::ReconnectRequired, "Reconnect Dropbox"
    end

    with_dropbox_client(client) do
      post recording_studio_attachable.recording_attachment_imports_path(@root),
           params: {
             attachment_import: {
               provider_key: "dropbox",
               attachments: [{ provider_payload: { id: "file-1" } }]
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    assert_includes payload.fetch("error"), "Reconnect"
    assert payload.dig("errors", "url").present?
  end

  test "upload page is reachable for the seeded workspace" do
    get recording_studio_attachable.recording_attachment_upload_path(@root)

    assert_response :success
    assert_includes response.body, "Dropbox"
  end

  private

  def follow_connect!(owner: "user", root_recording_id: nil, return_to: dropbox_imports_path)
    get dropbox_imports_path
    assert_response :success
    post oauth_outbound_connect_path, params: {
      authenticity_token: authenticity_token,
      owner: owner,
      root_recording_id: root_recording_id,
      return_to: return_to
    }.compact
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
    assert_response :redirect
    follow_redirect!
  end

  def with_dropbox_client(client, &block)
    RecordingStudioDropbox::Attachable::Integration.stub(:client, ->(**) { client }, &block)
  end

  def listing_client
    dropbox_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-1",
      name: "Brief.pdf",
      path: "/Brief.pdf",
      tag: "file",
      size: 12
    )
    client = Object.new
    client.define_singleton_method(:list) do |**|
      RecordingStudioDropbox::Page.new(entries: [dropbox_file], next_cursor: nil)
    end
    client
  end

  def import_client
    dropbox_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-1",
      name: "Brief.pdf",
      path: "/Brief.pdf",
      tag: "file",
      size: 12
    )
    downloaded = RecordingStudioDropbox::DownloadedFile.new(
      body: "%PDF-1.4\nbrief",
      filename: "Brief.pdf",
      content_type: nil
    )
    client = listing_client
    client.define_singleton_method(:fetch_file) { |path:| dropbox_file }
    client.define_singleton_method(:download) { |path:| downloaded }
    client
  end

  def authenticity_token
    css_select('input[name="authenticity_token"]').first&.[]("value") ||
      css_select('meta[name="csrf-token"]').first&.[]("content")
  end

  def oauth_outbound_connect_path
    RecordingStudioOauth::Engine.routes.url_helpers.outbound_connect_path(provider: "dropbox")
  end

  def dropbox_imports_path
    "/recording_studio_attachable/dropbox/recordings/#{@root.id}/imports"
  end

  def dropbox_connect_path
    "/recording_studio_attachable/dropbox/recordings/#{@root.id}/connect"
  end

  def dropbox_connected_path
    "/recording_studio_attachable/dropbox/recordings/#{@root.id}/connected"
  end

  def dropbox_bootstrap_path
    "/recording_studio_attachable/dropbox/recordings/#{@root.id}/bootstrap"
  end

  def grant_workspace_access!(root, actor: @user, role: :admin)
    original = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(**) { true }
    result = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: actor,
      role: role,
      manager_actor: @user
    )
    raise result.error if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = original
  end
end
