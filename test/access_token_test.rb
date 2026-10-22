# frozen_string_literal: true

require "test_helper"

class AccessTokenTest < Minitest::Test
  def test_reads_a_callable_first
    source = Object.new
    source.define_singleton_method(:call) { "from-call" }
    source.define_singleton_method(:access_token) { "from-access-token" }

    assert_equal "from-call", RecordingStudioDropbox::AccessToken.new(source).to_s
  end

  def test_reads_access_token_when_call_is_missing
    source = Object.new
    source.define_singleton_method(:access_token) { "from-object" }

    assert_equal "from-object", RecordingStudioDropbox::AccessToken.new(source).to_s
  end

  def test_blank_token_raises_reconnect_required
    error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
      RecordingStudioDropbox::AccessToken.new(-> { "  " }).to_s
    end

    assert_equal "Dropbox access token is blank", error.message
  end

  def test_nil_token_raises_reconnect_required
    error = assert_raises(RecordingStudioDropbox::ReconnectRequired) do
      RecordingStudioDropbox::AccessToken.new(-> {}).to_s
    end

    assert_equal "Dropbox access token is blank", error.message
  end

  def test_string_provider_raises_argument_error
    error = assert_raises(ArgumentError) { RecordingStudioDropbox::AccessToken.new("sl.token") }

    assert_equal "Dropbox access tokens cannot be a raw string", error.message
    refute_includes error.message, "sl.token"
  end

  def test_provider_without_call_or_access_token_raises_argument_error
    error = assert_raises(ArgumentError) { RecordingStudioDropbox::AccessToken.new(Object.new) }

    assert_equal "Dropbox access token provider must respond to call or access_token", error.message
  end
end
