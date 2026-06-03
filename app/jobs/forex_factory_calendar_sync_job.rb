class ForexFactoryCalendarSyncJob < ApplicationJob
  queue_as :default

  def perform(force: false)
    ForexFactoryCalendarSyncService.new(force: force).call
  end
end
