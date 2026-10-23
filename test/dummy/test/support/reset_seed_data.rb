# frozen_string_literal: true

module ResetSeedData
  SKIPPED_TABLES = %w[schema_migrations ar_internal_metadata].freeze

  module_function

  def call
    connection = ActiveRecord::Base.connection
    tables = connection.tables - SKIPPED_TABLES
    return if tables.empty?

    connection.truncate_tables(*tables)
    load Rails.root.join("db/seeds.rb")
  end
end
