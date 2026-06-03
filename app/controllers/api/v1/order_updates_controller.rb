module Api
  module V1
    class OrderUpdatesController < BaseController
      def create
        result = OrderStatusSyncService.new(order_update_params).call

        if result.success?
          render json: {
            status: "ok",
            order_id: result.order.id,
            order_status: result.order.status,
            audit_log_id: result.audit_log&.id
          }
        else
          render json: {
            status: "error",
            errors: result.errors
          }, status: :unprocessable_content
        end
      end

      private

      def order_update_params
        source = params[:order_update].presence || params

        source.permit(:order_id, :status, :ticket, :profit_loss, :exit_price)
      end
    end
  end
end
