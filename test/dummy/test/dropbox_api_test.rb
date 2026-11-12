# frozen_string_literal: true

require "test_helper"

class DropboxApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"
  MCP_TOOL_NAME = /\A[A-Za-z][A-Za-z0-9_.-]*\z/

  setup do
    @previous_actor = Current.actor
    @owner = create_user("owner")
    @editor = create_user("editor")
    @viewer = create_user("viewer")
    Current.actor = @owner
    @workspace = Workspace.create!(name: "API #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    bootstrap!(@root, @owner)
    @editor_access = grant!(@editor, :edit)
    @viewer_access = grant!(@viewer, :view)
    @editor_token = token_for(@editor_access)
    @viewer_token = token_for(@viewer_access)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "dropbox.import authorized copies files and a viewer is denied" do
    payload = nil
    with_dropbox_client(import_client) do
      payload = call(
        :post,
        "/dropbox/import",
        @editor_token,
        recording_id: @root.id,
        attachments: [{ "id" => "id:file-1", "name" => "Brief.pdf" }]
      )
    end

    assert_response :success, response.body
    attachments = payload.fetch("attachments")
    assert_equal 1, attachments.size
    assert_equal "Brief.pdf", attachments.first.fetch("name")
    assert RecordingStudio::Recording.find(attachments.first.fetch("id"))

    with_dropbox_client(import_client) do
      call(
        :post,
        "/dropbox/import",
        @viewer_token,
        recording_id: @root.id,
        attachments: [{ "id" => "id:file-1", "name" => "Brief.pdf" }]
      )
    end
    assert_response :forbidden
    assert_equal "forbidden", JSON.parse(response.body).dig("error", "code")
  end

  test "dropbox.list and dropbox.search authorized succeed and a viewer is denied" do
    with_dropbox_client(listing_client) do
      listed = call(:get, "/dropbox/list", @editor_token, recording_id: @root.id)
      assert_response :success, response.body
      names = listed.fetch("entries").map { |entry| entry.fetch("name") }
      assert_includes names, "Brief.pdf"
      assert_includes names, "Briefs"

      searched = call(:get, "/dropbox/search", @editor_token, recording_id: @root.id, query: "Brief")
      assert_response :success, response.body
      assert_equal %w[Brief.pdf], searched.fetch("entries").map { |entry| entry.fetch("name") }
    end

    with_dropbox_client(listing_client) do
      call(:get, "/dropbox/list", @viewer_token, recording_id: @root.id)
    end
    assert_response :forbidden
    assert_equal "forbidden", JSON.parse(response.body).dig("error", "code")

    with_dropbox_client(listing_client) do
      call(:get, "/dropbox/search", @viewer_token, recording_id: @root.id, query: "Brief")
    end
    assert_response :forbidden
  end

  test "each dropbox endpoint is an MCP tool and excluded operations stay off the catalog" do
    %i[public].each do |api|
      %w[dropbox.import dropbox.list dropbox.search].each do |name|
        endpoint = RecordingStudioApi.registered_endpoint(name, api: api)
        assert endpoint, "expected #{name} on #{api}"
        assert_match MCP_TOOL_NAME, endpoint.name
        assert_match(/\ADropbox - /, endpoint.openapi.fetch(:title))
        assert_equal endpoint.openapi.fetch(:title), endpoint.openapi.fetch(:summary)
      end
    end

    RecordingStudioDropbox::Api::Registration::EXCLUDED_ENDPOINT_NAMES.each do |name|
      refute RecordingStudioApi.registered_endpoint(name, api: :public), name
      refute RecordingStudioApi.capability_action(name.to_sym, api: :public) if RecordingStudioApi.respond_to?(:capability_action)
    end

    if defined?(RecordingStudioMcp) && RecordingStudioMcp.respond_to?(:tools)
      tool_names = Array(RecordingStudioMcp.tools).map { |tool| tool.respond_to?(:name) ? tool.name : tool.to_s }
      assert_includes tool_names, "dropbox.import"
      assert_includes tool_names, "dropbox.list"
      assert_includes tool_names, "dropbox.search"
      RecordingStudioDropbox::Api::Registration::EXCLUDED_ENDPOINT_NAMES.each do |name|
        refute_includes tool_names, name
      end
    end
  end

  private

  def create_user(label)
    User.create!(
      email: "#{label}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def bootstrap!(recording, actor)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    raise result.error if result.failure?

    result.value
  end

  def grant!(actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: access_recording.parent_recording || access_recording.root_recording,
      manager_actor: @owner,
      role: access_recording.recordable.role,
      name: "Client #{SecureRandom.hex(3)}"
    )
    raise provision.error unless provision.success?

    issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise issued.error unless issued.success?

    issued.value.fetch(:access_token)
  end

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params: params, headers: headers(token), as: :json)
    parse_json
  end

  def headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def parse_json
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def with_dropbox_client(client, &block)
    RecordingStudioDropbox::Attachable::Registration.stub(:client, ->(**) { client }, &block)
  end

  def listing_client
    dropbox_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-1", name: "Brief.pdf", path: "/Brief.pdf", tag: "file", size: 12
    )
    dropbox_folder = RecordingStudioDropbox::Entry.new(
      id: "id:folder-1", name: "Briefs", path: "/Briefs", tag: "folder"
    )
    client = Object.new
    client.define_singleton_method(:list) do |**|
      RecordingStudioDropbox::Page.new(entries: [dropbox_folder, dropbox_file], next_cursor: nil)
    end
    client.define_singleton_method(:search) do |query:, **|
      matches = [dropbox_file].select { |file| file.name.include?(query.to_s) }
      RecordingStudioDropbox::Page.new(entries: matches, next_cursor: nil)
    end
    client
  end

  def import_client
    client = listing_client
    files = {
      "id:file-1" => RecordingStudioDropbox::Entry.new(
        id: "id:file-1", name: "Brief.pdf", path: "/Brief.pdf", tag: "file", size: 12
      )
    }
    downloads = {
      "id:file-1" => RecordingStudioDropbox::DownloadedFile.new(
        body: "%PDF-1.4\nbrief", filename: "Brief.pdf", content_type: nil
      )
    }
    client.define_singleton_method(:fetch_file) { |path:| files.fetch(path) }
    client.define_singleton_method(:download) { |path:, **| downloads.fetch(path) }
    client
  end
end
