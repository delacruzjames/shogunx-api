class OpenaiAnalysisService
  class Error < StandardError; end
  class ApiError < Error; end
  class ParseError < Error; end

  MAX_RETRIES = 3
  DEFAULT_MODEL = "gpt-4o-mini"
  ANALYSIS_TIMEFRAME = "H4"

  PROMPT_TEMPLATE = <<~PROMPT
    You are a professional XAUUSD trader.

    Analyze the following market summary.

    Return ONLY JSON:

    {
      "action": "BUY|SELL|WAIT",
      "confidence": 0-100,
      "timeframe": "H4",
      "reason": "short explanation"
    }

    Consider:

    - trend
    - momentum
    - support/resistance
    - risk/reward
    - USD high-impact news calendar and trading blackout windows

    Market Summary:
    %{summary}

    News Context (ForexFactory calendar):
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
    summary[:snapshot_count].to_i.zero? ||
      summary[:current_price].nil? ||
      summary[:average_rsi].nil? ||
      summary[:current_ema50].nil? ||
      summary[:current_ema200].nil?
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
    <<~SUMMARY.strip
      symbol: #{summary[:symbol]}
      current_price: #{summary[:current_price]}
      average_rsi: #{summary[:average_rsi]}
      ema50_trend: #{summary[:ema50_trend]}
      ema200_trend: #{summary[:ema200_trend]}
      support: #{summary[:support]}
      resistance: #{summary[:resistance]}
      timeframe: #{summary[:timeframe] || ANALYSIS_TIMEFRAME}
    SUMMARY
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
            content: "You are a professional XAUUSD trader. Respond only with valid JSON."
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

    {
      action: action,
      confidence: payload["confidence"].to_i.clamp(0, 100),
      timeframe: payload["timeframe"].presence || ANALYSIS_TIMEFRAME,
      reason: payload["reason"].to_s.presence || "No reason provided"
    }
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
