class ExecutionAuditLog < ApplicationRecord
  SOURCES = %w[order_updates position_updates].freeze

  belongs_to :order, optional: true
  belongs_to :position, optional: true

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :event_status, presence: true
  validates :payload, presence: true
  validate :requires_order_or_position

  scope :for_order, ->(order) { where(order: order).order(created_at: :desc) }
  scope :for_position, ->(position) { where(position: position).order(created_at: :desc) }

  private

  def requires_order_or_position
    return if order_id.present? || position_id.present?

    errors.add(:base, "must belong to an order or position")
  end
end
