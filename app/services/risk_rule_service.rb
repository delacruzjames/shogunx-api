class RiskRuleService
  MIN_CONFIDENCE = 70
  DEFAULT_ACCOUNT_SIZE = 10_000.0
  MAX_DAILY_LOSS_PERCENT = 3.0
  XAUUSD_SYMBOL = "XAUUSD"

  RULES = [
    :high_impact_news,
    :pending_orders_exist,
    :duplicate_signal_action,
    :existing_open_position,
    :confidence_below_threshold,
    :daily_loss_limit_reached,
    :order_expired
  ].freeze

  def initialize(trade_signal:, order_plan:, open_positions: nil)
    @trade_signal = trade_signal
    @order_plan = order_plan
    @open_positions = open_positions
  end

  def call
    failure = RULES.lazy.map { |rule| send(rule) }.detect(&:present?)
    return { allowed: false, reason: failure } if failure

    { allowed: true, reason: "all checks passed" }
  end

  private

  def pending_orders_exist
    return nil unless pending_orders_synced_to_mt4.exists?

    "pending orders already exist"
  end

  def existing_open_position
    return nil unless open_xauusd_positions.exists?

    "existing open position"
  end

  def confidence_below_threshold
    return nil if @trade_signal.confidence >= min_confidence

    "confidence below threshold"
  end

  def daily_loss_limit_reached
    performance = DailyPerformance.for_today
    return nil if performance.nil?

    loss_limit = account_size * (max_daily_loss_percent / 100.0)
    return nil if performance.profit_loss.to_f > -loss_limit

    "daily loss limit reached"
  end

  def high_impact_news
    result = NewsFilterService.new.call
    return nil if result[:allowed]

    result[:reason]
  end

  def duplicate_signal_action
    position = open_xauusd_positions.first
    return nil if position.nil?
    return nil unless @trade_signal.action == position.action

    "duplicate signal action"
  end

  def order_expired
    return nil unless signal_expired?

    "order expired"
  end

  def signal_expired?
    expires_at = @trade_signal.expires_at
    expires_at.present? && expires_at <= Time.current
  end

  def open_xauusd_positions
    @open_xauusd_positions ||= @open_positions || Position.open_positions.where(symbol: XAUUSD_SYMBOL)
  end

  def pending_orders_synced_to_mt4
    Order.pending
      .joins(:trade_signal)
      .where(trade_signals: { symbol: @trade_signal.symbol })
      .where.not(ticket: nil)
  end

  def min_confidence
    ENV.fetch("SHOGUNX_MIN_CONFIDENCE", MIN_CONFIDENCE).to_i
  end

  def account_size
    ENV.fetch("SHOGUNX_ACCOUNT_SIZE", DEFAULT_ACCOUNT_SIZE).to_f
  end

  def max_daily_loss_percent
    ENV.fetch("SHOGUNX_MAX_DAILY_LOSS_PERCENT", MAX_DAILY_LOSS_PERCENT).to_f
  end
end
