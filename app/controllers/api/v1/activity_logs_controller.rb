module Api
  module V1
    class ActivityLogsController < BaseController
      include ListScoped

      def index
        if params[:since_id].present?
          render json: incremental_payload
        else
          render json: paginated_payload
        end
      end

      private

      def incremental_payload
        limit = params[:limit].to_i
        limit = ActivityLog::DEFAULT_LIMIT if limit <= 0
        limit = [ limit, ActivityLog::MAX_LIMIT ].min

        logs = ActivityLog.after_id(params[:since_id].to_i).limit(limit)

        {
          data: logs.map { |log| JsonPresenter.activity_log(log) },
          meta: {
            limit: limit,
            since_id: params[:since_id].presence,
            incremental: true,
            generated_at: Time.current.iso8601
          }
        }
      end

      def paginated_payload
        result = paginate(ActivityLog.recent)

        {
          data: result[:records].map { |log| JsonPresenter.activity_log(log) },
          meta: result[:meta].merge(generated_at: Time.current.iso8601)
        }
      end
    end
  end
end
