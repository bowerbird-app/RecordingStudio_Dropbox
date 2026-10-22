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
end
