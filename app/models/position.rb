class Position < ApplicationRecord
  ACTIONS = Order::ACTIONS

  belongs_to :order
  has_one :trade_performance, dependent: :destroy
  has_many :execution_audit_logs, dependent: :destroy

  enum :status, {
    open: "open",
    closed: "closed",
    cancelled: "cancelled"
  }, default: :open, validate: true

  validates :ticket, presence: true, uniqueness: true
  validates :symbol, presence: true
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :entry_price, :stop_loss, :take_profit,
    presence: true,
    numericality: { greater_than: 0 }
  validates :opened_at, presence: true, if: :open?
  validate :closed_at_present, if: -> { closed? || cancelled? }

  scope :open_positions, -> { open }

  private

  def closed_at_present
    errors.add(:closed_at, "can't be blank") if closed_at.blank?
  end
end
