module Api
  module V1
    class DashboardController < BaseController
      def show
        overview = DashboardOverviewService.new(symbol: dashboard_symbol).call
        render json: overview
      end

      private

      def dashboard_symbol
        params[:symbol].presence || DashboardOverviewService::DEFAULT_SYMBOL
      end
    end
  end
end
