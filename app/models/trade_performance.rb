class TradePerformance < ApplicationRecord
  ACTIONS = Order::ACTIONS

  belongs_to :position

  validates :symbol, :action, presence: true
  validates :action, inclusion: { in: ACTIONS }
  validates :entry_price, :exit_price, :profit_loss,
    presence: true,
    numericality: true
  validates :opened_at, :closed_at, presence: true
  validates :position_id, uniqueness: true

  scope :for_day, ->(day = Time.zone.today) {
    where(closed_at: day.in_time_zone.all_day)
  }

  scope :for_month, ->(month = Time.zone.today) {
    day = month.to_date
    where(closed_at: day.beginning_of_month.in_time_zone..day.end_of_month.in_time_zone.end_of_day)
  }

  scope :closed_between, ->(from, to) {
    where(closed_at: from.in_time_zone.beginning_of_day..to.in_time_zone.end_of_day)
  }

  scope :for_symbol, ->(symbol) {
    symbol.present? ? where(symbol: symbol) : all
  }
end
