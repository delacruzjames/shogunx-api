class EndToEndSignalPipelineService
  HOLD_ACTION = "HOLD"

  def initialize(snapshot, summary_service: nil, analysis_service: nil)
    @snapshot = snapshot
    @summary_service = summary_service
    @analysis_service = analysis_service
  end

  def call
    market_summary
    trade_signal = create_trade_signal!
    return hold_response(trade_signal.reason) if trade_signal.action == "WAIT"

    plan_service = OrderPlanService.new(trade_signal)
    plan = plan_service.call
    return hold_response("no order plan available") if plan.nil?

    risk_result = RiskRuleService.new(trade_signal: trade_signal, order_plan: plan).call
    unless risk_result[:allowed]
      trade_signal.update!(rejection_reason: risk_result[:reason])
      return hold_response(risk_result[:reason])
    end

    orders = plan_service.create_orders_from_plan!(plan)
    return hold_response("no order plan available") if orders.blank?

    executable_response(orders.first)
  end

  def market_summary
    @market_summary ||= summary_service.call
  end

  private

  def summary_service
    @summary_service ||= MarketSummaryService.new(symbol: @snapshot.symbol)
  end

  def create_trade_signal!
    @trade_signal ||= analysis_service.call
  end

  def analysis_service
    @analysis_service ||= OpenaiAnalysisService.new(market_snapshot: @snapshot)
  end

  def hold_response(reason)
    {
      action: HOLD_ACTION,
      reason: reason
    }
  end

  def executable_response(order)
    {
      action: order.entry_type,
      order_id: order.id,
      symbol: order.trade_signal.symbol,
      entry_price: order.entry_price,
      stop_loss: order.stop_loss,
      take_profit: order.take_profit
    }
  end
end
