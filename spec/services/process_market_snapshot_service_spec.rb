require "rails_helper"

RSpec.describe ProcessMarketSnapshotService do
  def create_open_position_for_risk_block
    snapshot = build_snapshot
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
      ticket: "risk-block-#{SecureRandom.hex(4)}",
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      opened_at: Time.current
    )
    order
  end

  def build_snapshot(symbol: "XAUUSD", rsi: 68, ema50: 4490, ema200: 4470, support: 3350, resistance: 3380)
    create_multi_timeframe_snapshots(
      symbol: symbol,
      price: 4448.87,
      rsi: rsi,
      ema50: ema50,
      ema200: ema200,
      support: support,
      resistance: resistance
    ).find { |snapshot| snapshot.timeframe == "H4" }
  end

  describe "#call" do
    it "delegates to EndToEndSignalPipelineService" do
      snapshot = build_snapshot
      pipeline_result = { action: "HOLD", reason: "test" }
      pipeline = instance_double(EndToEndSignalPipelineService, call: pipeline_result)

      allow(EndToEndSignalPipelineService).to receive(:new).with(snapshot).and_return(pipeline)

      expect(described_class.new(snapshot).call).to eq(pipeline_result)
    end

    it "returns HOLD when analysis is WAIT" do
      stub_openai_wait(reason: "No actionable setup")
      snapshot = build_snapshot(rsi: 45, ema50: 4490, ema200: 4470)

      result = described_class.new(snapshot).call

      expect(result).to eq(action: "HOLD", reason: "No actionable setup")
      expect(Order.count).to eq(0)
    end

    it "returns executable instructions when analysis creates a pending order" do
      snapshot = build_snapshot

      result = described_class.new(snapshot).call

      expect(result[:action]).to eq("BUY_LIMIT")
      expect(result[:order_id]).to eq(Order.last.id)
      expect(result[:entry_price]).to eq(3350)
    end

    it "does not create an order when risk rules reject the trade" do
      create_open_position_for_risk_block

      snapshot = build_snapshot
      result = described_class.new(snapshot).call

      expect(result[:action]).to eq("HOLD")
      expect(result[:reason]).to eq("duplicate signal action")
      expect(Order.pending.count).to eq(0)
    end

    it "does not create an order when daily loss limit is reached" do
      DailyPerformance.create!(date: Time.zone.today, profit_loss: -500)

      snapshot = build_snapshot
      result = described_class.new(snapshot).call

      expect(result[:action]).to eq("HOLD")
      expect(result[:reason]).to eq("daily loss limit reached")
      expect(Order.count).to eq(0)
    end
  end
end
