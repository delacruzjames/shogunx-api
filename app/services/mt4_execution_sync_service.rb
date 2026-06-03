# Orchestrates the MT4 → Rails execution feedback loop.
#
# Lifecycle:
#   pending  → order_updates(placed)
#   filled   → order_updates(triggered) → position_updates(open)
#   closed   → position_updates(closed)  → updates Order, Position, TradePerformance
class Mt4ExecutionSyncService
  Result = Struct.new(:success?, :order, :position, :errors, keyword_init: true)

  def initialize(order)
    @order = order
  end

  def record_placed!(ticket:)
    sync_order_status("placed", ticket: ticket)
  end

  def record_triggered!(ticket:)
    sync_order_status("triggered", ticket: ticket)
  end

  def record_open!(ticket:, entry_price:)
    result = PositionUpdateService.new(
      {
        order_id: @order.id,
        ticket: ticket,
        status: "open",
        entry_price: entry_price
      }
    ).call

    build_result(result, @order.reload)
  end

  def record_closed!(ticket:, profit_loss:, exit_price: nil)
    result = PositionUpdateService.new(
      {
        order_id: @order.id,
        ticket: ticket,
        status: "closed",
        profit_loss: profit_loss,
        exit_price: exit_price
      }
    ).call

    build_result(result, @order.reload)
  end

  def lifecycle_state
    order = @order.reload
    position = order.position

    {
      order_id: order.id,
      order_status: order.status,
      ticket: order.ticket,
      position_status: position&.status,
      profit_loss: position&.profit_loss,
      trade_performance_recorded: position&.trade_performance.present?
    }
  end

  private

  def sync_order_status(status, ticket:)
    result = OrderStatusSyncService.new(
      order_id: @order.id,
      ticket: ticket,
      status: status
    ).call

    build_result(result, result.order)
  end

  def build_result(result, record)
    if result.success?
      order = record.is_a?(Order) ? record : record&.order
      position = result.try(:position) || order&.position

      Result.new(success?: true, order: order, position: position, errors: [])
    else
      Result.new(success?: false, order: nil, position: nil, errors: result.errors)
    end
  end
end
