class MarketSummaryService
  DEFAULT_SYMBOL = "XAUUSD"
  SNAPSHOT_LIMIT = 10

  def initialize(symbol: DEFAULT_SYMBOL)
    @symbol = symbol
  end

  def call
    timeframes = MarketSnapshot::ANALYSIS_TIMEFRAMES.index_with { |timeframe| build_timeframe_summary(timeframe) }
    primary = timeframes[MarketSnapshot::PRIMARY_TIMEFRAME]

    legacy_summary_fields(primary).merge(
      symbol: @symbol,
      timeframes: timeframes,
      snapshot_count: timeframes.values.sum { |summary| summary[:snapshot_count] }
    )
  end

  private

  def build_timeframe_summary(timeframe)
    snapshots = snapshots_for(timeframe)
    current = snapshots.first
    return unavailable_timeframe_summary(timeframe) if current.nil?

    {
      timeframe: timeframe,
      available: true,
      current_price: current.price,
      current_rsi: current.rsi,
      current_ema50: current.ema50,
      current_ema200: current.ema200,
      support: current.support,
      resistance: current.resistance,
      trend: determine_trend(current),
      ema50_trend: ema_trend(snapshots, :ema50),
      ema200_trend: ema_trend(snapshots, :ema200),
      average_rsi: average_rsi(snapshots),
      snapshot_count: snapshots.size
    }
  end

  def unavailable_timeframe_summary(timeframe)
    {
      timeframe: timeframe,
      available: false,
      current_price: nil,
      current_rsi: nil,
      current_ema50: nil,
      current_ema200: nil,
      support: nil,
      resistance: nil,
      trend: "neutral",
      ema50_trend: "unknown",
      ema200_trend: "unknown",
      average_rsi: nil,
      snapshot_count: 0
    }
  end

  def legacy_summary_fields(primary)
    {
      current_price: primary[:current_price],
      current_rsi: primary[:current_rsi],
      current_ema50: primary[:current_ema50],
      current_ema200: primary[:current_ema200],
      support: primary[:support],
      resistance: primary[:resistance],
      timeframe: primary[:timeframe],
      trend: primary[:trend],
      ema50_trend: primary[:ema50_trend],
      ema200_trend: primary[:ema200_trend],
      average_rsi: primary[:average_rsi]
    }
  end

  def snapshots_for(timeframe)
    MarketSnapshot
      .where(symbol: @symbol, timeframe: timeframe)
      .order(created_at: :desc)
      .limit(SNAPSHOT_LIMIT)
  end

  def ema_trend(snapshots, field)
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

  def average_rsi(snapshots)
    values = snapshots.map(&:rsi).compact
    return nil if values.empty?

    values.sum / values.size.to_f
  end
end
