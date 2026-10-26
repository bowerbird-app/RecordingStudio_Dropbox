# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    RecordingStudioDropbox.configure
    RecordingStudioDropbox.configuration.hooks.clear!
  end

  def teardown
    RecordingStudioDropbox.configuration.hooks.clear!
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioDropbox.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioDropbox.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_dropbox.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_dropbox.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudioDropbox.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    find_initializer("recording_studio_dropbox.load_config").block.call(Object.new)

    assert hook_called
    assert_equal RecordingStudioDropbox.configuration, hook_payload
  end

  def test_load_config_does_not_read_yaml_or_config_x
    source = File.read(File.expand_path("../lib/recording_studio_dropbox/engine.rb", __dir__))

    refute_includes source, "config_for"
    refute_includes source, "RuntimeError"
    refute_includes source, "merge!"
    assert_includes source, 'Gem::Version.new("0.21.0")'
  end

  def test_engine_does_not_apply_host_extensions
    refute RecordingStudioDropbox::Engine.respond_to?(:apply_model_extensions)
    refute RecordingStudioDropbox::Engine.respond_to?(:apply_controller_extensions)
    names = RecordingStudioDropbox::Engine.initializers.map(&:name)
    refute_includes names, "recording_studio_dropbox.apply_model_extensions"
    refute_includes names, "recording_studio_dropbox.apply_controller_extensions"
    refute_includes names, "recording_studio_dropbox.register_oauth_provider"
    source = File.read(File.expand_path("../lib/recording_studio_dropbox/engine.rb", __dir__))
    refute_includes source, "register_oauth_provider"
    refute_includes source, "register_outbound_provider"
    assert_includes source, "isolate_namespace RecordingStudioDropbox"
  end

  private

  def find_initializer(name)
    RecordingStudioDropbox::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
