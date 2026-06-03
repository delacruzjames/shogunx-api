require "rails_helper"

RSpec.describe "Api::V1::Signals", type: :request do
  describe "POST /api/v1/signals" do
    let(:payload) do
      {
        symbol: "EURUSD",
        timeframe: "H1",
        price: 1.085,
        rsi: 55.25,
        ema50: 1.084,
        ema200: 1.082,
        support: 1.080,
        resistance: 1.090
      }
    end

    it "creates a market snapshot and returns WAIT" do
      expect {
        post api_v1_signals_path, params: payload, as: :json
      }.to change(MarketSnapshot, :count).by(1)

      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body["status"]).to eq("received")
      expect(body["action"]).to eq("WAIT")
      expect(body["snapshot_id"]).to eq(MarketSnapshot.last.id)

      snapshot = MarketSnapshot.last
      expect(snapshot.symbol).to eq("EURUSD")
      expect(snapshot.timeframe).to eq("H1")
      expect(snapshot.price).to eq(1.085)
      expect(snapshot.rsi).to eq(55.25)
      expect(snapshot.ema50).to eq(1.084)
      expect(snapshot.ema200).to eq(1.082)
      expect(snapshot.support).to eq(1.080)
      expect(snapshot.resistance).to eq(1.090)
    end

    it "accepts flat JSON like the MT4 EA (no :signal wrapper)" do
      post api_v1_signals_path,
        params: payload.to_json,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "ACCEPT" => "application/json"
        }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["action"]).to eq("WAIT")
      expect(response.parsed_body).not_to have_key("signal")
    end

    it "returns errors when required fields are missing" do
      post api_v1_signals_path, params: { symbol: "EURUSD" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)

      body = response.parsed_body
      expect(body["status"]).to eq("error")
      expect(body["errors"]).to include("Timeframe can't be blank")
    end
  end
end
