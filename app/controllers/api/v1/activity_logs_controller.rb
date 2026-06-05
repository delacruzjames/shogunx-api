module Api
  module V1
    class ActivityLogsController < BaseController
      def index
        limit = params[:limit].to_i
        limit = ActivityLog::DEFAULT_LIMIT if limit <= 0
        limit = [ limit, ActivityLog::MAX_LIMIT ].min

        logs = if params[:since_id].present?
                 ActivityLog.after_id(params[:since_id].to_i).limit(limit)
        else
                 ActivityLog.recent.limit(limit)
        end

        render json: {
          data: logs.map { |log| JsonPresenter.activity_log(log) },
          meta: {
            limit: limit,
            since_id: params[:since_id].presence,
            incremental: params[:since_id].present?,
            generated_at: Time.current.iso8601
          }
        }
      end
    end
  end
end
