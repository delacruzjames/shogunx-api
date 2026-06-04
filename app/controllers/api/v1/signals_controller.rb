module Api
  module V1
    class SignalsController < BaseController
      def create
        snapshot = MarketSnapshotIngestService.new(snapshot_params).call
        result = EndToEndSignalPipelineService.new(snapshot).call
        render json: result
      rescue ActiveRecord::RecordInvalid => error
        render json: {
          status: "error",
          errors: error.record.errors.full_messages
        }, status: :unprocessable_content
      end

      private

      def snapshot_params
        permitted = params.permit(
          :symbol,
          :timeframe,
          :price,
          :rsi,
          :ema50,
          :ema200,
          :support,
          :resistance,
          timeframes: {}
        )

        if permitted[:timeframes].present?
          permitted[:timeframes] = permitted[:timeframes].to_unsafe_h.transform_values do |metrics|
            metrics.permit(:price, :rsi, :ema50, :ema200, :support, :resistance)
          end
        end

        permitted
      end
    end
  end
end
