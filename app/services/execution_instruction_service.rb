class ExecutionInstructionService
  HOLD_ACTION = "hold"
  HOLD_REASON = "no pending order available"
  READY_REASON = "pending order ready for MT4 execution"

  EXECUTION_HOLD_ACTION = "HOLD"
  EXECUTION_HOLD_REASON = "No approved trade available"

  def initialize(order: nil, format: :nested)
    @order = order
    @format = format
  end

  def call
    order = @order || latest_pending_order
    return hold_instruction if order.nil?

    executable_instruction(order)
  end

  private

  def latest_pending_order
    Order.pending.order(created_at: :desc).first
  end

  def executable_instruction(order)
    case @format
    when :execution
      execution_payload(order)
    else
      {
        order: {
          action: order.entry_type,
          order_id: order.id,
          symbol: order.trade_signal.symbol,
          entry_price: order.entry_price,
          stop_loss: order.stop_loss,
          take_profit: order.take_profit,
          reason: READY_REASON
        }
      }
    end
  end

  def hold_instruction
    case @format
    when :execution
      {
        action: EXECUTION_HOLD_ACTION,
        reason: EXECUTION_HOLD_REASON
      }
    else
      {
        order: {
          action: HOLD_ACTION,
          reason: HOLD_REASON
        }
      }
    end
  end

  def execution_payload(order)
    payload = {
      action: order.entry_type,
      order_id: order.id,
      symbol: order.trade_signal.symbol,
      entry_price: order.entry_price,
      stop_loss: order.stop_loss,
      take_profit: order.take_profit
    }
    payload[:expires_at] = order.expires_at.iso8601 if order.expires_at.present?
    payload
  end
end
