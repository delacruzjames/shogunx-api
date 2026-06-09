class TradingMode
  MODES = %w[conservative tactical].freeze
  DEFAULT = "conservative"
  ANALYSIS_TIMEFRAME = "H1"
  D1_DISAGREEMENT_PENALTY = 10
  TACTICAL_BASE_CONFIDENCE = 80
  D1_AGREEMENT_BONUS = 5
  TACTICAL_REASON = "Tactical trade against higher timeframe (D1) trend."

  CONSERVATIVE_RULES = <<~RULES.strip
    Rules:

    - Never force a trade.
    - Require D1, H4, and H1 trend alignment for BUY or SELL.
    - If timeframes are mixed, return WAIT.
    - If confidence is below 70, return WAIT.
    - Avoid trades within 60 minutes before major USD news.
    - Prefer trend continuation trades.
    - Penalize overextended price moves.
    - Reward pullbacks into support/resistance.
    - Consider higher highs, lower lows, break of structure and momentum shifts.

    Confidence Guide:

    90-100:
    Strong trend alignment across timeframes.

    70-89:
    Good setup with acceptable risk.

    50-69:
    Mixed signals.

    0-49:
    No trade.
  RULES

  TACTICAL_RULES = <<~RULES.strip
    Rules:

    - You are a daily XAUUSD trader looking for intraday setups, not weekly swing holds.
    - Never force a trade.
    - Prefer actionable BUY or SELL when H4 and H1 trends are aligned, even if D1 disagrees.
    - If H4 and H1 are not aligned, return WAIT.
    - If confidence is below 70, return WAIT.
    - Avoid trades within 60 minutes before major USD news.
    - Prefer trend continuation trades on H4 and H1.
    - Penalize overextended price moves.
    - Reward pullbacks into support/resistance.
    - Consider higher highs, lower lows, break of structure and momentum shifts.
    - When recommending a trade against the D1 trend, mention the tactical nature in your reason.

    Confidence Guide:

    90-100:
    Strong H4 and H1 alignment with excellent intraday setup quality.

    70-89:
    Good H4/H1 daily setup with acceptable risk.

    50-69:
    Weak or conflicting lower-timeframe signals.

    0-49:
    No trade.

    Note: A 10-point confidence penalty is applied automatically when D1 disagrees with the trade direction.
  RULES

  class << self
    def current
      @current ||= new(ENV.fetch("SHOGUNX_TRADING_MODE", DEFAULT))
    end

    def reset!
      @current = nil
    end
  end

  def initialize(mode)
    normalized = mode.to_s.downcase.strip
    raise ArgumentError, "Invalid trading mode: #{mode}" unless MODES.include?(normalized)

    @mode = normalized
  end

  attr_reader :mode

  def conservative?
    mode == "conservative"
  end

  def tactical?
    mode == "tactical"
  end

  def prompt_rules
    conservative? ? CONSERVATIVE_RULES : TACTICAL_RULES
  end

  def infer_daily_signal(summary, min_confidence:)
    return nil unless tactical?

    trends = timeframe_trends(summary)
    action = inferred_action(trends)
    return nil if action.nil?

    analysis = {
      action: action,
      confidence: TACTICAL_BASE_CONFIDENCE,
      timeframe: ANALYSIS_TIMEFRAME,
      reason: "Daily #{action} setup: H4 and H1 trends aligned"
    }

    if d1_disagrees?(trends["D1"], action)
      analysis = analysis.merge(
        confidence: analysis[:confidence] - D1_DISAGREEMENT_PENALTY,
        reason: append_tactical_reason(analysis[:reason])
      )
    elsif aligned?(trends, %w[D1], trend_for_action(action))
      analysis = analysis.merge(confidence: analysis[:confidence] + D1_AGREEMENT_BONUS)
    end

    return nil if analysis[:confidence] < min_confidence

    analysis
  end

  def apply_tradable_analysis(analysis, summary, min_confidence:)
    direction = trend_for_action(analysis[:action])
    trends = timeframe_trends(summary)

    if conservative?
      return wait_analysis("Mixed signals across timeframes") unless aligned?(trends, %w[D1 H4 H1], direction)
    elsif tactical?
      return wait_analysis("H4 and H1 trends not aligned") unless aligned?(trends, %w[H4 H1], direction)

      if d1_disagrees?(trends["D1"], analysis[:action])
        analysis = analysis.merge(
          confidence: analysis[:confidence] - D1_DISAGREEMENT_PENALTY,
          reason: append_tactical_reason(analysis[:reason])
        )
      end
    end

    enforce_min_confidence(analysis, min_confidence)
  end

  private

  def timeframe_trends(summary)
    MarketSnapshot::ANALYSIS_TIMEFRAMES.index_with do |timeframe|
      summary.dig(:timeframes, timeframe, :trend).to_s
    end
  end

  def trend_for_action(action)
    action == "BUY" ? "bullish" : "bearish"
  end

  def inferred_action(trends)
    return "SELL" if aligned?(trends, %w[H4 H1], "bearish")
    return "BUY" if aligned?(trends, %w[H4 H1], "bullish")

    nil
  end

  def aligned?(trends, timeframes, direction)
    timeframes.all? { |timeframe| trends[timeframe] == direction }
  end

  def d1_disagrees?(d1_trend, action)
    case action
    when "BUY" then d1_trend == "bearish"
    when "SELL" then d1_trend == "bullish"
    else false
    end
  end

  def append_tactical_reason(reason)
    base = reason.to_s.strip
    return TACTICAL_REASON if base.blank?
    return base if base.include?(TACTICAL_REASON)

    "#{base} #{TACTICAL_REASON}"
  end

  def enforce_min_confidence(analysis, min_confidence)
    return analysis if analysis[:confidence] >= min_confidence

    wait_analysis("Confidence #{analysis[:confidence]} below #{min_confidence} threshold")
  end

  def wait_analysis(reason)
    {
      action: "WAIT",
      confidence: 0,
      timeframe: ANALYSIS_TIMEFRAME,
      reason: reason
    }
  end
end
