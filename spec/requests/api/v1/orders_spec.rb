require "rails_helper"

RSpec.describe "Api::V1::Orders", type: :request do
  def create_order(status: :pending)
    snapshot = MarketSnapshot.create!(symbol: "XAUUSD", timeframe: "H4", price: 3350)
    trade_signal = TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: "BUY",
      confidence: 75,
      timeframe: "H4"
    )

    Order.create!(
      trade_signal: trade_signal,
      action: "BUY",
      entry_type: "BUY_LIMIT",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      risk_reward: 2.0,
      status: status,
      expires_at: 1.day.from_now
    )
  end

  describe "GET /api/v1/orders" do
    it "returns orders as JSON data array" do
      order = create_order

      get api_v1_orders_path

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["data"].size).to eq(1)
      expect(body["data"].first).to include(
        "id" => order.id,
        "action" => "BUY",
        "entry_type" => "BUY_LIMIT",
        "status" => "pending",
        "expires_at"
      )
    end
  end
end
