module Api
  module V1
    class PositionUpdatesController < BaseController
      def create
        result = PositionUpdateService.new(position_update_params).call

        if result.success?
          render json: {
            status: "ok",
            position_id: result.position.id,
            position_status: result.position.status,
            audit_log_id: result.audit_log.id
          }
        else
          render json: {
            status: "error",
            errors: result.errors
          }, status: :unprocessable_content
        end
      end

      private

      def position_update_params
        source = params[:position_update].presence || params

        source.permit(
          :order_id,
          :ticket,
          :status,
          :entry_price,
          :profit_loss,
          :exit_price
        )
      end
    end
  end
end
