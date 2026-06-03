require "rails_helper"

RSpec.describe "Api::V1::Signals", type: :request do
  describe "POST /api/v1/signals" do
    it "accepts signal payload from MT4 EA" do
      post api_v1_signals_path,
        params: { symbol: "EURUSD", entry: 1.085, sl: 1.082, tp: 1.091 },
        as: :json

      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body["status"]).to eq("received")
      expect(body["signal"]["symbol"]).to eq("EURUSD")
      expect(body["order"]["action"]).to eq("hold")
    end
  end
end
