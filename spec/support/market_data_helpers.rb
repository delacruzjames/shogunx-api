module MarketDataHelpers
  def create_multi_timeframe_snapshots(attrs = {})
    defaults = {
      symbol: "XAUUSD",
      price: 4448.87,
      rsi: 60.0,
      ema50: 4490.0,
      ema200: 4470.0,
      support: 4430.0,
      resistance: 4490.0
    }
    merged = defaults.merge(attrs)
    created_at = merged.delete(:created_at)

    MarketSnapshot::ANALYSIS_TIMEFRAMES.map do |timeframe|
      record_attrs = merged.merge(timeframe: timeframe)
      record_attrs[:created_at] = created_at if created_at
      MarketSnapshot.create!(record_attrs)
    end
  end
end
