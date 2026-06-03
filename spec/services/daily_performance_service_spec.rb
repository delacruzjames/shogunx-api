require "rails_helper"

RSpec.describe DailyPerformanceService do
  def create_trade_performance(profit_loss:, closed_at: Time.current)
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
      status: :closed
    )
    position = Position.create!(
      order: order,
      ticket: "daily-#{SecureRandom.hex(4)}",
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350.50,
      stop_loss: 3335,
      take_profit: 3380,
      status: :closed,
      profit_loss: profit_loss,
      opened_at: 2.hours.ago,
      closed_at: closed_at
    )

    TradePerformance.create!(
      position: position,
      symbol: position.symbol,
      action: position.action,
      entry_price: position.entry_price,
      exit_price: 3375.50,
      profit_loss: profit_loss,
      opened_at: position.opened_at,
      closed_at: position.closed_at
    )
  end

  describe "#call" do
    it "returns zeroed stats when there are no trades for the day" do
      stats = described_class.new.call

      expect(stats).to eq(
        date: Time.zone.today,
        total_trades: 0,
        wins: 0,
        losses: 0,
        win_rate: 0.0,
        total_profit_loss: 0.to_d
      )
    end

    it "calculates totals, wins, losses, and win rate for today" do
      create_trade_performance(profit_loss: 50)
      create_trade_performance(profit_loss: -20)
      create_trade_performance(profit_loss: 10)

      stats = described_class.new.call

      expect(stats[:total_trades]).to eq(3)
      expect(stats[:wins]).to eq(2)
      expect(stats[:losses]).to eq(1)
      expect(stats[:win_rate]).to eq(66.67)
      expect(stats[:total_profit_loss]).to eq(40.to_d)
    end

    it "ignores trades closed on other days" do
      create_trade_performance(profit_loss: 100, closed_at: 1.day.ago)

      stats = described_class.new.call

      expect(stats[:total_trades]).to eq(0)
    end
  end

  describe "#record!" do
    it "upserts the daily performance profit/loss total" do
      create_trade_performance(profit_loss: 30)
      create_trade_performance(profit_loss: -10)

      stats = described_class.new.record!

      expect(stats[:total_profit_loss]).to eq(20.to_d)
      expect(DailyPerformance.for_today.profit_loss).to eq(20.to_d)
    end
  end
end
