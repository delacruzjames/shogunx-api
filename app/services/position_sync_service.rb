class PositionSyncService
  Result = Struct.new(:success?, :position, :errors, keyword_init: true)

  SYNCABLE_STATUSES = %w[open closed cancelled].freeze

  def initialize(params)
    @params = params
  end

  def call
    order = Order.find_by(id: @params[:order_id])
    return failure([ "Order not found" ]) if order.nil?
    return failure([ "Status is required" ]) if @params[:status].blank?
    return failure([ "Unsupported position status" ]) unless SYNCABLE_STATUSES.include?(@params[:status])

    position = find_or_build_position(order)
    closure_result = nil

    ActiveRecord::Base.transaction do
      position.update!(position_attributes(position))

      case @params[:status]
      when "open"
        update_order_status!(order)
      when "closed"
        closure_result = TradeClosureService.new(
          position,
          exit_price: @params[:exit_price],
          profit_loss: @params[:profit_loss]
        ).call
        raise ActiveRecord::Rollback unless closure_result.success?
      else
        update_order_status!(order)
      end
    end

    return failure(closure_result.errors) if closure_result && !closure_result.success?

    Result.new(success?: true, position: position, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  def find_or_build_position(order)
    Position.find_by(ticket: @params[:ticket]) ||
      order.position ||
      Position.new(order: order)
  end

  def position_attributes(position)
    attributes = {
      ticket: @params[:ticket],
      symbol: @params[:symbol],
      action: @params[:action],
      entry_price: @params[:entry_price],
      stop_loss: @params[:stop_loss],
      take_profit: @params[:take_profit],
      status: @params[:status],
      profit_loss: @params[:profit_loss]
    }

    case @params[:status]
    when "open"
      attributes[:opened_at] = @params[:opened_at] || position.opened_at || Time.current
      attributes[:closed_at] = nil
    when "closed", "cancelled"
      attributes[:closed_at] = @params[:closed_at] || Time.current
    end

    attributes
  end

  def update_order_status!(order)
    case @params[:status]
    when "open"
      order.update!(
        status: :triggered,
        opened_at: order.opened_at || Time.current
      )
    when "cancelled"
      order.update!(
        status: :cancelled,
        closed_at: order.closed_at || Time.current
      )
    end
  end

  def failure(errors)
    Result.new(success?: false, position: nil, errors: errors)
  end
end
