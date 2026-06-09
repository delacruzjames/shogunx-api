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
    log_analysis(trade_signal)

    if trade_signal.action == "WAIT"
      reason = trade_signal.reason
      log_analysis_hold("Analysis WAIT", reason, trade_signal: trade_signal)
      return hold_response(reason)
    end

    plan_service = OrderPlanService.new(trade_signal)
    plan = plan_service.call
    if plan.nil?
      log_pipeline_hold("No order plan", "support/resistance or price levels invalid", trade_signal: trade_signal, level: "warn")
      return hold_response("no order plan available")
    end

    cancel_unsynced_pending_orders!
    risk_result = RiskRuleService.new(trade_signal: trade_signal, order_plan: plan).call
    unless risk_result[:allowed]
      trade_signal.update!(rejection_reason: risk_result[:reason])
      log_risk_hold("Risk blocked", risk_result[:reason], trade_signal: trade_signal)
      return hold_response(risk_result[:reason])
    end

    orders = plan_service.create_orders_from_plan!(plan)
    if orders.blank?
      log_pipeline_hold("No orders created", "TP legs could not be built", trade_signal: trade_signal, level: "warn")
      return hold_response("no order plan available")
    end

    log_orders_created(orders, plan, trade_signal)
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

  def cancel_unsynced_pending_orders!
    stale = Order.pending
      .joins(:trade_signal)
      .where(trade_signals: { symbol: @snapshot.symbol }, ticket: nil)

    return if stale.none?

    count = stale.update_all(status: Order.statuses[:cancelled], updated_at: Time.current)
    ActivityLogService.record(
      category: "orders",
      level: "info",
      message: "Cancelled #{count} unsynced pending order(s) awaiting MT4 placement",
      metadata: { symbol: @snapshot.symbol, cancelled_count: count },
      market_snapshot: @snapshot
    )
  end

  def hold_response(reason)
    response = {
      action: HOLD_ACTION,
      reason: reason
    }
    log_execution_poll_hint(response)
    response
  end

  def executable_response(order)
    response = {
      action: order.entry_type,
      order_id: order.id,
      symbol: order.trade_signal.symbol,
      entry_price: order.entry_price,
      stop_loss: order.stop_loss,
      take_profit: order.take_profit
    }
    ActivityLogService.record(
      category: "orders",
      level: "success",
      message: "Approved #{order.entry_type} order ##{order.id} (TP leg #{order.tp_leg})",
      metadata: response.merge(tp_leg: order.tp_leg, pending_count: Order.pending.count),
      trade_signal: order.trade_signal,
      order: order,
      market_snapshot: @snapshot
    )
    response
  end

  def log_analysis(trade_signal)
    ActivityLogService.record(
      category: "analysis",
      level: trade_signal.action == "WAIT" ? "warn" : "success",
      message: "OpenAI #{trade_signal.action} @ #{trade_signal.confidence}% — #{trade_signal.reason}",
      metadata: {
        action: trade_signal.action,
        confidence: trade_signal.confidence,
        timeframe: trade_signal.timeframe,
        trade_signal_id: trade_signal.id
      },
      trade_signal: trade_signal,
      market_snapshot: @snapshot
    )
  end

  def log_analysis_hold(title, reason, trade_signal:)
    ActivityLogService.record(
      category: "analysis",
      level: "warn",
      message: "#{title}: #{reason}",
      metadata: {
        hold_reason: reason,
        trade_signal_id: trade_signal.id,
        signal_action: trade_signal.action,
        confidence: trade_signal.confidence
      },
      trade_signal: trade_signal,
      market_snapshot: @snapshot
    )
  end

  def log_risk_hold(title, reason, trade_signal:)
    ActivityLogService.record(
      category: "risk",
      level: "warn",
      message: "#{title}: #{reason}",
      metadata: {
        hold_reason: reason,
        trade_signal_id: trade_signal.id,
        signal_action: trade_signal.action,
        confidence: trade_signal.confidence
      },
      trade_signal: trade_signal,
      market_snapshot: @snapshot
    )
  end

  def log_pipeline_hold(title, reason, trade_signal:, level: "info")
    ActivityLogService.record(
      category: "orders",
      level: level,
      message: "#{title}: #{reason}",
      metadata: {
        hold_reason: reason,
        trade_signal_id: trade_signal.id,
        signal_action: trade_signal.action,
        confidence: trade_signal.confidence
      },
      trade_signal: trade_signal,
      market_snapshot: @snapshot
    )
  end

  def log_orders_created(orders, plan, trade_signal)
    ActivityLogService.record(
      category: "orders",
      level: "success",
      message: "Created #{orders.size} pending orders (#{plan[:entry_type]})",
      metadata: {
        order_ids: orders.map(&:id),
        entry_type: plan[:entry_type],
        entry_price: plan[:entry_price],
        stop_loss: plan[:stop_loss],
        take_profits: orders.map { |o| { leg: o.tp_leg, tp: o.take_profit } }
      },
      trade_signal: trade_signal,
      market_snapshot: @snapshot
    )
  end

  def log_execution_poll_hint(response)
    pending = Order.pending.count
    message = if response[:action] == HOLD_ACTION
      "Pipeline HOLD — #{response[:reason]} (#{pending} pending orders for MT4)"
    else
      "Pipeline returned #{response[:action]} for MT4"
    end

    ActivityLogService.record(
      category: "execution",
      level: response[:action] == HOLD_ACTION ? "info" : "success",
      message: message,
      metadata: response.merge(pending_orders: pending),
      market_snapshot: @snapshot
    )
  end
end
