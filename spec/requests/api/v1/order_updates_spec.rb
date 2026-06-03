require "rails_helper"

RSpec.describe "Api::V1::OrderUpdates", type: :request do
  def create_order(status: :pending)
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

  describe "POST /api/v1/order_updates" do
    it "updates order status and ticket from MT4 with audit log" do
      order = create_order

      post api_v1_order_updates_path,
        params: {
          order_id: order.id,
          ticket: 987654,
          status: "placed"
        },
        as: :json

      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body["status"]).to eq("ok")
      expect(body["order_id"]).to eq(order.id)
      expect(body["order_status"]).to eq("placed")
      expect(body["audit_log_id"]).to be_present

      order.reload
      expect(order.status).to eq("placed")
      expect(order.ticket).to eq("987654")
      expect(ExecutionAuditLog.find(body["audit_log_id"]).source).to eq("order_updates")
    end

    it "accepts triggered status without opening a position" do
      order = create_order

      post api_v1_order_updates_path,
        params: { order_id: order.id, status: "triggered", ticket: 987654 },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("triggered")
      expect(order.position).to be_nil
    end

    it "accepts closed status with profit_loss and closes position" do
      order = create_order(status: :triggered)
      Position.create!(
        order: order,
        ticket: "987654",
        symbol: "XAUUSD",
        action: "BUY",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        opened_at: Time.current,
        status: :open
      )

      post api_v1_order_updates_path,
        params: {
          order_id: order.id,
          status: "closed",
          ticket: 987654,
          profit_loss: 125.50
        },
        as: :json

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq("closed")
      expect(order.position.reload.profit_loss).to eq(125.50)
    end

    it "returns errors for unsupported statuses" do
      order = create_order

      post api_v1_order_updates_path,
        params: { order_id: order.id, status: "pending" },
        as: :json

      expect(response).to have_http_status(:unprocessable_content)

      body = response.parsed_body
      expect(body["status"]).to eq("error")
      expect(body["errors"]).to include("Unsupported order status")
      expect(order.reload.status).to eq("pending")
    end

    it "returns errors when the order does not exist" do
      post api_v1_order_updates_path,
        params: { order_id: 0, status: "placed" },
        as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Order not found")
    end
  end
end
