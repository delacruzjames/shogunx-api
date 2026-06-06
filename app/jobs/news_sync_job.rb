class NewsSyncJob < ApplicationJob
  queue_as :default

  def perform
    result = ForexFactoryCalendarSyncService.new(force: true).call

    unless result.success?
      Rails.logger.warn("[NewsSyncJob] ForexFactory sync failed: #{result.errors.join(', ')}")
    end
  end
end
