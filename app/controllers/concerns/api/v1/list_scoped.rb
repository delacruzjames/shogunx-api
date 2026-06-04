module Api
  module V1
    module ListScoped
      extend ActiveSupport::Concern

      DEFAULT_PER_PAGE = 50
      MAX_PER_PAGE = 100

      private

      def paginate(scope)
        page, per_page = pagination_values
        total_count = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page)

        {
          records: records,
          meta: {
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_pages_for(total_count, per_page)
          }
        }
      end

      def pagination_values
        page = params[:page].to_i
        page = 1 if page < 1

        per_page = params[:per_page].to_i
        if per_page <= 0
          legacy_limit = params[:limit].to_i
          per_page = legacy_limit.positive? ? legacy_limit : DEFAULT_PER_PAGE
        end
        per_page = [ per_page, MAX_PER_PAGE ].min

        [ page, per_page ]
      end

      def total_pages_for(total_count, per_page)
        return 0 if total_count.zero?

        (total_count.to_f / per_page).ceil
      end
    end
  end
end
