class EconomicEvent < ApplicationRecord
  IMPACTS = %w[high medium low].freeze
  CURRENCIES = %w[USD].freeze
  SOURCES = %w[manual forexfactory].freeze

  validates :currency, presence: true, inclusion: { in: CURRENCIES }
  validates :impact, presence: true, inclusion: { in: IMPACTS }
  validates :scheduled_at, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :external_id, uniqueness: true, allow_nil: true

  scope :high_impact, -> { where(impact: "high") }
  scope :usd, -> { where(currency: "USD") }
  scope :from_forexfactory, -> { where(source: "forexfactory") }

  scope :blocking_at, ->(time, buffer: 30.minutes) {
    where(scheduled_at: (time - buffer)..(time + buffer))
  }
end
