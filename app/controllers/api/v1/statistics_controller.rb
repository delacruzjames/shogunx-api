module Api
  module V1
    class StatisticsController < BaseController
      def show
        stats = TradePerformanceService.new(**statistics_params).call

        render json: stats
      end

      private

      def statistics_params
        permitted = params.permit(:from, :to, :symbol, :daily_days, :monthly_months)

        attrs = {
          from: permitted[:from],
          to: permitted[:to],
          symbol: permitted[:symbol]
        }
        attrs[:daily_days] = permitted[:daily_days].to_i if permitted[:daily_days].present?
        attrs[:monthly_months] = permitted[:monthly_months].to_i if permitted[:monthly_months].present?
        attrs.compact
      end
    end
  end
end
