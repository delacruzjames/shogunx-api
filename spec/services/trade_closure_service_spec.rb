require "rails_helper"

RSpec.describe TradeClosureService do
  def build_open_position
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: 3350
    )
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
      status: :triggered
    )

    Position.create!(
      order: order,
      ticket: "closure-#{SecureRandom.hex(4)}",
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350.50,
      stop_loss: 3335,
      take_profit: 3380,
      status: :open,
      opened_at: 1.hour.ago
    )
  end

  describe "#call" do
    it "closes the order, records trade performance, and updates daily performance" do
      position = build_open_position
      position.update!(
        status: :closed,
        closed_at: Time.current,
        profit_loss: 42.5
      )

      result = nil
      expect {
        result = described_class.new(position, exit_price: 3375.50, profit_loss: 42.5).call
      }.to change(TradePerformance, :count).by(1)
        .and change(DailyPerformance, :count).by(1)

      expect(result).to be_success
      expect(position.order.reload.status).to eq("closed")
      expect(result.trade_performance.profit_loss).to eq(42.5)
      expect(result.trade_performance.exit_price).to eq(3375.50)

      daily = DailyPerformance.for_today
      expect(daily.profit_loss).to eq(42.5)
    end

    it "returns an error when the position is not closed" do
      position = build_open_position

      result = described_class.new(position, exit_price: 3375.50, profit_loss: 10).call

      expect(result).not_to be_success
      expect(result.errors).to include("Position is not closed")
    end

    it "returns an error when exit price is missing" do
      position = build_open_position
      position.update!(status: :closed, closed_at: Time.current, profit_loss: 10)

      result = described_class.new(position, profit_loss: 10).call

      expect(result).not_to be_success
      expect(result.errors).to include("Exit price can't be blank")
    end

    it "does not duplicate trade performance records" do
      position = build_open_position
      position.update!(status: :closed, closed_at: Time.current, profit_loss: 10)

      described_class.new(position, exit_price: 3375.50, profit_loss: 10).call

      expect {
        described_class.new(position, exit_price: 3376.00, profit_loss: 10).call
      }.not_to change(TradePerformance, :count)
    end
  end
end
