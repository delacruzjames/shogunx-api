module Api
  module V1
    module TradePerformanceScoped
      extend ActiveSupport::Concern

      private

      def trade_performance_query_params
        source = params.slice(:from, :to, :symbol, :daily_days, :monthly_months)

        attrs = {
          from: source[:from],
          to: source[:to],
          symbol: source[:symbol]
        }
        attrs[:daily_days] = source[:daily_days].to_i if source[:daily_days].present?
        attrs[:monthly_months] = source[:monthly_months].to_i if source[:monthly_months].present?
        attrs.compact
      end
    end
  end
end
