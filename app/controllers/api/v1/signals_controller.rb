module Api
  module V1
    class SignalsController < ApplicationController
      # MT4 posts flat JSON; do not wrap params under :signal (resources :signals name).
      wrap_parameters false

      def create
        snapshot = MarketSnapshot.new(snapshot_params)

        if snapshot.save
          render json: {
            status: "received",
            snapshot_id: snapshot.id,
            action: "WAIT"
          }
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
