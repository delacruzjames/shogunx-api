class NewsContextService
  CALENDAR_URL = ForexFactory::CalendarClient::DEFAULT_URL
  LOOKAHEAD = 7.days
  MAX_EVENTS = 8
  BUFFER = NewsFilterService::BUFFER

  def initialize(at: Time.current, sync_calendar: default_sync_calendar?, events: nil)
    @at = at
    @sync_calendar = sync_calendar
    @events = events
  end

  def call
    refresh_calendar if @sync_calendar

    {
      calendar_url: CALENDAR_URL,
      in_blackout: in_blackout?,
      blackout_reason: blackout_reason,
      upcoming_events: upcoming_events
    }
  end

  def format_for_prompt
    context = call
    lines = [
      "USD high-impact news (ForexFactory: #{context[:calendar_url]}):",
      "trading_blackout: #{context[:in_blackout] ? "active" : "clear"}"
    ]

    if context[:in_blackout] && context[:blackout_reason].present?
      lines << "blackout_reason: #{context[:blackout_reason]}"
    end

    lines << "blackout_window_minutes: #{BUFFER.in_minutes.to_i} before and after each release"
    lines << "upcoming_usd_high_impact_releases:"

    if context[:upcoming_events].empty?
      lines << "- none scheduled in the next #{LOOKAHEAD.in_days.to_i} days"
    else
      context[:upcoming_events].each do |event|
        lines << format_event_line(event)
      end
    end

    lines << "news_guidance: Prefer WAIT when trading_blackout is active or within the blackout window of a listed release."
    lines.join("\n")
  end

  private

  def refresh_calendar
    ForexFactoryCalendarSyncService.new.call
  rescue ForexFactory::CalendarClient::FetchError => e
    Rails.logger.warn("[NewsContextService] ForexFactory sync failed: #{e.message}")
  end

  def in_blackout?
    blocking_events.exists?
  end

  def blackout_reason
    return nil unless in_blackout?

    event = blocking_events.order(:scheduled_at).first
    return NewsFilterService::BLOCK_REASON if event.nil? || event.title.blank?

    "#{NewsFilterService::BLOCK_REASON}: #{event.title}"
  end

  def event_scope
    @events || EconomicEvent.high_impact.usd
  end

  def blocking_events
    @blocking_events ||= event_scope.blocking_at(@at, buffer: BUFFER)
  end

  def upcoming_events
    event_scope
      .where(scheduled_at: @at..(@at + LOOKAHEAD))
      .order(:scheduled_at)
      .limit(MAX_EVENTS)
      .map do |event|
        {
          title: event.title,
          scheduled_at: event.scheduled_at,
          minutes_until: minutes_until(event.scheduled_at),
          within_blackout_window: within_blackout_window?(event.scheduled_at)
        }
      end
  end

  def format_event_line(event)
    time_label = event[:scheduled_at].in_time_zone.strftime("%Y-%m-%d %H:%M %Z")
    timing = relative_timing_label(event[:minutes_until])
    window_flag = event[:within_blackout_window] ? " [inside blackout window]" : ""

    "- #{time_label} (#{timing}): #{event[:title]}#{window_flag}"
  end

  def relative_timing_label(minutes_until)
    return "now" if minutes_until.zero?

    if minutes_until.positive?
      hours = minutes_until / 60
      mins = minutes_until % 60
      return "in #{hours}h #{mins}m" if hours.positive?

      return "in #{mins}m"
    end

    "started #{minutes_until.abs}m ago"
  end

  def minutes_until(scheduled_at)
    ((scheduled_at - @at) / 60).round
  end

  def within_blackout_window?(scheduled_at)
    scheduled_at.between?(@at - BUFFER, @at + BUFFER)
  end

  def default_sync_calendar?
    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("FOREXFACTORY_SYNC_ON_OPENAI", ENV.fetch("FOREXFACTORY_SYNC_ON_FILTER", !Rails.env.test?))
    )
  end
end
