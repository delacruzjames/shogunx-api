class MarketSnapshot < ApplicationRecord
  ANALYSIS_TIMEFRAMES = %w[D1 H4 H1].freeze
  PRIMARY_TIMEFRAME = "H4"

  has_many :trade_signals, dependent: :destroy

  validates :symbol, presence: true
  validates :timeframe, presence: true
end
