require "rails_helper"

RSpec.describe PositionSyncService do
  def unique_ticket
    "sync-#{SecureRandom.hex(8)}"
  end

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

  let(:open_payload) do
    {
      ticket: unique_ticket,
      order_id: nil,
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350.50,
      stop_loss: 3335.00,
      take_profit: 3380.00,
      status: "open"
    }
  end

  describe "#call" do
    it "creates a position and marks the order as triggered" do
      order = create_order
      payload = open_payload.merge(order_id: order.id)

      result = nil
      expect {
        result = described_class.new(payload).call
      }.to change(Position, :count).by(1)

      expect(result).to be_success
      position = result.position
      expect(position.ticket).to eq(payload[:ticket])
      expect(position.entry_price).to eq(3350.50)
      expect(position.status).to eq("open")
      expect(order.reload.status).to eq("triggered")
      expect(order.opened_at).to be_present
    end

    it "updates an existing position by ticket" do
      order = create_order(status: :triggered)
      described_class.new(open_payload.merge(order_id: order.id)).call

      result = described_class.new(
        open_payload.merge(
          order_id: order.id,
          entry_price: 3351.00,
          status: "open"
        )
      ).call

      expect(result).to be_success
      expect(result.position.entry_price).to eq(3351.00)
      expect(Position.where(ticket: open_payload[:ticket]).count).to eq(1)
    end

    it "closes a position and updates the order" do
      order = create_order
      described_class.new(open_payload.merge(order_id: order.id)).call

      result = nil
      expect {
        result = described_class.new(
          open_payload.merge(
            order_id: order.id,
            status: "closed",
            profit_loss: 25.5,
            exit_price: 3375.50
          )
        ).call
      }.to change(TradePerformance, :count).by(1)

      expect(result).to be_success
      expect(result.position.status).to eq("closed")
      expect(result.position.profit_loss).to eq(25.5)
      expect(order.reload.status).to eq("closed")
      expect(TradePerformance.last.exit_price).to eq(3375.50)
    end

    it "returns an error when closing without exit price" do
      order = create_order
      described_class.new(open_payload.merge(order_id: order.id)).call

      result = described_class.new(
        open_payload.merge(
          order_id: order.id,
          status: "closed",
          profit_loss: 25.5
        )
      ).call

      expect(result).not_to be_success
      expect(result.errors).to include("Exit price can't be blank")
      expect(order.reload.status).to eq("triggered")
    end

    it "returns an error when the order is missing" do
      result = described_class.new(open_payload.merge(order_id: 0)).call

      expect(result).not_to be_success
      expect(result.errors).to include("Order not found")
    end
  end
end
