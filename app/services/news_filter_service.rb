class NewsFilterService
  BUFFER = 60.minutes
  BLOCK_REASON = "high impact USD news"

  def initialize(at: Time.current, events: nil)
    @at = at
    @events = events
  end

  def call
    return allowed_result unless blocking_news?

    { allowed: false, reason: block_reason }
  end

  private

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
end
