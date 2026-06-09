require "rails_helper"

RSpec.describe OrderPlanService do
  def build_trade_signal(action:, support: 3335.0, resistance: 3380.0, price: 3350.0)
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: price,
      rsi: 60,
      ema50: 3360,
      ema200: 3340,
      support: support,
      resistance: resistance
    )

    TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: action,
      confidence: 75,
      timeframe: "H4",
      reason: "Test signal"
    )
  end

  describe "#call" do
    it "returns nil for WAIT signals" do
      signal = build_trade_signal(action: "WAIT")

      expect(described_class.new(signal).call).to be_nil
    end

    it "builds a BUY limit plan near support with stop below and target at resistance" do
      signal = build_trade_signal(action: "BUY", support: 3350.0, resistance: 3380.0, price: 3360.0)

      plan = described_class.new(signal).call

      expect(plan).to include(
        action: "BUY",
        entry_type: "BUY_LIMIT",
        entry_price: 3350.0,
        stop_loss: 3335.0,
        take_profit: 3380.0,
        max_take_profit: 3380.0,
        risk_reward: 2.0
      )
    end

    it "builds a SELL limit plan near resistance with stop above and target at support" do
      signal = build_trade_signal(action: "SELL", support: 3350.0, resistance: 3380.0, price: 3355.0)

      plan = described_class.new(signal).call

      expect(plan).to include(
        action: "SELL",
        entry_type: "SELL_LIMIT",
        entry_price: 3380.0,
        stop_loss: 3395.0,
        take_profit: 3350.0,
        max_take_profit: 3350.0,
        risk_reward: 2.0
      )
    end

    it "uses H1 resistance and caps entry distance in tactical mode" do
      snapshots = create_multi_timeframe_snapshots(
        price: 4334.0,
        rsi: 45,
        ema50: 4470,
        ema200: 4490,
        support: 4268.39,
        resistance: 4515.34
      )
      h1 = snapshots.find { |snapshot| snapshot.timeframe == "H1" }
      h1.update!(support: 4312.82, resistance: 4351.44)

      signal = TradeSignal.create!(
        market_snapshot: snapshots.find { |snapshot| snapshot.timeframe == "H4" },
        symbol: "XAUUSD",
        action: "SELL",
        confidence: 70,
        timeframe: "H1",
        reason: "Tactical sell"
      )

      original_mode = ENV["SHOGUNX_TRADING_MODE"]
      original_max = ENV["SHOGUNX_MAX_ENTRY_PIPS"]
      ENV["SHOGUNX_TRADING_MODE"] = "tactical"
      ENV["SHOGUNX_MAX_ENTRY_PIPS"] = "40"
      TradingMode.reset!

      plan = described_class.new(signal).call

      expect(plan[:entry_price]).to eq(4351.44)
      expect(plan[:entry_type]).to eq("SELL_LIMIT")
    ensure
      if original_mode.nil?
        ENV.delete("SHOGUNX_TRADING_MODE")
      else
        ENV["SHOGUNX_TRADING_MODE"] = original_mode
      end
      if original_max.nil?
        ENV.delete("SHOGUNX_MAX_ENTRY_PIPS")
      else
        ENV["SHOGUNX_MAX_ENTRY_PIPS"] = original_max
      end
      TradingMode.reset!
    end
  end

  describe "#take_profit_legs" do
    it "returns three capped take-profit legs for a BUY plan" do
      signal = build_trade_signal(action: "BUY", support: 3350.0, resistance: 3380.0, price: 3360.0)
      plan = described_class.new(signal).call

      legs = described_class.new(signal).take_profit_legs(plan)

      expect(legs.size).to eq(3)
      expect(legs.map { |leg| leg[:tp_leg] }).to eq([ 1, 2, 3 ])
      expect(legs.map { |leg| leg[:take_profit] }).to eq([ 3370.0, 3380.0, 3380.0 ])
      expect(legs.map { |leg| leg[:take_profit] }).to all(be <= plan[:max_take_profit])
    end

    it "returns three capped take-profit legs for a SELL plan" do
      signal = build_trade_signal(action: "SELL", support: 3350.0, resistance: 3380.0, price: 3355.0)
      plan = described_class.new(signal).call

      legs = described_class.new(signal).take_profit_legs(plan)

      expect(legs.size).to eq(3)
      expect(legs.map { |leg| leg[:take_profit] }).to eq([ 3360.0, 3350.0, 3350.0 ])
      expect(legs.map { |leg| leg[:take_profit] }).to all(be >= plan[:max_take_profit])
    end
  end

  describe "#create_orders_from_plan!" do
    it "returns nil for WAIT signals" do
      signal = build_trade_signal(action: "WAIT")

      expect {
        expect(described_class.new(signal).create_orders_from_plan!(nil)).to be_nil
      }.not_to change(Order, :count)
    end

    it "creates three pending orders with 20/30/40 pip take profits capped to structure" do
      signal = build_trade_signal(action: "BUY", support: 3350.0, resistance: 3380.0, price: 3360.0)
      expires_at = 1.day.from_now
      signal.update!(expires_at: expires_at)
      plan = described_class.new(signal).call

      orders = nil
      expect {
        orders = described_class.new(signal).create_orders_from_plan!(plan)
      }.to change(Order, :count).by(3)

      expect(orders.map(&:tp_leg)).to eq([ 1, 2, 3 ])
      expect(orders.map(&:take_profit)).to eq([ 3370.0, 3380.0, 3380.0 ])
      expect(orders).to all(have_attributes(
        action: "BUY",
        entry_type: "BUY_LIMIT",
        entry_price: 3350.0,
        stop_loss: 3335.0,
        status: "pending"
      ))
      expect(orders).to all(have_attributes(expires_at: be_within(1.second).of(expires_at)))
    end
  end

  describe "#create_order!" do
    it "creates the first TP leg order" do
      signal = build_trade_signal(action: "BUY", support: 3350.0, resistance: 3380.0, price: 3360.0)

      expect {
        order = described_class.new(signal).create_order!
        expect(order.tp_leg).to eq(1)
        expect(order.take_profit).to eq(3370.0)
      }.to change(Order, :count).by(3)
    end
  end
end
