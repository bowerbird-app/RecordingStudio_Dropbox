# frozen_string_literal: true

require "test_helper"
require "generators/recording_studio_dropbox/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  INSTALL_TEMPLATE_PATH = File.expand_path(
    "../lib/generators/recording_studio_dropbox/install/templates/INSTALL.md",
    __dir__
  )

  def build_generator(destination_root, options = {})
    RecordingStudioDropbox::Generators::InstallGenerator.new(
      [],
      options,
      destination_root: destination_root
    )
  end

  def test_generator_does_not_mount_the_engine
    generator = build_generator("/tmp")

    refute_includes generator.class.instance_methods(false), :mount_engine
    refute_includes generator.class.instance_methods(false), :add_tailwind_source
    refute_includes generator.class.instance_methods(false), :add_yaml_config
    yaml_template = File.expand_path(
      "../lib/generators/recording_studio_dropbox/install/templates/recording_studio_dropbox.yml",
      __dir__
    )
    refute File.exist?(yaml_template)
    refute File.exist?(File.expand_path("../lib/generators/recording_studio_dropbox/install/INSTALL.md", __dir__))
    assert File.exist?(INSTALL_TEMPLATE_PATH)
  end

  def test_show_readme_displays_install_guide_for_invoke_behavior
    generator = build_generator("/tmp")
    shown_templates = []

    generator.stub(:behavior, :invoke) do
      generator.stub(:readme, ->(template) { shown_templates << template }) do
        generator.show_readme
      end
    end

    assert_equal ["INSTALL.md"], shown_templates
  end

  def test_install_guide_points_hosts_at_access_token
    install_guide = File.read(INSTALL_TEMPLATE_PATH)

    assert_includes install_guide, "RecordingStudioDropbox::OauthToken"
    assert_includes install_guide, "credentials.recording_studio_oauth.outbound.dropbox.client_id"
    assert_includes install_guide, "credentials.recording_studio_oauth.outbound.dropbox.client_secret"
    assert_includes install_guide, "client_id"
    assert_includes install_guide, "enabled"
    assert_includes install_guide, "files.metadata.read"
    refute_includes install_guide, "token provider"
    refute_includes install_guide, "RecordingStudio v3"
    refute_includes install_guide, "api_key"
    refute_includes install_guide, "tailwind"
  end
end
