# Aggregates closed-trade metrics for dashboards and reporting.
class TradePerformanceService
  DEFAULT_DAILY_WINDOW = 30
  DEFAULT_MONTHLY_WINDOW = 12

  def initialize(from: nil, to: nil, symbol: nil, daily_days: DEFAULT_DAILY_WINDOW, monthly_months: DEFAULT_MONTHLY_WINDOW)
    @to = (to || Time.zone.today).to_date
    @from = (from || @to - (daily_days - 1).days).to_date
    @symbol = symbol.presence
    @daily_days = daily_days
    @monthly_months = monthly_months
  end

  def call
    trades = load_trades
    trade_rows = trades.to_a

    {
      generated_at: Time.current.iso8601,
      period: {
        from: @from.iso8601,
        to: @to.iso8601,
        symbol: @symbol
      },
      summary: build_summary(trade_rows),
      daily_pnl: build_daily_pnl(trade_rows),
      monthly_pnl: build_monthly_pnl(trade_rows)
    }
  end

  private

  def load_trades
    scope = TradePerformance.closed_between(@from, @to)
    scope = scope.for_symbol(@symbol) if @symbol
    scope.includes(position: :order).order(closed_at: :asc)
  end

  def build_summary(trades)
    total_trades = trades.size
    wins = count_wins(trades)
    losses = count_losses(trades)
    breakeven = total_trades - wins - losses
    gross_profit = sum_positive(trades)
    gross_loss = sum_negative_abs(trades)

    {
      total_trades: total_trades,
      wins: wins,
      losses: losses,
      breakeven: breakeven,
      win_rate: win_rate(wins, total_trades),
      profit_factor: profit_factor(gross_profit, gross_loss),
      average_rr: average_rr(trades),
      total_profit_loss: round_decimal(sum_profit_loss(trades)),
      gross_profit: round_decimal(gross_profit),
      gross_loss: round_decimal(gross_loss)
    }
  end

  def build_daily_pnl(trades)
    grouped = trades.group_by { |trade| trade.closed_at.in_time_zone.to_date }
    daily_range = (@to - (@daily_days - 1).days)..@to

    daily_range.map do |date|
      day_trades = grouped[date] || []
      {
        date: date.iso8601,
        profit_loss: round_decimal(sum_profit_loss(day_trades)),
        trades: day_trades.size,
        wins: count_wins(day_trades),
        losses: count_losses(day_trades)
      }
    end
  end

  def build_monthly_pnl(trades)
    grouped = trades.group_by { |trade| trade.closed_at.in_time_zone.strftime("%Y-%m") }
    month_keys = month_range_keys

    month_keys.map do |month|
      month_trades = grouped[month] || []
      {
        month: month,
        profit_loss: round_decimal(sum_profit_loss(month_trades)),
        trades: month_trades.size,
        wins: count_wins(month_trades),
        losses: count_losses(month_trades)
      }
    end
  end

  def month_range_keys
    start_month = (@to.beginning_of_month - (@monthly_months - 1).months).to_date

    (0...@monthly_months).map do |offset|
      (start_month + offset.months).strftime("%Y-%m")
    end
  end

  def count_wins(trades)
    trades.count { |trade| trade.profit_loss.to_d.positive? }
  end

  def count_losses(trades)
    trades.count { |trade| trade.profit_loss.to_d.negative? }
  end

  def sum_positive(trades)
    trades.sum { |trade| [ trade.profit_loss.to_d, 0 ].max }
  end

  def sum_negative_abs(trades)
    trades.sum { |trade| trade.profit_loss.to_d.negative? ? trade.profit_loss.to_d.abs : 0 }
  end

  def sum_profit_loss(trades)
    trades.sum { |trade| trade.profit_loss.to_d }
  end

  def win_rate(wins, total_trades)
    return 0.0 if total_trades.zero?

    ((wins.to_f / total_trades) * 100).round(2)
  end

  def profit_factor(gross_profit, gross_loss)
    return 0.0 if gross_profit.zero? && gross_loss.zero?
    return nil if gross_loss.zero?

    (gross_profit / gross_loss).round(2)
  end

  def average_rr(trades)
    values = trades.filter_map { |trade| trade.position&.order&.risk_reward&.to_d }
    return 0.0 if values.empty?

    (values.sum / values.size).round(2)
  end

  def round_decimal(value)
    value.to_d.round(2)
  end
end
