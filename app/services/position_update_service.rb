class PositionUpdateService
  Result = Struct.new(:success?, :position, :audit_log, :errors, keyword_init: true)

  SYNCABLE_STATUSES = %w[open closed].freeze

  def initialize(params = nil, audit: true, **keyword_params)
    @audit = audit
    base = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : (params.is_a?(Hash) ? params : {})
    @params = base.symbolize_keys.merge(keyword_params.symbolize_keys)
  end

  def call
    order = Order.find_by(id: @params[:order_id])
    return failure([ "Order not found" ]) if order.nil?
    return failure([ "Status is required" ]) if @params[:status].blank?
    return failure([ "Ticket is required" ]) if @params[:ticket].blank?
    return failure([ "Unsupported position status" ]) unless SYNCABLE_STATUSES.include?(@params[:status])
    return failure([ "Profit/loss is required" ]) if @params[:status] == "closed" && @params[:profit_loss].blank?

    sync_result = PositionSyncService.new(sync_params(order)).call
    return failure(sync_result.errors) unless sync_result.success?

    audit_log = record_audit!(order, sync_result.position) if @audit

    Result.new(
      success?: true,
      position: sync_result.position.reload,
      audit_log: audit_log,
      errors: []
    )
  end

  private

  def sync_params(order)
    entry_price = @params[:entry_price].presence || order.entry_price
    exit_price = @params[:exit_price].presence || infer_exit_price(order)

    {
      order_id: order.id,
      ticket: normalize_ticket(@params[:ticket]),
      status: @params[:status],
      symbol: order.trade_signal.symbol,
      action: order.action,
      entry_price: entry_price,
      stop_loss: order.stop_loss,
      take_profit: order.take_profit,
      profit_loss: @params[:profit_loss],
      exit_price: exit_price
    }.compact
  end

  def infer_exit_price(order)
    return nil unless @params[:status] == "closed"

    profit_loss = @params[:profit_loss].to_d
    profitable = profit_loss >= 0

    if profitable
      order.take_profit.presence || order.entry_price
    else
      order.stop_loss.presence || order.entry_price
    end
  end

  def record_audit!(order, position)
    ExecutionAuditLogService.new(
      source: "position_updates",
      params: @params,
      order: order,
      position: position
    ).record!
  end

  def normalize_ticket(ticket)
    ticket.to_s
  end

  def failure(errors)
    Result.new(success?: false, position: nil, audit_log: nil, errors: errors)
  end
end
