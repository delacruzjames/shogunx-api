class NewsFilterService
  BUFFER = 60.minutes
  BLOCK_REASON = "high impact USD news"

  def initialize(at: Time.current, events: nil, sync_calendar: default_sync_calendar?)
    @at = at
    @events = events
    @sync_calendar = sync_calendar
  end

  def call
    refresh_calendar if @sync_calendar
    return allowed_result unless blocking_news?

    { allowed: false, reason: block_reason }
  end

  private

  def refresh_calendar
    ForexFactoryCalendarSyncService.new.call
  rescue ForexFactory::CalendarClient::FetchError => e
    Rails.logger.warn("[NewsFilterService] ForexFactory sync failed: #{e.message}")
  end

  def blocking_news?
    blocking_events.exists?
  end

  def blocking_events
    @blocking_events ||= begin
      scope = @events || EconomicEvent.high_impact.usd
      scope.blocking_at(@at, buffer: BUFFER)
    end
  end

  def block_reason
    event = blocking_events.order(:scheduled_at).first
    return BLOCK_REASON if event.nil? || event.title.blank?

    "#{BLOCK_REASON}: #{event.title}"
  end

  def allowed_result
    { allowed: true, reason: "clear of high impact news" }
  end

  def default_sync_calendar?
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("FOREXFACTORY_SYNC_ON_FILTER", !Rails.env.test?)
    )
  end
end
