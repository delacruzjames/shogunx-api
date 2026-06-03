class ExecutionAuditLogService
  def initialize(source:, params:, order: nil, position: nil)
    @source = source
    @params = params
    @order = order
    @position = position
  end

  def record!
    ExecutionAuditLog.create!(
      order: @order,
      position: @position || @order&.position,
      source: @source,
      event_status: @params[:status].to_s,
      ticket: normalize_ticket(@params[:ticket]),
      entry_price: @params[:entry_price],
      profit_loss: @params[:profit_loss],
      payload: audit_payload
    )
  end

  private

  def audit_payload
    @params.to_h.deep_stringify_keys.slice(
      "order_id",
      "ticket",
      "status",
      "entry_price",
      "profit_loss",
      "exit_price"
    ).compact
  end

  def normalize_ticket(ticket)
    ticket.presence&.to_s
  end
end
