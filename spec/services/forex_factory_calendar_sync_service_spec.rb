require "rails_helper"

RSpec.describe ForexFactoryCalendarSyncService do
  let(:calendar_payload) do
    [
      {
        "title" => "Non-Farm Payrolls",
        "country" => "USD",
        "date" => "2026-06-06T08:30:00-04:00",
        "impact" => "High",
        "forecast" => "180K",
        "previous" => "175K"
      },
      {
        "title" => "CPI y/y",
        "country" => "EUR",
        "date" => "2026-06-06T05:00:00-04:00",
        "impact" => "High",
        "forecast" => "2.1%",
        "previous" => "2.0%"
      },
      {
        "title" => "FOMC Member Speaks",
        "country" => "USD",
        "date" => "2026-06-07T10:00:00-04:00",
        "impact" => "Low",
        "forecast" => "",
        "previous" => ""
      }
    ]
  end

  let(:client) { instance_double(ForexFactory::CalendarClient, fetch: calendar_payload) }

  describe "#call" do
    it "imports high-impact USD events from ForexFactory" do
      result = described_class.new(client: client, force: true).call

      expect(result).to be_success
      expect(result.imported_count).to eq(1)
      expect(EconomicEvent.from_forexfactory.high_impact.usd.count).to eq(1)
      expect(EconomicEvent.last.title).to eq("Non-Farm Payrolls")
      expect(EconomicEvent.last.external_id).to be_present
    end

    it "replaces stale ForexFactory events for the synced week" do
      old_event = EconomicEvent.create!(
        source: "forexfactory",
        external_id: "stale-event",
        currency: "USD",
        impact: "high",
        title: "Old Event",
        scheduled_at: Time.zone.parse("2026-06-06T08:30:00-04:00")
      )

      described_class.new(client: client, force: true).call

      expect(EconomicEvent.exists?(old_event.id)).to be(false)
      expect(EconomicEvent.from_forexfactory.high_impact.usd.pluck(:title)).to eq([ "Non-Farm Payrolls" ])
    end

    it "returns errors when the calendar cannot be fetched" do
      allow(client).to receive(:fetch).and_raise(ForexFactory::CalendarClient::FetchError, "offline")

      result = described_class.new(client: client, force: true).call

      expect(result).not_to be_success
      expect(result.errors).to include("offline")
    end
  end
end
