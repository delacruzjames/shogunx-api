require "rails_helper"

RSpec.describe "Api::V1::TradeSignals", type: :request do
  describe "GET /api/v1/trade_signals" do
    it "returns trade signals as JSON data array" do
      snapshot = MarketSnapshot.create!(symbol: "XAUUSD", timeframe: "H4", price: 3350)
      TradeSignal.create!(
        market_snapshot: snapshot,
        symbol: "XAUUSD",
        action: "BUY",
        confidence: 77,
        timeframe: "H4",
        reason: "Momentum"
      )

      get api_v1_trade_signals_path

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["data"].size).to eq(1)
      expect(body["meta"]["per_page"]).to eq(50)
      expect(body["data"].first).to include(
        "symbol" => "XAUUSD",
        "action" => "BUY",
        "confidence" => 77,
        "timeframe" => "H4",
        "reason" => "Momentum",
        "created_at"
      )
    end
  end
end
