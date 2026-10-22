# frozen_string_literal: true

require "test_helper"

class ContractTest < Minitest::Test
  def test_access_token_is_the_public_token_type
    refute defined?(RecordingStudioDropbox::TokenProvider)
    assert_equal [%i[req provider]], RecordingStudioDropbox::AccessToken.instance_method(:initialize).parameters
    assert RecordingStudioDropbox::AccessToken.method_defined?(:to_s)
    assert_equal(
      [%i[keyreq root], %i[keyreq actor], %i[key provider]],
      RecordingStudioDropbox::OauthToken.instance_method(:initialize).parameters
    )
    assert RecordingStudioDropbox::OauthToken.method_defined?(:call)
    assert RecordingStudioDropbox::OauthToken.method_defined?(:access_token)
    assert_respond_to RecordingStudioDropbox, :register_oauth_provider
  end

  def test_error_classes
    assert RecordingStudioDropbox::Error < StandardError
    assert RecordingStudioDropbox::ReconnectRequired < RecordingStudioDropbox::Error
    assert RecordingStudioDropbox::RequestError < RecordingStudioDropbox::Error
    refute defined?(RecordingStudioDropbox::ApiError)
    assert_equal(
      [%i[opt message], %i[key status], %i[key code]],
      RecordingStudioDropbox::RequestError.instance_method(:initialize).parameters
    )
    error = RecordingStudioDropbox::RequestError.new("path/not_found/..", status: 409, code: "path")
    assert_equal "path/not_found/..", error.message
    assert_equal 409, error.status
    assert_equal "path", error.code
  end

  def test_page_shape
    refute defined?(RecordingStudioDropbox::Listing)
    assert_equal %i[entries next_cursor], RecordingStudioDropbox::Page.members
    page = RecordingStudioDropbox::Page.new(entries: [], next_cursor: nil)
    assert_equal [], page.entries
    assert_nil page.next_cursor
    refute page.more?
    refute RecordingStudioDropbox::Page.new(entries: [], next_cursor: "").more?
    assert RecordingStudioDropbox::Page.new(entries: [], next_cursor: :more).more?
  end

  def test_downloaded_file_shape
    assert_equal %i[body filename content_type], RecordingStudioDropbox::DownloadedFile.members
    file = RecordingStudioDropbox::DownloadedFile.new(body: "x", filename: "a.pdf", content_type: "application/pdf")
    assert_equal "x", file.body
    assert_equal "a.pdf", file.filename
    assert_equal "application/pdf", file.content_type
    assert_nil RecordingStudioDropbox::DownloadedFile.new(body: "x", filename: "a.pdf", content_type: nil).content_type
    refute file.respond_to?(:bytes)
  end

  def test_client_signatures
    client = RecordingStudioDropbox::Client
    assert_equal [%i[keyreq token_provider]], client.instance_method(:initialize).parameters
    assert_equal(
      [%i[key path], %i[key cursor], %i[key page_size]],
      client.instance_method(:list).parameters
    )
    assert_equal(
      [%i[keyreq query], %i[key cursor], %i[key page_size]],
      client.instance_method(:search).parameters
    )
    refute_includes client.instance_method(:search).parameters, %i[key path]
    refute_includes client.instance_method(:search).parameters, %i[keyreq path]
    assert_equal [%i[keyreq path]], client.instance_method(:fetch_file).parameters
    assert_equal [%i[keyreq path]], client.instance_method(:download).parameters
    assert_equal(
      [%i[keyreq path], %i[keyreq io], %i[key chunk_size]],
      client.instance_method(:upload_file).parameters,
      "Dropbox upload_file omits content_type:; Google Drive requires it because Drive sends a MIME type"
    )
    refute_includes client.instance_method(:upload_file).parameters.flatten, :content_type
    refute_includes client.instance_method(:upload_file).parameters.flatten, :content
    refute client.method_defined?(:list_folder)
    refute client.method_defined?(:metadata)
  end

  def test_configure_returns_configuration
    result = RecordingStudioDropbox.configure

    assert_same RecordingStudioDropbox.configuration, result
  end
end
