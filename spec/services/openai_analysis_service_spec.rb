require "rails_helper"

RSpec.describe OpenaiAnalysisService do
  include ActiveSupport::Testing::TimeHelpers

  before { EconomicEvent.delete_all }

  def create_snapshot(ema50:, ema200:, rsi:, price: 4448.87, timeframe: "H4")
    MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: timeframe,
      price: price,
      rsi: rsi,
      ema50: ema50,
      ema200: ema200,
      support: 4430,
      resistance: 4490
    )
  end

  def service_for(snapshot, chat_client:, max_retries: 3, news_context_service: nil)
    described_class.new(
      market_snapshot: snapshot,
      chat_client: chat_client,
      max_retries: max_retries,
      news_context_service: news_context_service
    )
  end

  def empty_news_context
    NewsContextService.new(sync_calendar: false, events: EconomicEvent.none)
  end

  describe "#call" do
    it "returns WAIT without calling OpenAI when the API key is missing" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      original_key = ENV.delete("OPENAI_API_KEY")

      trade_signal = described_class.new(market_snapshot: snapshot).call

      ENV["OPENAI_API_KEY"] = original_key || "test-openai-key"

      expect(trade_signal.action).to eq("WAIT")
      expect(trade_signal.reason).to include("OpenAI API key not configured")
    end

    it "returns WAIT without calling OpenAI when market data is insufficient" do
      snapshot = MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4500,
        rsi: nil,
        ema50: nil,
        ema200: nil
      )
      chat_client = instance_double(Openai::ChatClient)
      expect(chat_client).not_to receive(:chat)

      trade_signal = service_for(snapshot, chat_client: chat_client).call

      expect(trade_signal.action).to eq("WAIT")
      expect(trade_signal.confidence).to eq(0)
      expect(trade_signal.reason).to include("Insufficient market data")
    end

    it "creates a TradeSignal from a mocked OpenAI BUY response" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      chat_client = openai_json_response(
        action: "BUY",
        confidence: 82,
        reason: "Momentum favors longs above support"
      )

      expect {
        service_for(snapshot, chat_client: chat_client).call
      }.to change(TradeSignal, :count).by(1)

      trade_signal = TradeSignal.last
      expect(trade_signal.market_snapshot).to eq(snapshot)
      expect(trade_signal.action).to eq("BUY")
      expect(trade_signal.confidence).to eq(82)
      expect(trade_signal.timeframe).to eq("H4")
      expect(trade_signal.reason).to eq("Momentum favors longs above support")
    end

    it "creates a TradeSignal from a mocked OpenAI SELL response" do
      snapshot = create_snapshot(ema50: 4470, ema200: 4490, rsi: 40)
      chat_client = openai_json_response(
        action: "SELL",
        confidence: 75,
        reason: "Bearish EMA stack with weak momentum"
      )

      trade_signal = service_for(snapshot, chat_client: chat_client).call

      expect(trade_signal.action).to eq("SELL")
      expect(trade_signal.confidence).to eq(75)
    end

    it "sends the market summary in the prompt" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60, price: 4500)
      chat_client = openai_json_response(action: "WAIT", confidence: 0, reason: "No setup")

      allow(chat_client).to receive(:chat).and_return(
        "choices" => [ { "message" => { "content" => { action: "WAIT", confidence: 0, timeframe: "H4", reason: "No setup" }.to_json } } ]
      )

      service_for(snapshot, chat_client: chat_client, news_context_service: empty_news_context).call

      expect(chat_client).to have_received(:chat) do |parameters:|
        prompt = parameters[:messages].last[:content]
        expect(prompt).to include("current_price: 4500")
        expect(prompt).to include("average_rsi:")
        expect(prompt).to include("ema50_trend:")
        expect(prompt).to include("timeframe: H4")
        expect(prompt).to include("News Context (ForexFactory calendar):")
        expect(prompt).to include(NewsContextService::CALENDAR_URL)
        expect(prompt).to include("trading_blackout: clear")
      end
    end

    it "includes ForexFactory news context from upcoming economic events" do
      now = Time.zone.parse("2026-06-03 12:00:00")
      travel_to(now) do
        event = EconomicEvent.create!(
          source: "forexfactory",
          currency: "USD",
          impact: "high",
          title: "FOMC Statement",
          scheduled_at: now + 3.hours,
          external_id: "fomc-test"
        )

        snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
        chat_client = openai_json_response(action: "WAIT", confidence: 0, reason: "News risk")
        news_context = NewsContextService.new(
          at: now,
          sync_calendar: false,
          events: EconomicEvent.where(id: event.id)
        )

        service_for(
          snapshot,
          chat_client: chat_client,
          news_context_service: news_context
        ).call

        expect(chat_client).to have_received(:chat) do |parameters:|
          prompt = parameters[:messages].last[:content]
          expect(prompt).to include("FOMC Statement")
          expect(prompt).to include("in 3h 0m")
        end
      end
    end

    it "logs the prompt and response" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      chat_client = openai_json_response(action: "BUY", confidence: 80, reason: "Trend aligned")

      allow(Rails.logger).to receive(:info)

      service_for(snapshot, chat_client: chat_client).call

      expect(Rails.logger).to have_received(:info).with(/\[OpenaiAnalysisService\] prompt=/)
      expect(Rails.logger).to have_received(:info).with(/\[OpenaiAnalysisService\] response=/)
    end

    it "retries on parse errors and eventually returns WAIT" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      chat_client = openai_chat_client(content: "not-json")
      allow(chat_client).to receive(:chat).and_return(
        "choices" => [ { "message" => { "content" => "not-json" } } ]
      )

      trade_signal = service_for(snapshot, chat_client: chat_client, max_retries: 2).call

      expect(trade_signal.action).to eq("WAIT")
      expect(trade_signal.reason).to include("OpenAI analysis failed")
      expect(chat_client).to have_received(:chat).twice
    end

    it "retries on API errors" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      chat_client = instance_double(Openai::ChatClient)
      attempts = 0

      allow(chat_client).to receive(:chat) do
        attempts += 1
        raise Faraday::ConnectionFailed, "timeout" if attempts < 2

        {
          "choices" => [
            { "message" => { "content" => { action: "BUY", confidence: 80, timeframe: "H4", reason: "Recovered" }.to_json } }
          ]
        }
      end

      trade_signal = service_for(snapshot, chat_client: chat_client, max_retries: 3).call

      expect(trade_signal.action).to eq("BUY")
      expect(chat_client).to have_received(:chat).twice
    end

    it "parses fenced JSON responses" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      fenced = <<~JSON
        ```json
        {"action":"WAIT","confidence":0,"timeframe":"H4","reason":"Range bound"}
        ```
      JSON
      chat_client = openai_chat_client(content: fenced)

      trade_signal = service_for(snapshot, chat_client: chat_client).call

      expect(trade_signal.action).to eq("WAIT")
      expect(trade_signal.reason).to eq("Range bound")
    end
  end

  describe "#market_summary" do
    it "loads the latest 10 XAUUSD snapshots through MarketSummaryService" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60, price: 4500)

      summary = service_for(snapshot, chat_client: openai_json_response(action: "WAIT", confidence: 0, reason: "x")).market_summary

      expect(summary[:symbol]).to eq("XAUUSD")
      expect(summary[:current_price]).to eq(4500)
      expect(summary[:snapshot_count]).to be_positive
      expect(summary[:timeframe]).to eq("H4")
      expect(summary[:ema50_trend]).to be_present
    end
  end
end
