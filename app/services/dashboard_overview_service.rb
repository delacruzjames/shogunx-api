# Aggregates read-only dashboard fields for GET /api/v1/dashboard.
class DashboardOverviewService
  DEFAULT_SYMBOL = "XAUUSD"

  def initialize(symbol: DEFAULT_SYMBOL)
    @symbol = symbol
  end

  def call
    signal = latest_trade_signal
    execution = ExecutionInstructionService.new(format: :execution).call
    open_position = Position.open.order(opened_at: :desc).first
    today = DailyPerformanceService.new.call

    {
      generated_at: Time.current.iso8601,
      xauusd_price: latest_xauusd_price,
      latest_signal: signal ? JsonPresenter.trade_signal(signal) : nil,
      signal_confidence: signal&.confidence,
      order_status: order_status_label(execution),
      open_position_status: open_position_status_label(open_position),
      daily_pnl: today[:total_profit_loss],
      total_trades_today: today[:total_trades]
    }
  end

  private

  def latest_xauusd_price
    snapshot = MarketSnapshot
      .where(symbol: @symbol)
      .order(created_at: :desc, id: :desc)
      .first

    snapshot&.price
  end

  def latest_trade_signal
    TradeSignal.order(created_at: :desc, id: :desc).first
  end

  def order_status_label(execution)
    if execution[:action] == ExecutionInstructionService::EXECUTION_HOLD_ACTION
      "Hold — #{execution[:reason]}"
    else
      order_id = execution[:order_id] || "—"
      "#{execution[:action]} (order ##{order_id})"
    end
  end

  def open_position_status_label(position)
    return "No open position" if position.nil?

    "#{position.action} #{position.symbol} — #{position.status}"
  end
end
