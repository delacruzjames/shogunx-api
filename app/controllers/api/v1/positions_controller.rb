module Api
  module V1
    class PositionsController < BaseController
      def create
        result = PositionSyncService.new(position_params).call

        if result.success?
          render json: { status: "ok" }
        else
          render json: {
            status: "error",
            errors: result.errors
          }, status: :unprocessable_content
        end
      end

      private

      def position_params
        source = params[:position].presence || params

        permitted = source.permit(
          :ticket,
          :order_id,
          :symbol,
          :entry_price,
          :stop_loss,
          :take_profit,
          :status,
          :profit_loss,
          :exit_price,
          :opened_at,
          :closed_at
        )

        trade_action = json_param(:action) || source[:action]
        permitted[:action] = trade_action if trade_action.present?

        permitted
      end
    end
  end
end
