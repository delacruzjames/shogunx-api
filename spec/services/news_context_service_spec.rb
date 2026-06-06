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

      result = described_class.new(at: now).call

      expect(result[:in_blackout]).to be(false)
      expect(result[:blackout_reason]).to be_nil
      expect(result[:upcoming_events].size).to eq(1)
      expect(result[:calendar_url]).to eq(NewsContextService::CALENDAR_URL)
    end

    it "reports active blackout during the 60-minute news window" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_event(scheduled_at: now + 20.minutes)

      result = described_class.new(at: now).call

      expect(result[:in_blackout]).to be(true)
      expect(result[:blackout_reason]).to include("Non-Farm Payrolls")
    end

    it "reads cached economic_events without calling ForexFactory" do
      allow(ForexFactoryCalendarSyncService).to receive(:new)

      described_class.new.call

      expect(ForexFactoryCalendarSyncService).not_to have_received(:new)
    end
  end

  describe "#format_for_prompt" do
    it "includes the ForexFactory calendar URL and upcoming releases" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_event(scheduled_at: now + 2.hours, title: "CPI m/m")

      text = described_class.new(at: now).format_for_prompt

      expect(text).to include(NewsContextService::CALENDAR_URL)
      expect(text).to include("trading_blackout: clear")
      expect(text).to include("CPI m/m")
      expect(text).to include("news_guidance:")
    end
  end
end
