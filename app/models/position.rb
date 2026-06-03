class Position < ApplicationRecord
  ACTIONS = Order::ACTIONS
  STATUSES = %w[open closed].freeze

  belongs_to :order

  validates :symbol, presence: true
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :volume, :open_price, :stop_loss, :take_profit,
    presence: true,
    numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :mt4_ticket, presence: true, uniqueness: true
  validates :opened_at, presence: true
  validate :closed_fields_present, if: :closed?

  scope :open, -> { where(status: "open") }
  scope :closed, -> { where(status: "closed") }

  def closed?
    status == "closed"
  end

  private

  def closed_fields_present
    errors.add(:closed_at, "can't be blank") if closed_at.blank?
    errors.add(:close_price, "can't be blank") if close_price.blank?
  end
end
