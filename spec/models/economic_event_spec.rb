require "rails_helper"

RSpec.describe EconomicEvent, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      event = described_class.new(
        source: "manual",
        currency: "USD",
        impact: "high",
        title: "Non-Farm Payrolls",
        scheduled_at: 1.hour.from_now
      )

      expect(event).to be_valid
    end

    it "rejects unsupported impact levels" do
      event = described_class.new(
        currency: "USD",
        impact: "red",
        scheduled_at: Time.current
      )

      expect(event).not_to be_valid
      expect(event.errors[:impact]).to be_present
    end
  end

  describe ".blocking_at" do
    it "returns events within the buffer window around the given time" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      in_window = described_class.create!(
        source: "manual",
        currency: "USD",
        impact: "high",
        scheduled_at: now + 20.minutes
      )
      described_class.create!(
        source: "manual",
        currency: "USD",
        impact: "high",
        scheduled_at: now + 2.hours
      )

      expect(described_class.blocking_at(now, buffer: 30.minutes)).to contain_exactly(in_window)
    end
  end
end
