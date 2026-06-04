require "rails_helper"

RSpec.describe DashboardOverviewService do
  include ActiveSupport::Testing::TimeHelpers

  before do
    ExecutionAuditLog.delete_all
    TradePerformance.delete_all
    Position.delete_all
    Order.delete_all
    TradeSignal.delete_all
    MarketSnapshot.where(symbol: "XAUUSD").delete_all
  end

  def create_snapshot(price: 3350)
    MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: price,
      rsi: 55,
      ema50: 3340,
      ema200: 3330,
      support: 3320,
      resistance: 3360
    )
  end

  def create_signal(confidence: 82)
    snapshot = create_snapshot
    TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: "BUY",
      confidence: confidence,
      timeframe: "H4",
      reason: "EMA crossover"
    )
  end

  describe "#call" do
    it "returns empty-state dashboard fields when no data exists" do
      overview = described_class.new.call

      expect(overview[:xauusd_price]).to be_nil
      expect(overview[:latest_signal]).to be_nil
      expect(overview[:signal_confidence]).to be_nil
      expect(overview[:order_status]).to include("Hold")
      expect(overview[:open_position_status]).to eq("No open position")
      expect(overview[:total_trades_today]).to eq(0)
      expect(overview[:generated_at]).to be_present
    end

    it "includes latest XAUUSD price, signal, and open position" do
      travel_to Time.zone.local(2026, 6, 3, 12, 0, 0) do
        create_snapshot(price: 3388.25).update_column(:created_at, 2.hours.ago)

        snapshot = create_snapshot(price: 3390)
        latest_signal = TradeSignal.create!(
          market_snapshot: snapshot,
          symbol: "XAUUSD",
          action: "SELL",
          confidence: 70,
          timeframe: "H4"
        )
        order = Order.create!(
          trade_signal: latest_signal,
          action: "SELL",
          entry_type: "SELL_LIMIT",
          entry_price: 3390,
          stop_loss: 3405,
          take_profit: 3360,
          risk_reward: 2.0,
          status: :pending
        )
        Position.create!(
          order: order,
          ticket: "dash-open-1",
          symbol: "XAUUSD",
          action: "SELL",
          entry_price: 3390,
          stop_loss: 3405,
          take_profit: 3360,
          status: :open,
          opened_at: 1.hour.ago
        )

        overview = described_class.new.call

        expect(overview[:xauusd_price]).to eq(snapshot.price)
        expect(overview[:latest_signal][:id]).to eq(latest_signal.id)
        expect(overview[:signal_confidence]).to eq(70)
        expect(overview[:open_position_status]).to include("SELL XAUUSD")
      end
    end
  end
end
