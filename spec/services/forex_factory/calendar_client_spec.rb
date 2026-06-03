require "rails_helper"

RSpec.describe ForexFactory::CalendarClient do
  describe "#fetch" do
    it "parses the ForexFactory JSON calendar" do
      response = instance_double(Net::HTTPResponse, code: "200", body: [
        {
          "title" => "Non-Farm Payrolls",
          "country" => "USD",
          "date" => "2026-06-06T08:30:00-04:00",
          "impact" => "High"
        }
      ].to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      http = instance_double(Net::HTTP)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:get).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http)

      payload = described_class.new.fetch

      expect(payload.size).to eq(1)
      expect(payload.first["title"]).to eq("Non-Farm Payrolls")
    end

    it "raises when the calendar request fails" do
      response = instance_double(Net::HTTPResponse, code: "500", body: "")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      http = instance_double(Net::HTTP)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:get).and_return(response)
      allow(Net::HTTP).to receive(:start).and_yield(http)

      expect {
        described_class.new.fetch
      }.to raise_error(ForexFactory::CalendarClient::FetchError, /HTTP 500/)
    end
  end
end
