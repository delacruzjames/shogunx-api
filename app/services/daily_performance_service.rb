class DailyPerformanceService
  def initialize(date: Time.zone.today)
    @date = date.to_date
  end

  def call
    trades = TradePerformance.for_day(@date)
    total_trades = trades.count
    wins = trades.where("profit_loss > 0").count
    losses = trades.where("profit_loss < 0").count

    {
      date: @date,
      total_trades: total_trades,
      wins: wins,
      losses: losses,
      win_rate: win_rate(wins, total_trades),
      total_profit_loss: trades.sum(:profit_loss).to_d
    }
  end

  def record!
    stats = call
    performance = DailyPerformance.find_or_initialize_by(date: @date)
    performance.update!(profit_loss: stats[:total_profit_loss])
    stats
  end

  private

  def win_rate(wins, total_trades)
    return 0.0 if total_trades.zero?

    ((wins.to_f / total_trades) * 100).round(2)
  end
end
