module Api
  module V1
    class BaseController < ApplicationController
      wrap_parameters false

      private

      # Rack/Rails reserve keys like :action and :controller that shadow JSON fields.
      def json_param(key)
        return nil unless request.content_type.to_s.include?("json")

        parsed_json_body[key.to_s]
      end

      def parsed_json_body
        @parsed_json_body ||= begin
          raw = request.raw_post
          raw.present? ? JSON.parse(raw) : {}
        rescue JSON::ParserError
          {}
        end
      end
    end
  end
end
