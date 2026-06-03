class OrderCreationService
  def initialize(trade_signal, plan_service: nil)
    @trade_signal = trade_signal
    @plan_service = plan_service
  end

  def call
    plan_service.create_order!
  end

  private

  def plan_service
    @plan_service ||= OrderPlanService.new(@trade_signal)
  end
end
