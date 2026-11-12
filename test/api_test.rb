# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"
require "recording_studio_attachable"
require "recording_studio_dropbox/api"
require "recording_studio_dropbox/attachable/import"

class ApiTest < Minitest::Test
  FakeContext = Struct.new(:access_grant, :params, :authorized_by, keyword_init: true)
  FakeGrant = Struct.new(:actor, keyword_init: true)
  FakeResult = Struct.new(:success, :error, :value, keyword_init: true) do
    def success?
      success
    end
  end
  FakeRecording = Struct.new(:id, :recordable, keyword_init: true)
  FakeAttachment = Struct.new(:name, :attachment_kind, keyword_init: true)
  FakeEndpoint = Struct.new(
    :name, :api, :http_verb, :path, :handler, :openapi, :input_contract,
    keyword_init: true
  )

  def test_gemspec_omits_recording_studio_api_runtime_dependency
    gemspec = File.read(File.expand_path("../recording_studio_dropbox.gemspec", __dir__))

    refute_includes gemspec, '"recording_studio_api"'
  end

  def test_engine_registers_api_when_api_and_attachable_are_loaded
    engine = File.read(File.expand_path("../lib/recording_studio_dropbox/engine.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_dropbox.api"'
    assert_includes engine, "defined?(RecordingStudioApi)"
    assert_includes engine, "defined?(RecordingStudioAttachable)"
    assert_includes engine, "RecordingStudioDropbox::Api.register!"
  end

  def test_registers_import_list_and_search
    captured = capture_registrations { RecordingStudioDropbox::Api.register! }

    names = captured.map(&:name)
    assert_equal %i[dropbox.import dropbox.list dropbox.search], names
    assert(captured.all? { |endpoint| endpoint.api == :public })
    assert_equal %i[post get get], captured.map(&:http_verb)
    assert_equal %w[dropbox/import dropbox/list dropbox/search], captured.map(&:path)
    assert_equal(
      [RecordingStudioDropbox::Api::Import, RecordingStudioDropbox::Api::List, RecordingStudioDropbox::Api::Search],
      captured.map(&:handler)
    )
  end

  def test_registered_openapi_uses_dropbox_type_first_titles
    captured = capture_registrations { RecordingStudioDropbox::Api.register! }

    captured.each do |endpoint|
      assert_equal ["Dropbox"], endpoint.openapi.fetch(:tags)
      title = endpoint.openapi.fetch(:title)
      assert_match(/\ADropbox - /, title)
      assert_equal title, endpoint.openapi.fetch(:summary)
      assert endpoint.openapi.fetch(:description).present?
    end
  end

  def test_excluded_operations_are_not_registered
    captured = capture_registrations { RecordingStudioDropbox::Api.register! }
    names = captured.map { |endpoint| endpoint.name.to_s }

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

  def test_authorized_uses_attachable_upload_allowed
    recording = Object.new
    actor = Object.new
    context = FakeContext.new(access_grant: FakeGrant.new(actor: actor), params: {})
    seen = nil
    check = lambda do |action:, actor:, recording:|
      seen = [action, actor, recording]
      action == :upload
    end

    RecordingStudioAttachable::Authorization.stub(:allowed?, check) do
      assert RecordingStudioDropbox::Api::Access.authorized?(context, recording: recording)
    end
    assert_equal [:upload, actor, recording], seen
  end

  def test_authorized_denies_a_blank_actor_or_recording
    context = FakeContext.new(access_grant: FakeGrant.new(actor: nil), params: {})

    refute RecordingStudioDropbox::Api::Access.authorized?(context, recording: Object.new)
    refute RecordingStudioDropbox::Api::Access.authorized?(
      FakeContext.new(access_grant: FakeGrant.new(actor: Object.new), params: {}),
      recording: nil
    )
  end

  def test_import_authorized_wraps_remote_files_with_picker_file_ids
    recording = FakeRecording.new(id: "rec-1", recordable: nil)
    imported = FakeRecording.new(
      id: "att-1",
      recordable: FakeAttachment.new(name: "Brief.pdf", attachment_kind: "file")
    )
    called = nil
    context = FakeContext.new(
      access_grant: FakeGrant.new(actor: :editor),
      params: { attachments: [{ id: "id:file-1" }, "id:file-2"] },
      authorized_by: :manager
    )

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
    assert_equal %w[id:file-1 id:file-2], called[:attachments]
    assert_equal :editor, called[:actor]
    assert_equal :manager, called[:impersonator]
  end

  def test_import_unauthorized_does_not_call_remote_files
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

  def test_errors_wrap_maps_reconnect_to_authentication_and_request_failures
    reconnect = assert_raises(RecordingStudioApi::AuthenticationError) do
      RecordingStudioDropbox::Api::Errors.wrap { raise RecordingStudioDropbox::ReconnectRequired, "reconnect Dropbox" }
    end
    request = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioDropbox::Api::Errors.wrap { raise RecordingStudioDropbox::RequestError.new("nope", status: 500) }
    end

    assert_equal "reconnect Dropbox", reconnect.message
    assert_equal "nope", request.message
  end

  def test_import_maps_a_failed_remote_files_result
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

  def capture_registrations(&block)
    captured = []
    register = lambda do |name, **options|
      captured << FakeEndpoint.new(name: name, **options.slice(*FakeEndpoint.members))
    end

    RecordingStudioApi.stub(:registered_endpoint, nil) do
      RecordingStudioApi.stub(:register_endpoint, register, &block)
    end
    captured
  end
end
