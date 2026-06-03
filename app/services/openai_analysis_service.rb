class OpenaiAnalysisService
  DEFAULT_SYMBOL = "XAUUSD"
  ANALYSIS_TIMEFRAME = "H4"

  BUY_RSI_RANGE = (50..70).freeze
  SELL_RSI_RANGE = (30..50).freeze

  def initialize(symbol: DEFAULT_SYMBOL, summary_service: nil)
    @symbol = symbol
    @summary_service = summary_service
  end

  def call
    analyze(market_summary)
  end

  def market_summary
    @market_summary ||= summary_service.call
  end

  private

  def summary_service
    @summary_service ||= MarketSummaryService.new(symbol: @symbol)
  end

  def analyze(summary)
    ema50 = summary[:current_ema50]
    ema200 = summary[:current_ema200]
    rsi = summary[:current_rsi]

    if ema50.nil? || ema200.nil? || rsi.nil?
      return wait_signal("Insufficient market data for analysis")
    end

    rsi_value = rsi.to_f
    ema50_value = ema50.to_f
    ema200_value = ema200.to_f

    if buy_conditions?(ema50_value, ema200_value, rsi_value)
      return buy_signal(rsi_value)
    end

    if sell_conditions?(ema50_value, ema200_value, rsi_value)
      return sell_signal(rsi_value)
    end

    wait_signal(wait_reason(ema50_value, ema200_value, rsi_value))
  end

  def buy_conditions?(ema50, ema200, rsi)
    ema50 > ema200 && BUY_RSI_RANGE.cover?(rsi)
  end

  def sell_conditions?(ema50, ema200, rsi)
    ema50 < ema200 && SELL_RSI_RANGE.cover?(rsi)
  end

  def buy_signal(rsi)
    {
      action: "BUY",
      confidence: band_confidence(rsi, BUY_RSI_RANGE),
      timeframe: ANALYSIS_TIMEFRAME,
      reason: "EMA50 above EMA200 with RSI #{format_rsi(rsi)} in 50–70 range"
    }
  end

  def sell_signal(rsi)
    {
      action: "SELL",
      confidence: band_confidence(rsi, SELL_RSI_RANGE),
      timeframe: ANALYSIS_TIMEFRAME,
      reason: "EMA50 below EMA200 with RSI #{format_rsi(rsi)} in 30–50 range"
    }
  end

  def wait_signal(reason)
    {
      action: "WAIT",
      confidence: 0,
      timeframe: ANALYSIS_TIMEFRAME,
      reason: reason
    }
  end

  def wait_reason(ema50, ema200, rsi)
    if ema50 > ema200
      return "Bullish EMA trend but RSI #{format_rsi(rsi)} outside 50–70 buy range"
    end

    if ema50 < ema200
      return "Bearish EMA trend but RSI #{format_rsi(rsi)} outside 30–50 sell range"
    end

    "EMA50 and EMA200 aligned; RSI #{format_rsi(rsi)} does not meet entry rules"
  end

  def band_confidence(rsi, range)
    min = range.begin.to_f
    max = range.end.to_f
    span = max - min

    return 50 if span.zero?

    (((rsi - min) / span) * 100).round.clamp(1, 100)
  end

  def format_rsi(rsi)
    format("%.2f", rsi)
  end
end
