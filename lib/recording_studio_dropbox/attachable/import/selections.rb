# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    module Import
      module Selections
        module_function

        def selections_from(attachments)
          Array(attachments).filter_map { |item| selection_from(item) }.uniq { |row| row.fetch("id") }
        end

        def selection_from(item)
          return string_selection(item) if item.is_a?(String)

          hash = stringify_hash(item)
          return if hash.blank?

          payload = stringify_hash(hash["provider_payload"]) || hash
          build_selection(hash, payload)
        end

        def stringify_hash(value)
          return unless value.respond_to?(:to_h)

          hash = value.to_h
          hash = hash.to_unsafe_h if hash.respond_to?(:to_unsafe_h)
          hash.deep_stringify_keys
        end

        def build_selection(hash, payload)
          id = payload["id"]
          return if id.blank?

          {
            "id" => id.to_s,
            "name" => (hash["name"].presence || payload["name"]).presence,
            "description" => hash["description"].presence
          }.compact
        end

        def string_selection(item)
          item.presence && { "id" => item }
        end
      end
    end
  end
end
