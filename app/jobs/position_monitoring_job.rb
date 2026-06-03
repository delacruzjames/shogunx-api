class PositionMonitoringJob < ApplicationJob
  queue_as :default

  def perform
    Position.open_positions.find_each do |position|
      review(position)
    end
  end

  private

  def review(position)
    # Reserved for trailing stop, break-even, and partial take-profit logic.
    position
  end
end
