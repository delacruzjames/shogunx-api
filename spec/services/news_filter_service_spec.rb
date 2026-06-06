require "rails_helper"

RSpec.describe NewsFilterService do
  def create_high_impact_event(scheduled_at:, currency: "USD", impact: "high")
    EconomicEvent.create!(
      source: "manual",
      currency: currency,
      impact: impact,
      title: "Test Event",
      scheduled_at: scheduled_at
    )
  end

  describe "#call" do
    it "allows trading when there is no high-impact USD news" do
      result = described_class.new.call

      expect(result).to eq(allowed: true, reason: "clear of high impact news")
    end

    it "blocks trading 60 minutes before high-impact news" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_high_impact_event(scheduled_at: now + 60.minutes)

      result = described_class.new(at: now).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("high impact USD news: Test Event")
    end

    it "blocks trading 60 minutes after high-impact news" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_high_impact_event(scheduled_at: now - 60.minutes)

      result = described_class.new(at: now).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("high impact USD news: Test Event")
    end

    it "blocks trading during the news release" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_high_impact_event(scheduled_at: now)

      result = described_class.new(at: now).call

      expect(result[:allowed]).to be(false)
      expect(result[:reason]).to eq("high impact USD news: Test Event")
    end

    it "allows trading just outside the 60-minute buffer" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_high_impact_event(scheduled_at: now + 61.minutes)

      result = described_class.new(at: now).call

      expect(result[:allowed]).to be(true)
    end

    it "ignores medium-impact events" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      create_high_impact_event(scheduled_at: now, impact: "medium")

      result = described_class.new(at: now).call

      expect(result[:allowed]).to be(true)
    end

    it "ignores non-USD high-impact events" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      event = create_high_impact_event(scheduled_at: now)
      event.update_column(:currency, "EUR")

      result = described_class.new(at: now).call

      expect(result[:allowed]).to be(true)
    end

    it "reads cached economic_events without calling ForexFactory" do
      allow(ForexFactoryCalendarSyncService).to receive(:new)

      described_class.new.call

      expect(ForexFactoryCalendarSyncService).not_to have_received(:new)
    end
  end
end
