class MarketSnapshot < ApplicationRecord
  validates :symbol, presence: true
  validates :timeframe, presence: true
end
