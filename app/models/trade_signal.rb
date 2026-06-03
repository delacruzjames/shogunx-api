class TradeSignal < ApplicationRecord
  ACTIONS = %w[BUY SELL WAIT].freeze

  belongs_to :market_snapshot
  has_many :orders, dependent: :destroy

  validates :symbol, presence: true
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :confidence,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
