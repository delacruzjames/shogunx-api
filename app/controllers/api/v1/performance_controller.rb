module Api
  module V1
    class PerformanceController < BaseController
      include TradePerformanceScoped

      def show
        stats = TradePerformanceService.new(**trade_performance_query_params).call
        render json: stats
      end
    end
  end
end
