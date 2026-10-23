# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioDropbox::Configuration.new
  end

  def test_initialize_exposes_recording_studio_hooks
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
    refute_respond_to @configuration, :merge!
    refute_respond_to @configuration, :to_h
  end

  def test_configure_without_block_is_safe
    result = RecordingStudioDropbox.configure

    assert_same RecordingStudioDropbox.configuration, result
    assert_kind_of RecordingStudioDropbox::Configuration, result
  end

  def test_attachable_add_on_defaults_to_off_until_an_app_key_is_set
    refute_predicate @configuration, :enabled?
    refute_predicate @configuration, :chooser_configured?
    refute_predicate @configuration, :available?

    @configuration.enabled = true
    @configuration.client_id = "dummy-dropbox-client-id"
    refute_predicate @configuration, :available?

    @configuration.client_id = "real-dropbox-app-key"
    assert_predicate @configuration, :available?
    assert_equal 25, @configuration.page_size
  end
end
