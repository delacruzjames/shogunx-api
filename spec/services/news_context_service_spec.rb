require "rails_helper"

RSpec.describe NewsContextService do
  before { EconomicEvent.delete_all }

  def create_event(scheduled_at:, title: "Non-Farm Payrolls")
    EconomicEvent.create!(
      source: "forexfactory",
      currency: "USD",
      impact: "high",
      title: title,
      scheduled_at: scheduled_at,
      external_id: SecureRandom.hex(8)
    )
  end

  describe "#call" do
    it "reports clear blackout when no events are near" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_event(scheduled_at: now + 2.days)

      result = described_class.new(at: now, sync_calendar: false).call

      expect(result[:in_blackout]).to be(false)
      expect(result[:blackout_reason]).to be_nil
      expect(result[:upcoming_events].size).to eq(1)
      expect(result[:calendar_url]).to eq(NewsContextService::CALENDAR_URL)
    end

    it "reports active blackout during the 30-minute news window" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_event(scheduled_at: now + 20.minutes)

      result = described_class.new(at: now, sync_calendar: false).call

      expect(result[:in_blackout]).to be(true)
      expect(result[:blackout_reason]).to include("Non-Farm Payrolls")
    end

    it "syncs ForexFactory before building context when enabled" do
      sync = instance_double(
        ForexFactoryCalendarSyncService,
        call: ForexFactoryCalendarSyncService::Result.new(success?: true, imported_count: 0, errors: [])
      )
      allow(ForexFactoryCalendarSyncService).to receive(:new).and_return(sync)

      described_class.new(sync_calendar: true).call

      expect(ForexFactoryCalendarSyncService).to have_received(:new)
      expect(sync).to have_received(:call)
    end
  end

  describe "#format_for_prompt" do
    it "includes the ForexFactory calendar URL and upcoming releases" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_event(scheduled_at: now + 2.hours, title: "CPI m/m")

      text = described_class.new(at: now, sync_calendar: false).format_for_prompt

      expect(text).to include(NewsContextService::CALENDAR_URL)
      expect(text).to include("trading_blackout: clear")
      expect(text).to include("CPI m/m")
      expect(text).to include("news_guidance:")
    end
  end
end
