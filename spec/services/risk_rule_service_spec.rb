require "rails_helper"

RSpec.describe RiskRuleService do
  def build_snapshot(**attrs)
    defaults = {
      symbol: "XAUUSD",
      timeframe: "H4",
      price: 3350,
      rsi: 60,
      ema50: 3360,
      ema200: 3340,
      support: 3350,
      resistance: 3380
    }

    MarketSnapshot.create!(defaults.merge(attrs))
  end

  def build_trade_signal(confidence: 75, action: "BUY", expires_at: nil, snapshot: nil)
    snapshot ||= build_snapshot

    TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: action,
      confidence: confidence,
      timeframe: "H4",
      expires_at: expires_at
    )
  end

  def build_order_plan(action: "BUY")
    {
      action: action,
      entry_type: "#{action}_LIMIT",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      risk_reward: 2.0
    }
  end

  def service(trade_signal:, plan: build_order_plan, open_positions: nil)
    described_class.new(
      trade_signal: trade_signal,
      order_plan: plan,
      open_positions: open_positions
    )
  end

  def create_open_position(action: "BUY", symbol: "XAUUSD")
    order = Order.create!(
      trade_signal: build_trade_signal(action: action),
      action: action,
      entry_type: "#{action}_LIMIT",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      risk_reward: 2.0,
      status: :triggered
    )

    Position.create!(
      order: order,
      ticket: "pos-#{SecureRandom.hex(6)}",
      symbol: symbol,
      action: action,
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      opened_at: Time.current
    )
  end

  describe "#call" do
    it "allows when all checks pass" do
      result = service(trade_signal: build_trade_signal(confidence: 80)).call

      expect(result).to eq(allowed: true, reason: "all checks passed")
    end

    it "rejects when pending orders already exist on MT4 for the symbol" do
      signal = build_trade_signal(action: "SELL", confidence: 80)
      Order.create!(
        trade_signal: signal,
        action: "SELL",
        entry_type: "SELL_LIMIT",
        entry_price: 3380,
        stop_loss: 3395,
        take_profit: 3350,
        risk_reward: 2.0,
        status: :pending,
        ticket: "123456"
      )

      result = service(trade_signal: build_trade_signal(action: "SELL", confidence: 80)).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("pending orders already exist")
    end

    it "allows when pending orders exist only in Rails awaiting MT4 placement" do
      signal = build_trade_signal(action: "SELL", confidence: 80)
      Order.create!(
        trade_signal: signal,
        action: "SELL",
        entry_type: "SELL_LIMIT",
        entry_price: 3380,
        stop_loss: 3395,
        take_profit: 3350,
        risk_reward: 2.0,
        status: :pending,
        ticket: nil
      )

      result = service(trade_signal: build_trade_signal(action: "SELL", confidence: 80)).call

      expect(result[:allowed]).to be(true)
    end

    it "rejects when an open XAUUSD position exists with opposing direction" do
      create_open_position(action: "BUY")

      result = service(trade_signal: build_trade_signal(action: "SELL")).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("existing open position")
    end

    it "allows when an open position exists for another symbol" do
      create_open_position(symbol: "EURUSD")

      result = service(trade_signal: build_trade_signal).call

      expect(result[:allowed]).to be(true)
    end

    it "rejects during high-impact USD news windows" do
      EconomicEvent.create!(
        source: "manual",
        currency: "USD",
        impact: "high",
        title: "CPI",
        scheduled_at: Time.current
      )

      result = service(trade_signal: build_trade_signal).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("high impact USD news: CPI")
    end

    it "rejects when confidence is below the threshold" do
      result = service(trade_signal: build_trade_signal(confidence: 69)).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("confidence below threshold")
    end

    it "rejects at confidence 69 and allows at 70" do
      low = service(trade_signal: build_trade_signal(confidence: 69)).call
      high = service(trade_signal: build_trade_signal(confidence: 70)).call

      expect(low[:reason]).to eq("confidence below threshold")
      expect(high[:allowed]).to be(true)
    end

    it "rejects when daily loss exceeds 3% of account size" do
      DailyPerformance.create!(date: Time.zone.today, profit_loss: -301)

      result = service(trade_signal: build_trade_signal).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("daily loss limit reached")
    end

    it "allows when daily loss is within 3% of account size" do
      DailyPerformance.create!(date: Time.zone.today, profit_loss: -299)

      result = service(trade_signal: build_trade_signal).call

      expect(result[:allowed]).to be(true)
    end

    it "allows when there is no daily performance record for today" do
      DailyPerformance.create!(date: Date.yesterday, profit_loss: -500)

      result = service(trade_signal: build_trade_signal).call

      expect(result[:allowed]).to be(true)
    end

    it "rejects duplicate signal action when open position direction matches" do
      create_open_position(action: "BUY")

      result = service(trade_signal: build_trade_signal(action: "BUY")).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("duplicate signal action")
    end

    it "rejects existing open position when direction differs" do
      create_open_position(action: "BUY")

      result = service(trade_signal: build_trade_signal(action: "SELL")).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("existing open position")
    end

    it "rejects when the trade signal has expired" do
      signal = build_trade_signal(expires_at: 1.hour.ago)

      result = service(trade_signal: signal).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("order expired")
    end

    it "allows when expires_at is in the future" do
      signal = build_trade_signal(expires_at: 1.hour.from_now)

      result = service(trade_signal: signal).call

      expect(result[:allowed]).to be(true)
    end

    it "returns the first failing rule in priority order" do
      create_open_position(action: "BUY")
      DailyPerformance.create!(date: Time.zone.today, profit_loss: -500)

      result = service(trade_signal: build_trade_signal(confidence: 10, action: "BUY")).call

      expect(result[:reason]).to eq("duplicate signal action")
    end
  end
end
