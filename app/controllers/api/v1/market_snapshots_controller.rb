module Api
  module V1
    class MarketSnapshotsController < BaseController
      include ListScoped

      def index
        scope = MarketSnapshot.order(created_at: :desc)
        scope = scope.where(symbol: params[:symbol]) if params[:symbol].present?

        result = paginate(scope)
        render json: {
          data: result[:records].map { |snapshot| JsonPresenter.market_snapshot(snapshot) },
          meta: result[:meta]
        }
      end
    end
  end
end
