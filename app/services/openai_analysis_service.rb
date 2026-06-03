class OpenaiAnalysisService
  DEFAULT_SYMBOL = "XAUUSD"
  SNAPSHOT_LIMIT = 10

  def initialize(symbol: DEFAULT_SYMBOL)
    @symbol = symbol
  end

  def call
    market_summary
    stub_response
  end

  def market_summary
    @market_summary ||= build_market_summary
  end

  private

  def snapshots
    @snapshots ||= MarketSnapshot
      .where(symbol: @symbol)
      .order(created_at: :desc)
      .limit(SNAPSHOT_LIMIT)
  end

  def build_market_summary
    {
      symbol: @symbol,
      snapshot_count: snapshots.size,
      snapshots: snapshots.map { |snapshot| snapshot_summary(snapshot) }
    }
  end

  def snapshot_summary(snapshot)
    {
      id: snapshot.id,
      timeframe: snapshot.timeframe,
      price: snapshot.price,
      rsi: snapshot.rsi,
      ema50: snapshot.ema50,
      ema200: snapshot.ema200,
      support: snapshot.support,
      resistance: snapshot.resistance,
      captured_at: snapshot.created_at
    }
  end

  def stub_response
    {
      action: "WAIT",
      confidence: 0,
      timeframe: "H4",
      reason: "Not implemented"
    }
  end
end
