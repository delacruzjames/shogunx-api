module Api
  module V1
    class TradeSignalsController < BaseController
      include ListScoped

      def index
        scope = TradeSignal.order(created_at: :desc)
        scope = scope.where(symbol: params[:symbol]) if params[:symbol].present?

        signals = scope.limit(list_limit)
        render json: { data: signals.map { |signal| JsonPresenter.trade_signal(signal) } }
      end
    end
  end
end
