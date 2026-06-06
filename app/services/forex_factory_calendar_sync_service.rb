class ForexFactoryCalendarSyncService
  Result = Struct.new(:success?, :imported_count, :errors, keyword_init: true)

  SYNC_CACHE_KEY = "forexfactory_calendar_synced_at"
  MIN_SYNC_INTERVAL = 15.minutes

  def initialize(client: ForexFactory::CalendarClient.new, force: false)
    @client = client
    @force = force
  end

  def call
    return skipped_result unless @force || sync_due?

    entries = @client.fetch
    events = filter_entries(entries)
    imported = replace_week_events!(events)

    mark_synced!
    Result.new(success?: true, imported_count: imported, errors: [])
  rescue ForexFactory::CalendarClient::FetchError => e
    failure([ e.message ])
  rescue JSON::ParserError => e
    failure([ "ForexFactory calendar JSON was invalid: #{e.message}" ])
  end

  private

  def filter_entries(entries)
    entries.filter_map do |entry|
      next unless high_impact_usd?(entry)

      scheduled_at = parse_scheduled_at(entry["date"])
      next if scheduled_at.nil?

      {
        external_id: external_id_for(entry),
        currency: entry["country"].to_s.upcase,
        impact: "high",
        title: entry["title"].to_s.presence || "ForexFactory event",
        scheduled_at: scheduled_at
      }
    end
  end

  def high_impact_usd?(entry)
    entry["country"].to_s.upcase == "USD" && entry["impact"].to_s.casecmp("high").zero?
  end

  def external_id_for(entry)
    scheduled_at = parse_scheduled_at(entry["date"])
    title = entry["title"].to_s
    Digest::SHA256.hexdigest([ entry["country"], scheduled_at.utc.iso8601, title ].join("|"))
  end

  def parse_scheduled_at(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def replace_week_events!(events)
    return 0 if events.empty?

    scheduled_times = events.map { |event| event[:scheduled_at] }.compact
    week_range = scheduled_times.min.beginning_of_day..scheduled_times.max.end_of_day

    imported = 0

    ActiveRecord::Base.transaction do
      EconomicEvent.where(source: "forexfactory", currency: "USD", impact: "high")
        .where(scheduled_at: week_range)
        .delete_all

      events.each do |attributes|
        next if attributes[:scheduled_at].nil?

        EconomicEvent.create!(
          attributes.merge(source: "forexfactory")
        )
        imported += 1
      end
    end

    imported
  end

  def sync_due?
    last_sync = Rails.cache.read(SYNC_CACHE_KEY)
    last_sync.nil? || last_sync < MIN_SYNC_INTERVAL.ago
  end

  def mark_synced!
    Rails.cache.write(SYNC_CACHE_KEY, Time.current, expires_in: MIN_SYNC_INTERVAL)
  end

  def skipped_result
    Result.new(success?: true, imported_count: 0, errors: [])
  end

  def failure(errors)
    Result.new(success?: false, imported_count: 0, errors: errors)
  end
end
