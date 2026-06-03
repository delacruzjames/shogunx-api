class Order < ApplicationRecord
  ACTIONS = %w[BUY SELL].freeze
  ENTRY_TYPES = %w[BUY_LIMIT SELL_LIMIT].freeze

  belongs_to :trade_signal
  has_one :position, dependent: :destroy

  enum :status, {
    pending: "pending",
    placed: "placed",
    triggered: "triggered",
    closed: "closed",
    cancelled: "cancelled",
    expired: "expired"
  }, default: :pending, validate: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
  validates :entry_price, :stop_loss, :take_profit, :risk_reward,
    presence: true,
    numericality: { greater_than: 0 }
  validate :entry_type_matches_action

  private

  def entry_type_matches_action
    return if action.blank? || entry_type.blank?

    expected = "#{action}_LIMIT"
    return if entry_type == expected

    errors.add(:entry_type, "must be #{expected} for action #{action}")
  end
end
