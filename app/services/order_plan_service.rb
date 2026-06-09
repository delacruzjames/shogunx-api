class OrderPlanService
  TARGET_RISK_REWARD = 2.0
  PRICE_PRECISION = 5
  RISK_REWARD_PRECISION = 2
  DEFAULT_TP_PIPS = [ 20, 30, 40 ].freeze
  # XAUUSD: 1 pip = $1 on price (e.g. 3350.00 → 3351.00). Override via SHOGUNX_PIP_SIZE.
  DEFAULT_PIP_SIZE = 1.0
  PIP_SIZE_BY_SYMBOL = {
    "XAUUSD" => 1.0
  }.freeze

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
    orders = create_orders_from_plan!(call)
    orders&.first
  end

  def create_orders_from_plan!(plan)
    return nil if plan.nil?

    legs = take_profit_legs(plan)
    return nil if legs.empty?

    legs.map { |leg| create_order_from_plan!(plan, leg) }
  end

  def create_order_from_plan!(plan, leg = nil)
    leg ||= take_profit_legs(plan).first
    return nil if leg.nil?

    Order.create!(
      trade_signal: @trade_signal,
      action: plan[:action],
      entry_type: plan[:entry_type],
      entry_price: plan[:entry_price],
      stop_loss: plan[:stop_loss],
      take_profit: leg[:take_profit],
      risk_reward: leg[:risk_reward],
      tp_leg: leg[:tp_leg],
      status: :pending,
      expires_at: @trade_signal.expires_at
    )
  end

  def tp_pips_for(_symbol)
    raw = ENV.fetch("SHOGUNX_TP_PIPS", DEFAULT_TP_PIPS.join(","))
    raw.split(",").filter_map { |value| Integer(value.strip, exception: false) }.select(&:positive?)
  end

  def take_profit_legs(plan)
    symbol = @trade_signal.symbol.to_s.upcase
    pip_size = pip_size_for(symbol)

    tp_pips_for(symbol).filter_map.with_index(1) do |pips, index|
      take_profit = take_profit_for_pips(
        action: plan[:action],
        entry_price: plan[:entry_price],
        pips: pips,
        pip_size: pip_size,
        max_take_profit: plan[:max_take_profit]
      )
      next if take_profit.nil?

      risk_reward = risk_reward(
        action: plan[:action],
        entry_price: plan[:entry_price],
        stop_loss: plan[:stop_loss],
        take_profit: take_profit
      )
      next if risk_reward.nil?

      {
        tp_leg: index,
        take_profit: take_profit,
        risk_reward: round_risk_reward(risk_reward)
      }
    end
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
    market_price = current_market_price
    return nil if market_price.nil?

    case @trade_signal.action
    when "BUY"
      entry_price = levels[:support]
      stop_loss = levels[:support] - levels[:buffer]
      max_take_profit = levels[:resistance]
      entry_type = entry_type_for_buy(entry_price, market_price)
    when "SELL"
      entry_price = levels[:resistance]
      stop_loss = levels[:resistance] + levels[:buffer]
      max_take_profit = levels[:support]
      entry_type = entry_type_for_sell(entry_price, market_price)
    else
      return nil
    end

    entry_price = round_price(entry_price)
    stop_loss = round_price(stop_loss)
    max_take_profit = round_price(max_take_profit)
    reward_ratio = risk_reward(
      action: @trade_signal.action,
      entry_price: entry_price,
      stop_loss: stop_loss,
      take_profit: max_take_profit
    )

    return nil if reward_ratio.nil?

    {
      action: @trade_signal.action,
      entry_type: entry_type,
      entry_price: entry_price,
      stop_loss: stop_loss,
      take_profit: max_take_profit,
      max_take_profit: max_take_profit,
      risk_reward: round_risk_reward(reward_ratio)
    }
  end

  def take_profit_for_pips(action:, entry_price:, pips:, pip_size:, max_take_profit:)
    offset = pips * pip_size

    take_profit = case action
    when "BUY"
      round_price([ entry_price + offset, max_take_profit ].min)
    when "SELL"
      round_price([ entry_price - offset, max_take_profit ].max)
    else
      return nil
    end

    return nil unless take_profit_valid?(action, entry_price, take_profit)

    take_profit
  end

  def take_profit_valid?(action, entry_price, take_profit)
    case action
    when "BUY"
      take_profit > entry_price
    when "SELL"
      take_profit < entry_price
    else
      false
    end
  end

  def pip_size_for(symbol)
    per_symbol = ENV.fetch("SHOGUNX_PIP_SIZE_BY_SYMBOL", "")
    unless per_symbol.blank?
      per_symbol.split(",").each do |pair|
        key, value = pair.split("=", 2).map(&:strip)
        next if key.blank? || value.blank?

        return value.to_f if key.upcase == symbol
      end
    end

    PIP_SIZE_BY_SYMBOL.fetch(symbol, ENV.fetch("SHOGUNX_PIP_SIZE", DEFAULT_PIP_SIZE).to_f)
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

  def current_market_price
    price = @trade_signal.market_snapshot&.price&.to_f
    return nil if price.nil? || price <= 0

    price
  end

  def entry_type_for_buy(entry_price, market_price)
    entry_price < market_price ? "BUY_LIMIT" : "BUY_STOP"
  end

  def entry_type_for_sell(entry_price, market_price)
    entry_price > market_price ? "SELL_LIMIT" : "SELL_STOP"
  end
end
