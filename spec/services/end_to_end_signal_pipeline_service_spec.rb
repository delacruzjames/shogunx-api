require "rails_helper"

RSpec.describe EndToEndSignalPipelineService do
  def build_snapshot(rsi: 68, ema50: 4490, ema200: 4470, support: 3350, resistance: 3380)
    create_multi_timeframe_snapshots(
      price: 4448.87,
      rsi: rsi,
      ema50: ema50,
      ema200: ema200,
      support: support,
      resistance: resistance
    ).find { |snapshot| snapshot.timeframe == "H4" }
  end

  describe "#call" do
    it "loads market summary for the snapshot symbol" do
      snapshot = build_snapshot
      pipeline = described_class.new(snapshot)

      pipeline.call

      expect(pipeline.market_summary[:symbol]).to eq("XAUUSD")
      expect(pipeline.market_summary[:snapshot_count]).to eq(3)
      expect(pipeline.market_summary[:timeframes]["H4"][:snapshot_count]).to eq(1)
    end

    it "returns HOLD when analysis is WAIT" do
      snapshot = build_snapshot(rsi: 45)
      stub_openai_wait(reason: "No actionable setup")

      result = described_class.new(snapshot).call

      expect(result).to eq(action: "HOLD", reason: "No actionable setup")
      expect(Order.count).to eq(0)
    end

    it "returns executable instructions when risk approves" do
      snapshot = build_snapshot

      result = nil
      expect {
        result = described_class.new(snapshot).call
      }.to change(TradeSignal, :count).by(1)
        .and change(Order, :count).by(1)

      order = Order.last
      expect(result).to eq(
        action: "BUY_LIMIT",
        order_id: order.id,
        symbol: "XAUUSD",
        entry_price: order.entry_price,
        stop_loss: order.stop_loss,
        take_profit: order.take_profit
      )
      expect(TradeSignal.last.rejection_reason).to be_nil
    end

    it "stores rejection reason and returns HOLD when risk rejects" do
      snapshot = build_snapshot
      existing_snapshot = build_snapshot
      trade_signal = TradeSignal.create!(
        market_snapshot: existing_snapshot,
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
        ticket: "open-#{SecureRandom.hex(4)}",
        symbol: "XAUUSD",
        action: "BUY",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        opened_at: Time.current
      )

      result = described_class.new(snapshot).call

      expect(result[:action]).to eq("HOLD")
      expect(result[:reason]).to eq("duplicate signal action")
      expect(TradeSignal.last.rejection_reason).to eq("duplicate signal action")
      expect(Order.pending.count).to eq(0)
    end

    it "returns HOLD when daily loss limit is reached" do
      DailyPerformance.create!(date: Time.zone.today, profit_loss: -500)
      snapshot = build_snapshot

      result = described_class.new(snapshot).call

      expect(result).to eq(action: "HOLD", reason: "daily loss limit reached")
      expect(TradeSignal.last.rejection_reason).to eq("daily loss limit reached")
    end

    it "returns HOLD when no order plan can be built" do
      snapshot = build_snapshot(support: 3380, resistance: 3350)
      chat_client = openai_json_response(action: "BUY", confidence: 80, reason: "Invalid levels")

      allow(Openai::ChatClient).to receive(:build).and_return(chat_client)

      result = described_class.new(snapshot).call

      expect(result).to eq(action: "HOLD", reason: "no order plan available")
    end
  end
end
