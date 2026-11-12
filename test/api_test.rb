# frozen_string_literal: true

require "test_helper"
require "recording_studio_dropbox/api"
require "recording_studio_dropbox/attachable/import"

class ApiTest < Minitest::Test
  FakeEndpoint = Struct.new(
    :name, :api, :http_verb, :path, :handler, :openapi, :input_contract,
    keyword_init: true
  )
  FakeContext = Struct.new(:access_grant, :params, :authorized_by, keyword_init: true)
  FakeGrant = Struct.new(:actor, keyword_init: true)
  FakeResult = Struct.new(:success, :error, :value, keyword_init: true) do
    def success?
      success
    end
  end
  FakeRecording = Struct.new(:id, :recordable, keyword_init: true)
  FakeAttachment = Struct.new(:name, :attachment_kind, keyword_init: true)

  def teardown
    remove_fake_api!
  end

  def test_gemspec_omits_recording_studio_api_runtime_dependency
    gemspec = File.read(File.expand_path("../recording_studio_dropbox.gemspec", __dir__))

    refute_includes gemspec, '"recording_studio_api"'
  end

  def test_engine_registers_api_in_to_prepare
    engine = File.read(File.expand_path("../lib/recording_studio_dropbox/engine.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_dropbox.api"'
    assert_includes engine, "RecordingStudioDropbox::Api.register!"
  end

  def test_registration_is_a_noop_without_recording_studio_api
    RecordingStudioDropbox::Api.stub(:recording_studio_api_available?, false) do
      RecordingStudioDropbox::Api.stub(:attachable_available?, true) do
        assert_nil RecordingStudioDropbox::Api.register!
      end
    end
  end

  def test_registration_is_a_noop_without_attachable
    install_fake_api!
    RecordingStudioDropbox::Api.stub(:attachable_available?, false) do
      assert_nil RecordingStudioDropbox::Api.register!
    end
    assert_empty RecordingStudioApi.endpoints
  end

  def test_registers_import_list_and_search
    api = install_fake_api!
    RecordingStudioDropbox::Api.stub(:attachable_available?, true) do
      assert RecordingStudioDropbox::Api.register!
    end

    names = api.endpoints.map(&:name)
    assert_equal %i[dropbox.import dropbox.list dropbox.search], names
    assert(api.endpoints.all? { |endpoint| endpoint.api == :public })
    assert_equal %i[post get get], api.endpoints.map(&:http_verb)
    assert_equal %w[dropbox/import dropbox/list dropbox/search], api.endpoints.map(&:path)
    assert_equal(
      [RecordingStudioDropbox::Api::Import, RecordingStudioDropbox::Api::List, RecordingStudioDropbox::Api::Search],
      api.endpoints.map(&:handler)
    )
  end

  def test_registered_openapi_uses_dropbox_type_first_titles
    api = install_fake_api!
    RecordingStudioDropbox::Api.stub(:attachable_available?, true) do
      RecordingStudioDropbox::Api.register!
    end

    api.endpoints.each do |endpoint|
      assert_equal ["Dropbox"], endpoint.openapi.fetch(:tags)
      title = endpoint.openapi.fetch(:title)
      assert_match(/\ADropbox - /, title)
      assert_equal title, endpoint.openapi.fetch(:summary)
      assert endpoint.openapi.fetch(:description).present?
    end
  end

  def test_excluded_operations_are_not_registered
    api = install_fake_api!
    RecordingStudioDropbox::Api.stub(:attachable_available?, true) do
      RecordingStudioDropbox::Api.register!
    end

    names = api.endpoints.map { |endpoint| endpoint.name.to_s }
    RecordingStudioDropbox::Api::Registration::EXCLUDED_ENDPOINT_NAMES.each do |name|
      refute_includes names, name
    end
  end

  def test_mcp_tool_names_match_registered_endpoints_and_exclude_hidden_operations
    names = RecordingStudioDropbox::Api::Registration::ENDPOINTS.map { |endpoint| endpoint.fetch(:name).to_s }

    assert_equal %w[dropbox.import dropbox.list dropbox.search], names
    names.each do |name|
      assert_match(/\A[A-Za-z][A-Za-z0-9_.-]*\z/, name)
    end
    RecordingStudioDropbox::Api::Registration::EXCLUDED_ENDPOINT_NAMES.each do |name|
      refute_includes names, name
    end
  end

  def test_api_authorize_uses_attachable_upload_allowed
    recording = Object.new
    actor = Object.new
    context = FakeContext.new(access_grant: FakeGrant.new(actor: actor), params: {})
    seen = nil
    check = lambda do |action:, actor:, recording:|
      seen = [action, actor, recording]
      action == :upload
    end

    with_attachable_authorization(check) do
      assert RecordingStudioDropbox::Api::Access.api_authorize.call(context, recording: recording)
      assert RecordingStudioDropbox::Api::Access.authorized?(context, recording: recording)
    end
    assert_equal [:upload, actor, recording], seen
  end

  def test_api_authorize_denies_a_blank_actor_or_recording
    context = FakeContext.new(access_grant: FakeGrant.new(actor: nil), params: {})

    refute RecordingStudioDropbox::Api::Access.authorized?(context, recording: Object.new)
    refute RecordingStudioDropbox::Api::Access.authorized?(
      FakeContext.new(access_grant: FakeGrant.new(actor: Object.new), params: {}),
      recording: nil
    )
  end

  def test_import_authorized_wraps_remote_files
    recording = FakeRecording.new(id: "rec-1", recordable: nil)
    imported = FakeRecording.new(
      id: "att-1",
      recordable: FakeAttachment.new(name: "Brief.pdf", attachment_kind: "file")
    )
    called = nil
    context = FakeContext.new(
      access_grant: FakeGrant.new(actor: :editor),
      params: { attachments: [{ id: "id:file-1" }] },
      authorized_by: :manager
    )

    ensure_api_errors!
    RecordingStudioDropbox::Api::Access.stub(:recording_for!, recording) do
      RecordingStudioDropbox::Attachable::Import.stub(
        :remote_files,
        lambda do |**kwargs|
          called = kwargs
          FakeResult.new(success: true, value: [imported])
        end
      ) do
        payload = RecordingStudioDropbox::Api::Import.call(context)
        assert_equal [{ id: "att-1", name: "Brief.pdf", kind: "file" }], payload.fetch(:attachments)
      end
    end
    assert_equal recording, called[:parent_recording]
    assert_equal [{ id: "id:file-1" }], called[:attachments]
    assert_equal :editor, called[:actor]
    assert_equal :manager, called[:impersonator]
  end

  def test_import_unauthorized_does_not_call_remote_files
    ensure_api_errors!
    context = FakeContext.new(
      access_grant: FakeGrant.new(actor: :viewer),
      params: { recording_id: "rec-1", attachments: [{ id: "id:file-1" }] }
    )
    called = false
    deny = lambda do |*|
      raise RecordingStudioApi::AuthorizationError, RecordingStudioDropbox::Api::Access::DENIED_MESSAGE
    end

    RecordingStudioDropbox::Api::Access.stub(:recording_for!, deny) do
      RecordingStudioDropbox::Attachable::Import.stub(:remote_files, ->(**) { called = true }) do
        error = assert_raises(RecordingStudioApi::AuthorizationError) do
          RecordingStudioDropbox::Api::Import.call(context)
        end
        assert_equal RecordingStudioDropbox::Api::Access::DENIED_MESSAGE, error.message
      end
    end
    refute called
  end

  def test_list_and_search_authorized_wrap_the_client
    ensure_api_errors!
    recording = FakeRecording.new(id: "rec-1")
    entry = RecordingStudioDropbox::Entry.new(id: "id:1", name: "Brief.pdf", path: "/Brief.pdf", tag: "file", size: 12)
    page = RecordingStudioDropbox::Page.new(entries: [entry], next_cursor: "next")
    client = Object.new
    listed = nil
    searched = nil
    client.define_singleton_method(:list) do |**kwargs|
      listed = kwargs
      page
    end
    client.define_singleton_method(:search) do |**kwargs|
      searched = kwargs
      page
    end

    RecordingStudioDropbox::Api::Access.stub(:recording_for!, recording) do
      RecordingStudioDropbox::Api::Access.stub(:client_for, client) do
        listed_payload = RecordingStudioDropbox::Api::List.call(
          FakeContext.new(params: { path: "/Briefs", cursor: nil, page_size: 10 })
        )
        searched_payload = RecordingStudioDropbox::Api::Search.call(
          FakeContext.new(params: { query: "Brief", cursor: nil, page_size: 5 })
        )

        expected = {
          entries: [{ id: "id:1", name: "Brief.pdf", path: "/Brief.pdf", folder: false, size: 12 }],
          next_cursor: "next"
        }
        assert_equal expected, listed_payload
        assert_equal expected, searched_payload
      end
    end
    assert_equal({ path: "/Briefs", cursor: nil, page_size: 10 }, listed)
    assert_equal({ query: "Brief", cursor: nil, page_size: 5 }, searched)
  end

  def test_errors_wrap_maps_reconnect_and_request_failures
    ensure_api_errors!
    reconnect = assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioDropbox::Api::Errors.wrap { raise RecordingStudioDropbox::ReconnectRequired, "reconnect Dropbox" }
    end
    request = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioDropbox::Api::Errors.wrap { raise RecordingStudioDropbox::RequestError.new("nope", status: 500) }
    end

    assert_equal "reconnect Dropbox", reconnect.message
    assert_equal "nope", request.message
  end

  def test_import_maps_a_failed_remote_files_result
    ensure_api_errors!
    RecordingStudioDropbox::Api::Access.stub(:recording_for!, FakeRecording.new(id: "rec-1")) do
      RecordingStudioDropbox::Attachable::Import.stub(
        :remote_files,
        ->(**) { FakeResult.new(success: false, error: "Select at least one file") }
      ) do
        error = assert_raises(RecordingStudioApi::InvalidActionInputError) do
          RecordingStudioDropbox::Api::Import.call(FakeContext.new(params: { attachments: [] }))
        end
        assert_equal "Select at least one file", error.message
      end
    end
  end

  def test_list_unauthorized_does_not_call_the_client
    ensure_api_errors!
    called = false
    context = FakeContext.new(
      access_grant: FakeGrant.new(actor: :viewer),
      params: { recording_id: "rec-1" }
    )
    deny = lambda do |*|
      raise RecordingStudioApi::AuthorizationError, RecordingStudioDropbox::Api::Access::DENIED_MESSAGE
    end

    RecordingStudioDropbox::Api::Access.stub(:recording_for!, deny) do
      RecordingStudioDropbox::Api::Access.stub(:client_for, ->(**) { called = true }) do
        assert_raises(RecordingStudioApi::AuthorizationError) do
          RecordingStudioDropbox::Api::List.call(context)
        end
      end
    end
    refute called
  end

  private

  def ensure_api_errors!
    return if defined?(RecordingStudioApi::AuthorizationError)

    install_fake_api!
  end

  def install_fake_api!
    api = Module.new
    api.const_set(:AuthorizationError, Class.new(StandardError))
    api.const_set(:NotFoundError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, Class.new(StandardError))
    endpoints = []
    api.define_singleton_method(:endpoints) { endpoints }
    api.define_singleton_method(:register_endpoint) do |name, **options|
      endpoints << FakeEndpoint.new(name: name, **options.slice(*FakeEndpoint.members))
    end
    api.define_singleton_method(:registered_endpoint) do |name, api: :public|
      endpoints.find { |endpoint| endpoint.name == name && endpoint.api == api }
    end
    Object.const_set(:RecordingStudioApi, api)
    api
  end

  def remove_fake_api!
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
  end

  def with_attachable_authorization(check, &)
    created_attachable = false
    created_authorization = false
    unless defined?(RecordingStudioAttachable)
      Object.const_set(:RecordingStudioAttachable, Module.new)
      created_attachable = true
    end
    unless RecordingStudioAttachable.const_defined?(:Authorization, false)
      RecordingStudioAttachable.const_set(:Authorization, Module.new)
      created_authorization = true
    end
    RecordingStudioAttachable::Authorization.stub(:allowed?, check, &)
  ensure
    if created_authorization && RecordingStudioAttachable.const_defined?(:Authorization, false)
      RecordingStudioAttachable.send(:remove_const, :Authorization)
    end
    Object.send(:remove_const, :RecordingStudioAttachable) if created_attachable
  end
end
