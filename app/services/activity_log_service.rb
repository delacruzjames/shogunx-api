class ActivityLogService
  def self.record(category:, message:, level: "info", metadata: {}, market_snapshot: nil, trade_signal: nil, order: nil)
    ActivityLog.create!(
      category: category,
      level: level,
      message: message,
      metadata: metadata,
      market_snapshot: market_snapshot,
      trade_signal: trade_signal,
      order: order
    )
  rescue ActiveRecord::RecordInvalid => error
    Rails.logger.warn("[ActivityLogService] failed to record: #{error.message}")
    nil
  end
end
