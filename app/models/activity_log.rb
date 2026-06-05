class ActivityLog < ApplicationRecord
  CATEGORIES = %w[snapshot analysis risk orders execution system].freeze
  LEVELS = %w[info warn success error].freeze
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 100

  belongs_to :market_snapshot, optional: true
  belongs_to :trade_signal, optional: true
  belongs_to :order, optional: true

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :level, presence: true, inclusion: { in: LEVELS }
  validates :message, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :after_id, ->(id) { where("id > ?", id).order(id: :asc) }
end
