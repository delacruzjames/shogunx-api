class DailyPerformance < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :profit_loss, presence: true, numericality: true

  scope :for_date, ->(day) { where(date: day) }

  def self.for_today
    find_by(date: Time.zone.today)
  end
end
