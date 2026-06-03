require "rails_helper"

RSpec.describe "Api::V1::Positions index", type: :request do
  def create_open_position
    snapshot = MarketSnapshot.create!(symbol: "XAUUSD", timeframe: "H4", price: 3350)
    trade_signal = TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: "BUY",
      confidence: 75,
      timeframe: "H4"
    )
    order = Order.create!(
      trade_signal: trade_signal,
      action: "BUY",
      entry_type: "BUY_LIMIT",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      risk_reward: 2.0,
      status: :placed
    )

    Position.create!(
      order: order,
      ticket: "index-#{SecureRandom.hex(4)}",
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350.50,
      stop_loss: 3335,
      take_profit: 3380,
      status: :open,
      profit_loss: 12.5,
      opened_at: 1.hour.ago
    )
  end

  describe "GET /api/v1/positions" do
    it "returns positions as JSON data array" do
      position = create_open_position

      get api_v1_positions_path

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["data"].size).to eq(1)
      expect(body["data"].first).to include(
        "id" => position.id,
        "ticket" => position.ticket,
        "symbol" => "XAUUSD",
        "status" => "open",
        "profit_loss" => "12.5"
      )
    end

    it "filters open positions" do
      create_open_position

      get api_v1_positions_path, params: { status: "open" }

      expect(response.parsed_body["data"].all? { |row| row["status"] == "open" }).to be(true)
    end
  end
end
