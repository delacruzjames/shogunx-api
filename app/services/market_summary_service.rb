class MarketSummaryService
  DEFAULT_SYMBOL = "XAUUSD"
  SNAPSHOT_LIMIT = 10

  def initialize(symbol: DEFAULT_SYMBOL)
    @symbol = symbol
  end

  def call
    build_summary
  end

  private

  def snapshots
    @snapshots ||= MarketSnapshot
      .where(symbol: @symbol)
      .order(created_at: :desc)
      .limit(SNAPSHOT_LIMIT)
  end

  def latest
    snapshots.first
  end

  def build_summary
    current = latest

    return empty_summary if current.nil?

    {
      symbol: @symbol,
      current_price: current.price,
      current_rsi: current.rsi,
      current_ema50: current.ema50,
      current_ema200: current.ema200,
      support: current.support,
      resistance: current.resistance,
      timeframe: current.timeframe,
      trend: determine_trend(current),
      ema50_trend: ema_trend(:ema50),
      ema200_trend: ema_trend(:ema200),
      average_rsi: average_rsi,
      snapshot_count: snapshots.size
    }
  end

  def empty_summary
    {
      symbol: @symbol,
      current_price: nil,
      current_rsi: nil,
      current_ema50: nil,
      current_ema200: nil,
      support: nil,
      resistance: nil,
      timeframe: nil,
      trend: "neutral",
      ema50_trend: "unknown",
      ema200_trend: "unknown",
      average_rsi: nil,
      snapshot_count: 0
    }
  end

  def ema_trend(field)
    values = snapshots.reverse.map { |snapshot| snapshot.public_send(field) }.compact
    return "unknown" if values.size < 2

    oldest, latest = values.first, values.last
    return "rising" if latest > oldest
    return "falling" if latest < oldest

    "flat"
  end

  def determine_trend(snapshot)
    ema50 = snapshot.ema50
    ema200 = snapshot.ema200

    return "neutral" if ema50.nil? || ema200.nil?
    return "bullish" if ema50 > ema200
    return "bearish" if ema50 < ema200

    "neutral"
  end

  def average_rsi
    values = snapshots.map(&:rsi).compact
    return nil if values.empty?

    values.sum / values.size.to_f
  end
end
