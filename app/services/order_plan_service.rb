class OrderPlanService
  TARGET_RISK_REWARD = 2.0
  PRICE_PRECISION = 5
  RISK_REWARD_PRECISION = 2

  def initialize(trade_signal)
    @trade_signal = trade_signal
  end

  def call
    return nil if @trade_signal.action == "WAIT"

    levels = price_levels
    return nil if levels.nil?

    build_plan(levels)
  end

  def create_order!
    plan = call
    return nil if plan.nil?

    create_order_from_plan!(plan)
  end

  def create_order_from_plan!(plan)
    Order.create!(
      trade_signal: @trade_signal,
      action: plan[:action],
      entry_type: plan[:entry_type],
      entry_price: plan[:entry_price],
      stop_loss: plan[:stop_loss],
      take_profit: plan[:take_profit],
      risk_reward: plan[:risk_reward],
      status: :pending,
      expires_at: @trade_signal.expires_at
    )
  end

  private

  def price_levels
    snapshot = @trade_signal.market_snapshot
    support = snapshot&.support&.to_f
    resistance = snapshot&.resistance&.to_f

    return nil if support.nil? || resistance.nil? || support >= resistance

    range = resistance - support
    buffer = range / TARGET_RISK_REWARD

    {
      support: support,
      resistance: resistance,
      buffer: buffer
    }
  end

  def build_plan(levels)
    case @trade_signal.action
    when "BUY"
      entry_price = levels[:support]
      stop_loss = levels[:support] - levels[:buffer]
      take_profit = levels[:resistance]
      entry_type = "BUY_LIMIT"
    when "SELL"
      entry_price = levels[:resistance]
      stop_loss = levels[:resistance] + levels[:buffer]
      take_profit = levels[:support]
      entry_type = "SELL_LIMIT"
    else
      return nil
    end

    entry_price = round_price(entry_price)
    stop_loss = round_price(stop_loss)
    take_profit = round_price(take_profit)
    reward_ratio = risk_reward(
      action: @trade_signal.action,
      entry_price: entry_price,
      stop_loss: stop_loss,
      take_profit: take_profit
    )

    return nil if reward_ratio.nil?

    {
      action: @trade_signal.action,
      entry_type: entry_type,
      entry_price: entry_price,
      stop_loss: stop_loss,
      take_profit: take_profit,
      risk_reward: round_risk_reward(reward_ratio)
    }
  end

  def risk_reward(action:, entry_price:, stop_loss:, take_profit:)
    risk, reward = case action
    when "BUY"
      [ entry_price - stop_loss, take_profit - entry_price ]
    when "SELL"
      [ stop_loss - entry_price, entry_price - take_profit ]
    else
      return nil
    end

    return nil if risk <= 0 || reward <= 0

    reward / risk
  end

  def round_price(value)
    value.to_f.round(PRICE_PRECISION)
  end

  def round_risk_reward(value)
    value.to_f.round(RISK_REWARD_PRECISION)
  end
end
