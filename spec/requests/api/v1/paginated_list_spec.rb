require "rails_helper"

RSpec.describe "Paginated list endpoints", type: :request do
  shared_examples "paginated index" do |path_helper, factory|
    it "returns 50 records per page by default" do
      51.times { |index| factory.call(index) }

      get send(path_helper)

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body["data"].size).to eq(50)
      expect(body["meta"]).to eq(
        "page" => 1,
        "per_page" => 50,
        "total_count" => 51,
        "total_pages" => 2
      )
    end

    it "returns the second page" do
      51.times { |index| factory.call(index) }

      get send(path_helper), params: { page: 2 }

      body = response.parsed_body
      expect(body["data"].size).to eq(1)
      expect(body["meta"]["page"]).to eq(2)
    end
  end

  describe "GET /api/v1/market_snapshots" do
    include_examples "paginated index", :api_v1_market_snapshots_path, lambda { |_index|
      MarketSnapshot.create!(symbol: "XAUUSD", timeframe: "H4", price: 3350)
    }
  end

  describe "GET /api/v1/trade_signals" do
    include_examples "paginated index", :api_v1_trade_signals_path, lambda { |_index|
      snapshot = MarketSnapshot.create!(symbol: "XAUUSD", timeframe: "H4", price: 3350)
      TradeSignal.create!(
        market_snapshot: snapshot,
        symbol: "XAUUSD",
        action: "BUY",
        confidence: 75,
        timeframe: "H4"
      )
    }
  end
end
