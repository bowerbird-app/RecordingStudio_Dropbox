# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require_relative "support/reset_seed_data"
require_relative "support/grant_workspace_access"

ResetSeedData.call

module ActiveSupport
  class TestCase
    include GrantWorkspaceAccess
  end
end
