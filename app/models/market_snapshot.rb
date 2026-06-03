class MarketSnapshot < ApplicationRecord
  has_many :trade_signals, dependent: :destroy

  validates :symbol, presence: true
  validates :timeframe, presence: true
end
