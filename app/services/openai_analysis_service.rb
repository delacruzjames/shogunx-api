class OpenaiAnalysisService
  class Error < StandardError; end
  class ApiError < Error; end
  class ParseError < Error; end

  MAX_RETRIES = 3
  DEFAULT_MODEL = "gpt-4o-mini"
  ANALYSIS_TIMEFRAME = "H4"

  PROMPT_TEMPLATE = <<~PROMPT
    You are a professional institutional XAUUSD trader.

    Analyze the market data and determine whether a new trade should be taken.

    Return ONLY valid JSON:

    {
      "action": "BUY|SELL|WAIT",
      "confidence": 0-100,
      "timeframe": "H4",
      "reason": "short explanation"
    }

    Evaluate:

    1. Daily trend
    2. H4 trend
    3. H1 momentum
    4. Market structure
    5. Support and resistance
    6. Risk-to-reward quality
    7. Volatility conditions
    8. Upcoming ForexFactory high-impact news

    Rules:

    - Never force a trade.
    - If signals are mixed, return WAIT.
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

    Market Summary:
    %{summary}

    News Context:
    %{news_context}
  PROMPT

  def initialize(
    market_snapshot:,
    symbol: nil,
    summary_service: nil,
    news_context_service: nil,
    chat_client: nil,
    max_retries: MAX_RETRIES
  )
    @market_snapshot = market_snapshot
    @symbol = symbol || market_snapshot.symbol
    @summary_service = summary_service
    @news_context_service = news_context_service
    @chat_client = chat_client
    @max_retries = max_retries
  end

  def call
    summary = market_summary
    analysis =
      if insufficient_data?(summary)
        wait_analysis("Insufficient market data for analysis")
      else
        analyze_with_openai(summary)
      end

    create_trade_signal!(analysis)
  end

  def market_summary
    @market_summary ||= summary_service.call
  end

  private

  def summary_service
    @summary_service ||= MarketSummaryService.new(symbol: @symbol)
  end

  def chat_client
    @chat_client ||= Openai::ChatClient.build
  end

  def insufficient_data?(summary)
    MarketSnapshot::ANALYSIS_TIMEFRAMES.any? do |timeframe|
      timeframe_insufficient?(summary.dig(:timeframes, timeframe))
    end
  end

  def timeframe_insufficient?(timeframe_summary)
    return true if timeframe_summary.blank? || !timeframe_summary[:available]

    timeframe_summary[:current_price].nil? ||
      timeframe_summary[:average_rsi].nil? ||
      timeframe_summary[:current_ema50].nil? ||
      timeframe_summary[:current_ema200].nil?
  end

  def analyze_with_openai(summary)
    return wait_analysis("OpenAI API key not configured") if @chat_client.nil? && api_key.blank?

    with_retries do
      prompt = build_prompt(summary)
      log_prompt(prompt)
      content = request_chat(prompt)
      log_response(content)
      normalize_analysis(parse_response(content))
    end
  rescue Error => error
    wait_analysis("OpenAI analysis failed: #{error.message}")
  end

  def with_retries
    attempt = 0

    begin
      attempt += 1
      yield
    rescue ApiError, ParseError => error
      raise error if attempt >= @max_retries

      sleep(attempt * 0.5)
      retry
    end
  end

  def build_prompt(summary)
    format(
      PROMPT_TEMPLATE,
      summary: format_summary(summary),
      news_context: news_context_service.format_for_prompt
    )
  end

  def news_context_service
    @news_context_service ||= NewsContextService.new
  end

  def format_summary(summary)
    lines = [ "symbol: #{summary[:symbol]}" ]

    MarketSnapshot::ANALYSIS_TIMEFRAMES.each do |timeframe|
      lines << ""
      lines << "#{timeframe} timeframe:"
      lines.concat(format_timeframe_lines(summary.dig(:timeframes, timeframe)))
    end

    lines.join("\n")
  end

  def format_timeframe_lines(timeframe_summary)
    return [ "  data unavailable" ] if timeframe_summary.blank? || !timeframe_summary[:available]

    [
      "  price: #{timeframe_summary[:current_price]}",
      "  rsi: #{timeframe_summary[:current_rsi]} (avg #{timeframe_summary[:average_rsi]})",
      "  ema50: #{timeframe_summary[:current_ema50]} (#{timeframe_summary[:ema50_trend]})",
      "  ema200: #{timeframe_summary[:current_ema200]} (#{timeframe_summary[:ema200_trend]})",
      "  trend: #{timeframe_summary[:trend]}",
      "  support: #{timeframe_summary[:support]}",
      "  resistance: #{timeframe_summary[:resistance]}",
      "  snapshots: #{timeframe_summary[:snapshot_count]}"
    ]
  end

  def request_chat(prompt)
    response = chat_client.chat(
      parameters: {
        model: model,
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You are a professional institutional XAUUSD trader. Respond only with valid JSON."
          },
          { role: "user", content: prompt }
        ]
      }
    )

    content = response.dig("choices", 0, "message", "content")
    raise ApiError, "Empty response from OpenAI" if content.blank?

    content
  rescue Faraday::Error, ::OpenAI::Error => error
    raise ApiError, error.message
  end

  def parse_response(content)
    cleaned = content.to_s.strip
    cleaned = cleaned.gsub(/\A```json\s*/i, "").gsub(/\A```\s*/, "").gsub(/```\z/, "").strip

    JSON.parse(cleaned)
  rescue JSON::ParserError => error
    raise ParseError, error.message
  end

  def normalize_analysis(payload)
    action = payload["action"].to_s.upcase
    raise ParseError, "Invalid action: #{action}" unless TradeSignal::ACTIONS.include?(action)

    confidence = payload["confidence"].to_i.clamp(0, 100)
    if tradable_action?(action) && confidence < min_confidence
      return wait_analysis("Confidence #{confidence} below #{min_confidence} threshold")
    end

    {
      action: action,
      confidence: confidence,
      timeframe: payload["timeframe"].presence || ANALYSIS_TIMEFRAME,
      reason: payload["reason"].to_s.presence || "No reason provided"
    }
  end

  def tradable_action?(action)
    action.in?(%w[BUY SELL])
  end

  def min_confidence
    ENV.fetch("SHOGUNX_MIN_CONFIDENCE", RiskRuleService::MIN_CONFIDENCE).to_i
  end

  def create_trade_signal!(analysis)
    TradeSignal.create!(
      market_snapshot: @market_snapshot,
      symbol: @symbol,
      action: analysis[:action],
      confidence: analysis[:confidence],
      timeframe: analysis[:timeframe],
      reason: analysis[:reason]
    )
  end

  def wait_analysis(reason)
    {
      action: "WAIT",
      confidence: 0,
      timeframe: ANALYSIS_TIMEFRAME,
      reason: reason
    }
  end

  def api_key
    ENV["OPENAI_API_KEY"].presence
  end

  def model
    ENV.fetch("OPENAI_MODEL", DEFAULT_MODEL)
  end

  def log_prompt(prompt)
    Rails.logger.info("[OpenaiAnalysisService] prompt=#{prompt}")
  end

  def log_response(content)
    Rails.logger.info("[OpenaiAnalysisService] response=#{content}")
  end
end
