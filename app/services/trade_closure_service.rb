class TradeClosureService
  Result = Struct.new(:success?, :trade_performance, :errors, keyword_init: true)

  def initialize(position, exit_price: nil, profit_loss: nil)
    @position = position
    @exit_price = exit_price
    @profit_loss = profit_loss
  end

  def call
    return failure([ "Position is not closed" ]) unless @position.closed?
    return failure([ "Exit price can't be blank" ]) if @exit_price.blank?
    return failure([ "Profit/loss can't be blank" ]) if resolved_profit_loss.nil?

    trade_performance = nil

    ActiveRecord::Base.transaction do
      persist_profit_loss!
      close_order!
      trade_performance = create_trade_performance!
      DailyPerformanceService.new.record!
    end

    Result.new(success?: true, trade_performance: trade_performance, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  def persist_profit_loss!
    return if resolved_profit_loss.nil?

    @position.update!(profit_loss: resolved_profit_loss)
  end

  def close_order!
    order = @position.order
    order.update!(
      status: :closed,
      closed_at: order.closed_at || @position.closed_at || Time.current
    )
  end

  def create_trade_performance!
    return @position.trade_performance if @position.trade_performance.present?

    TradePerformance.create!(
      position: @position,
      symbol: @position.symbol,
      action: @position.action,
      entry_price: @position.entry_price,
      exit_price: @exit_price.to_d,
      profit_loss: resolved_profit_loss,
      opened_at: @position.opened_at,
      closed_at: @position.closed_at
    )
  end

  def resolved_profit_loss
    value = @profit_loss.nil? ? @position.profit_loss : @profit_loss
    value.nil? ? nil : value.to_d
  end

  def failure(errors)
    Result.new(success?: false, trade_performance: nil, errors: errors)
  end
end
