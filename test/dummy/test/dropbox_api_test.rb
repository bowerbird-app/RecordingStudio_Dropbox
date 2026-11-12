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
      refute RecordingStudioApi.capability_action(name.to_sym, api: :public), name
    end
  end

  test "dropbox.list and dropbox.search pass the next_cursor into the second page" do
    with_dropbox_client(paging_client) do
      listed = call(:get, "/dropbox/list", @editor_token, recording_id: @root.id, page_size: 1)
      assert_response :success, response.body
      assert_equal %w[Brief.pdf], listed.fetch("entries").map { |entry| entry.fetch("name") }
      assert_equal "list-page-2", listed.fetch("next_cursor")

      listed_next = call(
        :get, "/dropbox/list", @editor_token, recording_id: @root.id, cursor: listed.fetch("next_cursor")
      )
      assert_response :success, response.body
      assert_equal %w[Notes.txt], listed_next.fetch("entries").map { |entry| entry.fetch("name") }
      assert_nil listed_next["next_cursor"]

      searched = call(:get, "/dropbox/search", @editor_token, recording_id: @root.id, query: "Brief", page_size: 1)
      assert_response :success, response.body
      assert_equal %w[Brief.pdf], searched.fetch("entries").map { |entry| entry.fetch("name") }
      assert_equal "search-page-2", searched.fetch("next_cursor")

      searched_next = call(
        :get,
        "/dropbox/search",
        @editor_token,
        recording_id: @root.id,
        query: "Brief",
        cursor: searched.fetch("next_cursor")
      )
      assert_response :success, response.body
      assert_equal %w[Briefs.doc], searched_next.fetch("entries").map { |entry| entry.fetch("name") }
      assert_nil searched_next["next_cursor"]
    end
  end

  test "each dropbox endpoint returns 401 without a token" do
    call(:post, "/dropbox/import", nil, recording_id: @root.id, attachments: [{ "id" => "id:file-1" }])
    assert_response :unauthorized

    call(:get, "/dropbox/list", nil, recording_id: @root.id)
    assert_response :unauthorized

    call(:get, "/dropbox/search", nil, recording_id: @root.id, query: "Brief")
    assert_response :unauthorized
  end

  test "a Dropbox reconnect is 401" do
    client = Object.new
    client.define_singleton_method(:list) do |**|
      raise RecordingStudioDropbox::ReconnectRequired, "reconnect Dropbox"
    end

    with_dropbox_client(client) do
      call(:get, "/dropbox/list", @editor_token, recording_id: @root.id)
    end
    assert_response :unauthorized
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
    accept = { "Accept" => "application/json" }
    token.present? ? accept.merge("Authorization" => "Bearer #{token}") : accept
  end

  def parse_json
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end

  def with_dropbox_client(client, &block)
    RecordingStudioDropbox::Attachable::Registration.stub(:client, ->(**) { client }, &block)
  end

  def paging_client
    page1_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-1", name: "Brief.pdf", path: "/Brief.pdf", tag: "file", size: 12
    )
    page2_file = RecordingStudioDropbox::Entry.new(
      id: "id:file-2", name: "Notes.txt", path: "/Notes.txt", tag: "file", size: 8
    )
    search_page2 = RecordingStudioDropbox::Entry.new(
      id: "id:file-3", name: "Briefs.doc", path: "/Briefs.doc", tag: "file", size: 9
    )
    client = Object.new
    client.define_singleton_method(:list) do |cursor: nil, **|
      if cursor == "list-page-2"
        RecordingStudioDropbox::Page.new(entries: [page2_file], next_cursor: nil)
      else
        RecordingStudioDropbox::Page.new(entries: [page1_file], next_cursor: "list-page-2")
      end
    end
    client.define_singleton_method(:search) do |cursor: nil, **|
      if cursor == "search-page-2"
        RecordingStudioDropbox::Page.new(entries: [search_page2], next_cursor: nil)
      else
        RecordingStudioDropbox::Page.new(entries: [page1_file], next_cursor: "search-page-2")
      end
    end
    client
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
