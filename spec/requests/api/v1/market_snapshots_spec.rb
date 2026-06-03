require "rails_helper"

RSpec.describe "Api::V1::MarketSnapshots", type: :request do
  describe "GET /api/v1/market_snapshots" do
    it "returns market snapshots as JSON data array" do
      MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 3350,
        rsi: 60,
        ema50: 3340,
        ema200: 3330,
        support: 3320,
        resistance: 3360
      )

      get api_v1_market_snapshots_path

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["data"].size).to eq(1)
      row = body["data"].first
      expect(row).to include(
        "symbol" => "XAUUSD",
        "timeframe" => "H4"
      )
      expect(row.keys).to include(
        "price",
        "rsi",
        "ema50",
        "ema200",
        "support",
        "resistance",
        "created_at"
      )
    end

    it "filters by symbol" do
      MarketSnapshot.create!(symbol: "XAUUSD", timeframe: "H4", price: 3350)
      MarketSnapshot.create!(symbol: "EURUSD", timeframe: "H1", price: 1.08)

      get api_v1_market_snapshots_path, params: { symbol: "EURUSD" }

      expect(response.parsed_body["data"].map { |row| row["symbol"] }).to eq([ "EURUSD" ])
    end
  end
end
