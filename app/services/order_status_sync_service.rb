class OrderStatusSyncService
  Result = Struct.new(:success?, :order, :audit_log, :errors, keyword_init: true)

  SYNCABLE_STATUSES = %w[placed triggered cancelled expired closed].freeze

  def initialize(params)
    @params = params
  end

  def call
    order = Order.find_by(id: @params[:order_id])
    return failure([ "Order not found" ]) if order.nil?

    status = @params[:status]
    return failure([ "Status is required" ]) if status.blank?
    return failure([ "Unsupported order status" ]) unless SYNCABLE_STATUSES.include?(status)
    return failure([ "Ticket is required" ]) if @params[:ticket].blank?
    return failure([ "Profit/loss is required" ]) if status == "closed" && @params[:profit_loss].blank?

    position_result = nil
    apply_order_status!(order, status)

    if status == "closed"
      position_result = close_position_if_open!(order)
      return failure(position_result.errors) if position_result && !position_result.success?
    end

    order.reload
    audit_log = record_audit!(order, position_result&.position)

    Result.new(success?: true, order: order, audit_log: audit_log, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  def apply_order_status!(order, status)
    order.status = status
    order.ticket = normalize_ticket(@params[:ticket])
    apply_timestamps(order, status)
    order.save!
  end

  def close_position_if_open!(order)
    position = order.position
    return nil unless position&.open?

    PositionUpdateService.new(
      {
        order_id: order.id,
        ticket: order.ticket.presence || @params[:ticket],
        status: "closed",
        profit_loss: @params[:profit_loss],
        exit_price: @params[:exit_price]
      },
      audit: false
    ).call
  end

  def record_audit!(order, position)
    ExecutionAuditLogService.new(
      source: "order_updates",
      params: @params,
      order: order,
      position: position
    ).record!
  end

  def normalize_ticket(ticket)
    ticket.to_s
  end

  def apply_timestamps(order, status)
    case status
    when "placed", "triggered"
      order.opened_at ||= Time.current
    when "cancelled", "expired", "closed"
      order.closed_at ||= Time.current
    end
  end

  def failure(errors)
    Result.new(success?: false, order: nil, audit_log: nil, errors: errors)
  end
end
