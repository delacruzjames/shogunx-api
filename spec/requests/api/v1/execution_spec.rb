require "rails_helper"

RSpec.describe "Api::V1::Execution", type: :request do
  def create_pending_order(expires_at: nil, created_at: Time.current)
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: 3350,
      rsi: 68,
      ema50: 3360,
      ema200: 3340,
      support: 3350,
      resistance: 3380
    )
    trade_signal = TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: "BUY",
      confidence: 80,
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
      status: :pending,
      expires_at: expires_at,
      created_at: created_at
    )
  end

  describe "GET /api/v1/execution" do
    it "returns HOLD when no approved pending order exists" do
      get api_v1_execution_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "action" => "HOLD",
        "reason" => "No approved trade available"
      )
    end

    it "returns the latest pending order for MT4 execution" do
      create_pending_order(created_at: 2.hours.ago)
      latest = create_pending_order(
        created_at: 1.hour.ago,
        expires_at: Time.zone.parse("2026-06-03T16:00:00Z")
      )

      get api_v1_execution_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "action" => "BUY_LIMIT",
        "order_id" => latest.id,
        "symbol" => "XAUUSD",
        "entry_price" => "3350.0",
        "stop_loss" => "3335.0",
        "take_profit" => "3380.0",
        "expires_at" => "2026-06-03T16:00:00Z"
      )
    end

    it "ignores non-pending orders" do
      order = create_pending_order
      order.update!(status: :placed)

      get api_v1_execution_path

      expect(response.parsed_body).to eq(
        "action" => "HOLD",
        "reason" => "No approved trade available"
      )
    end

    it "omits expires_at when the order has none" do
      create_pending_order(expires_at: nil)

      get api_v1_execution_path

      body = response.parsed_body
      expect(body["action"]).to eq("BUY_LIMIT")
      expect(body).not_to have_key("expires_at")
    end
  end
end
