class OrderExpiryJob < ApplicationJob
  queue_as :default

  def perform
    expired_orders.find_each do |order|
      order.update!(status: "expired")
    end
  end

  private

  def expired_orders
    Order
      .where(status: "pending")
      .where.not(expires_at: nil)
      .where(expires_at: ...Time.current)
  end
end
