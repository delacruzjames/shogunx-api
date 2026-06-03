module Api
  module V1
    class SignalsController < ApplicationController
      def create
        signal = params.permit(:symbol, :entry, :sl, :tp)

        render json: {
          status: "received",
          signal: signal,
          order: {
            action: "hold",
            reason: "pipeline not wired yet"
          }
        }
      end
    end
  end
end
