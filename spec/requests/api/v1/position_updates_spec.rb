require "rails_helper"

RSpec.describe "Api::V1::PositionUpdates", type: :request do
  def create_order(status: :placed)
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
      status: status
    )
  end

  describe "POST /api/v1/position_updates" do
    it "opens a position from MT4 with entry_price and audit log" do
      order = create_order

      post api_v1_position_updates_path,
        params: {
          order_id: order.id,
          ticket: 987654,
          status: "open",
          entry_price: 3350.50
        },
        as: :json

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include(
        "status" => "ok",
        "position_status" => "open"
      )
      expect(body["audit_log_id"]).to be_present

      position = Position.last
      expect(position.ticket).to eq("987654")
      expect(position.entry_price).to eq(3350.50)
      expect(order.reload.status).to eq("triggered")

      audit = ExecutionAuditLog.find(body["audit_log_id"])
      expect(audit.source).to eq("position_updates")
      expect(audit.entry_price).to eq(3350.50)
    end

    it "closes a position and records trade performance" do
      order = create_order

      post api_v1_position_updates_path,
        params: {
          order_id: order.id,
          ticket: 987654,
          status: "open",
          entry_price: 3350.50
        },
        as: :json

      post api_v1_position_updates_path,
        params: {
          order_id: order.id,
          ticket: 987654,
          status: "closed",
          profit_loss: 125.50
        },
        as: :json

      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body["status"]).to eq("ok")
      expect(body["position_status"]).to eq("closed")

      position = Position.find_by(ticket: "987654")
      expect(position.profit_loss).to eq(125.50)
      expect(order.reload.status).to eq("closed")
      expect(position.trade_performance).to be_present
      expect(position.trade_performance.profit_loss).to eq(125.50)
      expect(ExecutionAuditLog.where(event_status: "closed").count).to be >= 1
    end

    it "returns errors for invalid payloads" do
      order = create_order

      post api_v1_position_updates_path,
        params: { order_id: order.id, status: "open", entry_price: 3350.50 },
        as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Ticket is required")
    end

    it "requires profit_loss when closing" do
      order = create_order

      post api_v1_position_updates_path,
        params: {
          order_id: order.id,
          ticket: 987654,
          status: "open",
          entry_price: 3350.50
        },
        as: :json

      post api_v1_position_updates_path,
        params: {
          order_id: order.id,
          ticket: 987654,
          status: "closed"
        },
        as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Profit/loss is required")
    end
  end
end
