module Api
  module V1
    class SignalsController < BaseController
      def create
        snapshot = MarketSnapshot.new(snapshot_params)

        if snapshot.save
          result = EndToEndSignalPipelineService.new(snapshot).call
          render json: result
        else
          render json: {
            status: "error",
            errors: snapshot.errors.full_messages
          }, status: :unprocessable_content
        end
      end

      private

      def snapshot_params
        params.permit(
          :symbol,
          :timeframe,
          :price,
          :rsi,
          :ema50,
          :ema200,
          :support,
          :resistance
        )
      end
    end
  end
end
