module Api
  module V1
    class PositionsController < BaseController
      include ListScoped

      def index
        scope = Position.order(opened_at: :desc)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(symbol: params[:symbol]) if params[:symbol].present?

        positions = scope.limit(list_limit)
        render json: { data: positions.map { |position| JsonPresenter.position(position) } }
      end

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
