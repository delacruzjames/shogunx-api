module Api
  module V1
    class TradeSignalsController < BaseController
      include ListScoped

      def index
        scope = TradeSignal.order(created_at: :desc)
        scope = scope.where(symbol: params[:symbol]) if params[:symbol].present?

        result = paginate(scope)
        render json: {
          data: result[:records].map { |signal| JsonPresenter.trade_signal(signal) },
          meta: result[:meta]
        }
      end
    end
  end
end
