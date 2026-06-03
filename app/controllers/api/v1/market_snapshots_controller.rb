module Api
  module V1
    class MarketSnapshotsController < BaseController
      include ListScoped

      def index
        scope = MarketSnapshot.order(created_at: :desc)
        scope = scope.where(symbol: params[:symbol]) if params[:symbol].present?

        snapshots = scope.limit(list_limit)
        render json: { data: snapshots.map { |snapshot| JsonPresenter.market_snapshot(snapshot) } }
      end
    end
  end
end
