require "rails_helper"

RSpec.describe TradePerformanceService do
  include ActiveSupport::Testing::TimeHelpers
  def create_trade(profit_loss:, risk_reward: 2.0, closed_at: Time.current, symbol: "XAUUSD")
    snapshot = MarketSnapshot.create!(
      symbol: symbol,
      timeframe: "H4",
      price: 3350
    )
    trade_signal = TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: symbol,
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
      risk_reward: risk_reward,
      status: :closed
    )
    position = Position.create!(
      order: order,
      ticket: "stats-#{SecureRandom.hex(4)}",
      symbol: symbol,
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
    it "returns zeroed dashboard stats when there are no trades" do
      stats = described_class.new(from: Date.new(2026, 6, 1), to: Date.new(2026, 6, 3), daily_days: 3, monthly_months: 1).call

      expect(stats[:summary]).to include(
        total_trades: 0,
        wins: 0,
        losses: 0,
        breakeven: 0,
        win_rate: 0.0,
        profit_factor: 0.0,
        average_rr: 0.0,
        total_profit_loss: 0.0,
        gross_profit: 0.0,
        gross_loss: 0.0
      )
      expect(stats[:daily_pnl].size).to eq(3)
      expect(stats[:monthly_pnl].size).to eq(1)
    end

    it "calculates summary metrics for closed trades" do
      travel_to Time.zone.local(2026, 6, 3, 12, 0, 0) do
        create_trade(profit_loss: 100, risk_reward: 2.0, closed_at: Time.current)
        create_trade(profit_loss: 50, risk_reward: 3.0, closed_at: Time.current)
        create_trade(profit_loss: -40, risk_reward: 1.5, closed_at: Time.current)
        create_trade(profit_loss: 0, risk_reward: 2.0, closed_at: Time.current)

        stats = described_class.new(
          from: Date.new(2026, 6, 3),
          to: Date.new(2026, 6, 3),
          daily_days: 1,
          monthly_months: 1
        ).call

        summary = stats[:summary]
        expect(summary[:total_trades]).to eq(4)
        expect(summary[:wins]).to eq(2)
        expect(summary[:losses]).to eq(1)
        expect(summary[:breakeven]).to eq(1)
        expect(summary[:win_rate]).to eq(50.0)
        expect(summary[:profit_factor]).to eq(3.75)
        expect(summary[:average_rr]).to eq(2.13)
        expect(summary[:total_profit_loss]).to eq(110.0)
        expect(summary[:gross_profit]).to eq(150.0)
        expect(summary[:gross_loss]).to eq(40.0)
      end
    end

    it "builds daily pnl series for the dashboard window" do
      travel_to Time.zone.local(2026, 6, 3, 12, 0, 0) do
        create_trade(profit_loss: 25, closed_at: Time.zone.local(2026, 6, 1, 10, 0, 0))
        create_trade(profit_loss: -10, closed_at: Time.zone.local(2026, 6, 3, 10, 0, 0))

        stats = described_class.new(
          from: Date.new(2026, 6, 1),
          to: Date.new(2026, 6, 3),
          daily_days: 3,
          monthly_months: 1
        ).call

        expect(stats[:daily_pnl]).to eq(
          [
            { date: "2026-06-01", profit_loss: 25.0, trades: 1, wins: 1, losses: 0 },
            { date: "2026-06-02", profit_loss: 0.0, trades: 0, wins: 0, losses: 0 },
            { date: "2026-06-03", profit_loss: -10.0, trades: 1, wins: 0, losses: 1 }
          ]
        )
      end
    end

    it "builds monthly pnl series" do
      travel_to Time.zone.local(2026, 6, 15, 12, 0, 0) do
        create_trade(profit_loss: 80, closed_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
        create_trade(profit_loss: 20, closed_at: Time.zone.local(2026, 6, 5, 10, 0, 0))

        stats = described_class.new(
          from: Date.new(2026, 5, 1),
          to: Date.new(2026, 6, 15),
          daily_days: 7,
          monthly_months: 2
        ).call

        expect(stats[:monthly_pnl]).to eq(
          [
            { month: "2026-05", profit_loss: 80.0, trades: 1, wins: 1, losses: 0 },
            { month: "2026-06", profit_loss: 20.0, trades: 1, wins: 1, losses: 0 }
          ]
        )
      end
    end

    it "filters trades by symbol" do
      travel_to Time.zone.local(2026, 6, 3, 12, 0, 0) do
        create_trade(profit_loss: 50, symbol: "XAUUSD", closed_at: Time.current)
        create_trade(profit_loss: 30, symbol: "EURUSD", closed_at: Time.current)

        stats = described_class.new(
          from: Date.new(2026, 6, 3),
          to: Date.new(2026, 6, 3),
          symbol: "XAUUSD",
          daily_days: 1,
          monthly_months: 1
        ).call

        expect(stats[:summary][:total_trades]).to eq(1)
        expect(stats[:summary][:total_profit_loss]).to eq(50.0)
        expect(stats[:period][:symbol]).to eq("XAUUSD")
      end
    end

    it "ignores trades outside the summary period" do
      travel_to Time.zone.local(2026, 6, 3, 12, 0, 0) do
        create_trade(profit_loss: 100, closed_at: Time.zone.local(2026, 6, 1, 10, 0, 0))
        create_trade(profit_loss: 200, closed_at: Time.zone.local(2026, 6, 10, 10, 0, 0))

        stats = described_class.new(
          from: Date.new(2026, 6, 1),
          to: Date.new(2026, 6, 3),
          daily_days: 3,
          monthly_months: 1
        ).call

        expect(stats[:summary][:total_trades]).to eq(1)
        expect(stats[:summary][:total_profit_loss]).to eq(100.0)
      end
    end
  end
end
