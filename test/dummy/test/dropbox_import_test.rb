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
    @workspace = Workspace.find_by(name: "Studio Workspace") || Workspace.find_or_create_by!(name: "Studio Workspace")
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
    assert_includes response.body, "application/pdf"
    assert_includes response.body, "Import selected"
    refute_includes response.body, "Connect Dropbox"
    refute_includes response.body, "mimeType"
  end

  test "file-list page opens folders through the generic browser" do
    follow_connect!

    with_dropbox_client(listing_client) do
      get dropbox_imports_path
      assert_response :success
      assert_includes response.body, "Briefs"
      assert_includes response.body, "path=%2FBriefs"

      get dropbox_imports_path(path: "/Briefs")
    end

    assert_response :success
    assert_includes response.body, "Nested.pdf"
    assert_includes response.body, "/Briefs"
    assert_includes response.body, dropbox_imports_path
    refute_includes response.body, "Brief.pdf"
  end

  test "file-list page searches dropbox files" do
    follow_connect!

    with_dropbox_client(listing_client) do
      get dropbox_imports_path(query: "Brief.pdf")
    end

    assert_response :success
    assert_includes response.body, "Brief.pdf"
    refute_includes response.body, "Nested.pdf"
    refute_includes response.body, "Briefs"
  end

  test "file-list page follows a non-nil page token to the next page" do
    follow_connect!

    with_dropbox_client(listing_client) do
      get dropbox_imports_path
      assert_response :success
      assert_includes response.body, "Brief.pdf"
      assert_includes response.body, "page_token=page-2"

      get dropbox_imports_path(page_token: "page-2")
    end

    assert_response :success
    assert_includes response.body, "PageTwo.pdf"
    refute_includes response.body, "Brief.pdf"
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

  test "connected import copies multiple selected files into storage" do
    follow_connect!

    with_dropbox_client(import_client) do
      post dropbox_imports_path, params: { file_ids: ["id:file-1", "id:file-2"] }
    end

    assert_response :redirect
    imported = RecordingStudio::Recording.unscoped.where(
      parent_recording_id: @root.id,
      recordable_type: "RecordingStudioAttachable::Attachment"
    )
    names = imported.map { |recording| recording.recordable.original_filename }
    assert_includes names, "Brief.pdf"
    assert_includes names, "PageTwo.pdf"
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

    RecordingStudioDropbox::Attachable::Registration.stub(:chooser_access, nil) do
      get dropbox_bootstrap_path, as: :json
    end

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "test-dropbox-app-key", payload.fetch("client_id")
    assert_equal "dropbox", payload.fetch("provider_key")
    refute payload.fetch("needs_auth")
    assert payload.dig("connect", "url").present?
    assert_equal oauth_outbound_connect_path, payload.dig("connect", "url")
    assert payload.dig("connect", "fields", "authenticity_token").present?
    assert_nil payload["access_token"]
  end

  test "bootstrap returns a connect payload when reconnect is required" do
    follow_connect!

    RecordingStudioDropbox::Attachable::Registration.stub(
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
      post "/recording_studio_attachable/recordings/#{@root.id}/attachments/imports",
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

  def follow_connect!(owner: "root", root_recording_id: @root.id, return_to: dropbox_imports_path)
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
    RecordingStudioDropbox::Attachable::Registration.stub(:client, ->(**) { client }, &block)
  end

  def listing_client
    dropbox_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-1",
      name: "Brief.pdf",
      path: "/Brief.pdf",
      tag: "file",
      size: 12
    )
    dropbox_folder = RecordingStudioDropbox::Entry.new(
      id: "id:folder-1",
      name: "Briefs",
      path: "/Briefs",
      tag: "folder"
    )
    nested_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-2",
      name: "Nested.pdf",
      path: "/Briefs/Nested.pdf",
      tag: "file",
      size: 8
    )
    page_two_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-2",
      name: "PageTwo.pdf",
      path: "/PageTwo.pdf",
      tag: "file",
      size: 9
    )
    client = Object.new
    client.define_singleton_method(:list) do |path: "", cursor: nil, **|
      if cursor == "page-2"
        next RecordingStudioDropbox::Page.new(entries: [page_two_file], next_cursor: nil)
      end

      entries = path.to_s == "/Briefs" ? [nested_file] : [dropbox_folder, dropbox_file]
      next_cursor = path.to_s == "/Briefs" ? nil : "page-2"
      RecordingStudioDropbox::Page.new(entries: entries, next_cursor: next_cursor)
    end
    client.define_singleton_method(:search) do |query:, cursor: nil, **|
      _ = cursor
      matches = [dropbox_file, nested_file, page_two_file].select { |file| file.name.include?(query.to_s) }
      RecordingStudioDropbox::Page.new(entries: matches, next_cursor: nil)
    end
    client
  end

  def import_client
    files = {
      "id:file-1" => RecordingStudioDropbox::Entry.new(
        id: "id:file-1",
        name: "Brief.pdf",
        path: "/Brief.pdf",
        tag: "file",
        size: 12
      ),
      "/Brief.pdf" => RecordingStudioDropbox::Entry.new(
        id: "id:file-1",
        name: "Brief.pdf",
        path: "/Brief.pdf",
        tag: "file",
        size: 12
      ),
      "id:file-2" => RecordingStudioDropbox::Entry.new(
        id: "id:file-2",
        name: "PageTwo.pdf",
        path: "/PageTwo.pdf",
        tag: "file",
        size: 9
      )
    }
    downloads = {
      "id:file-1" => RecordingStudioDropbox::DownloadedFile.new(
        body: "%PDF-1.4\nbrief",
        filename: "Brief.pdf",
        content_type: nil
      ),
      "/Brief.pdf" => RecordingStudioDropbox::DownloadedFile.new(
        body: "%PDF-1.4\nbrief",
        filename: "Brief.pdf",
        content_type: nil
      ),
      "id:file-2" => RecordingStudioDropbox::DownloadedFile.new(
        body: "%PDF-1.4\npage-two",
        filename: "PageTwo.pdf",
        content_type: nil
      )
    }
    client = listing_client
    client.define_singleton_method(:fetch_file) { |path:| files.fetch(path) }
    client.define_singleton_method(:download) { |path:, **| downloads.fetch(path) }
    client
  end

  def authenticity_token
    css_select('input[name="authenticity_token"]').first&.[]("value") ||
      css_select('meta[name="csrf-token"]').first&.[]("content")
  end

  def oauth_outbound_connect_path
    RecordingStudioOauth::Engine.routes.url_helpers.outbound_connect_path(provider: "dropbox")
  end

  def dropbox_imports_path(path: nil, query: nil, page_token: nil)
    url = "/recording_studio_attachable/dropbox/recordings/#{@root.id}/imports"
    params = { path: path, query: query, page_token: page_token }.compact
    params.reject! { |_key, value| value.blank? }
    return url if params.blank?

    "#{url}?#{params.to_query}"
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
end
