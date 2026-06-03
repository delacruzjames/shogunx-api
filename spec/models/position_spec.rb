require "rails_helper"

RSpec.describe Position, type: :model do
  def build_order(status: "triggered")
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

  describe "constants" do
    it "defines allowed statuses" do
      expect(described_class::STATUSES).to eq(%w[open closed])
    end
  end

  describe "associations" do
    it "belongs to an order" do
      order = build_order
      position = described_class.new(
        order: order,
        symbol: "XAUUSD",
        action: "BUY",
        volume: 0.1,
        open_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        status: "open",
        mt4_ticket: 123_456,
        opened_at: Time.current
      )

      expect(position.order).to eq(order)
    end

    it "is destroyed when its order is destroyed" do
      order = build_order
      described_class.create!(
        order: order,
        symbol: "XAUUSD",
        action: "BUY",
        volume: 0.1,
        open_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        status: "open",
        mt4_ticket: 123_456,
        opened_at: Time.current
      )

      expect { order.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe "validations" do
    let(:order) { build_order }

    let(:valid_attributes) do
      {
        order: order,
        symbol: "XAUUSD",
        action: "BUY",
        volume: 0.1,
        open_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        status: "open",
        mt4_ticket: 123_456,
        opened_at: Time.current
      }
    end

    it "is valid when open" do
      position = described_class.new(valid_attributes)

      expect(position).to be_valid
    end

    it "defaults status to open" do
      position = described_class.create!(valid_attributes.except(:status))

      expect(position.status).to eq("open")
    end

    it "requires an order" do
      position = described_class.new(valid_attributes.except(:order))

      expect(position).not_to be_valid
      expect(position.errors[:order]).to include("must exist")
    end

    it "requires a unique mt4_ticket" do
      described_class.create!(valid_attributes)
      duplicate = described_class.new(valid_attributes.merge(order: build_order, mt4_ticket: 123_456))

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:mt4_ticket]).to include("has already been taken")
    end

    it "requires closed_at and close_price when closed" do
      position = described_class.new(valid_attributes.merge(status: "closed"))

      expect(position).not_to be_valid
      expect(position.errors[:closed_at]).to include("can't be blank")
      expect(position.errors[:close_price]).to include("can't be blank")
    end

    it "allows a valid closed position" do
      position = described_class.new(
        valid_attributes.merge(
          status: "closed",
          closed_at: Time.current,
          close_price: 3375,
          profit: 25
        )
      )

      expect(position).to be_valid
    end
  end

  describe "scopes" do
    it "filters open and closed positions" do
      order_open = build_order
      order_closed = build_order

      open_position = described_class.create!(
        order: order_open,
        symbol: "XAUUSD",
        action: "BUY",
        volume: 0.1,
        open_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        mt4_ticket: 111,
        opened_at: Time.current
      )
      described_class.create!(
        order: order_closed,
        symbol: "XAUUSD",
        action: "SELL",
        volume: 0.1,
        open_price: 3380,
        stop_loss: 3395,
        take_profit: 3350,
        status: "closed",
        mt4_ticket: 222,
        opened_at: 2.hours.ago,
        closed_at: Time.current,
        close_price: 3360,
        profit: 20
      )

      expect(described_class.open).to contain_exactly(open_position)
      expect(described_class.closed.count).to eq(1)
    end
  end
end
