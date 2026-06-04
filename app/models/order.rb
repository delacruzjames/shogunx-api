class Order < ApplicationRecord
  ACTIONS = %w[BUY SELL].freeze
  ENTRY_TYPES = %w[BUY_LIMIT SELL_LIMIT BUY_STOP SELL_STOP].freeze

  ENTRY_TYPES_BY_ACTION = {
    "BUY" => %w[BUY_LIMIT BUY_STOP],
    "SELL" => %w[SELL_LIMIT SELL_STOP]
  }.freeze

  belongs_to :trade_signal
  has_one :position, dependent: :destroy
  has_many :execution_audit_logs, dependent: :destroy

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

    allowed = ENTRY_TYPES_BY_ACTION[action]
    return if allowed&.include?(entry_type)

    errors.add(:entry_type, "must be #{allowed.join(' or ')} for action #{action}")
  end
end
