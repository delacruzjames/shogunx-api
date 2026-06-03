require "rails_helper"

RSpec.describe "Api::V1::Positions", type: :request do
  def create_order
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: 3350,
      rsi: 60,
      ema50: 3360,
      ema200: 3340,
      support: 3350,
      resistance: 3380
    )
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
      status: :pending
    )
  end

  describe "POST /api/v1/positions" do
    it "syncs position feedback from MT4 and returns ok" do
      order = create_order

      ticket = "req-#{SecureRandom.hex(8)}"

      post api_v1_positions_path,
        params: {
          ticket: ticket,
          order_id: order.id,
          symbol: "XAUUSD",
          action: "BUY",
          entry_price: 3350.50,
          stop_loss: 3335.00,
          take_profit: 3380.00,
          status: "open"
        },
        as: :json

      expect(response).to have_http_status(:ok), -> { response.parsed_body.inspect }
      expect(response.parsed_body).to eq("status" => "ok")
      expect(Position.count).to eq(1)
      expect(order.reload.status).to eq("triggered")
    end
  end
end
