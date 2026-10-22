# frozen_string_literal: true

require "test_helper"

class NoCredentialsTest < ActiveSupport::TestCase
  test "dummy does not ship encrypted Rails credentials" do
    refute File.exist?(Rails.root.join("config/credentials.yml.enc"))
  end
end
