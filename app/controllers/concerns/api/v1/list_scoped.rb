module Api
  module V1
    module ListScoped
      extend ActiveSupport::Concern

      DEFAULT_LIMIT = 100
      MAX_LIMIT = 500

      private

      def list_limit
        requested = params[:limit].to_i
        return DEFAULT_LIMIT if requested <= 0

        [ requested, MAX_LIMIT ].min
      end
    end
  end
end
