require "rails_helper"

RSpec.describe OpenaiAnalysisService do
  include ActiveSupport::Testing::TimeHelpers

  before { EconomicEvent.delete_all }

  def create_snapshot(ema50:, ema200:, rsi:, price: 4448.87, **attrs)
    create_multi_timeframe_snapshots(
      price: price,
      rsi: rsi,
      ema50: ema50,
      ema200: ema200,
      **attrs
    ).find { |snapshot| snapshot.timeframe == "H4" }
  end

  def service_for(snapshot, chat_client:, max_retries: 3, news_context_service: nil, trading_mode: TradingMode.new("conservative"))
    described_class.new(
      market_snapshot: snapshot,
      chat_client: chat_client,
      max_retries: max_retries,
      news_context_service: news_context_service,
      trading_mode: trading_mode
    )
  end

  def create_mixed_trend_snapshot(h4_h1_direction:, d1_direction:, **attrs)
    snapshots = create_multi_timeframe_snapshots(**attrs)
    apply_trend!(snapshots, "D1", d1_direction)
    apply_trend!(snapshots, "H4", h4_h1_direction)
    apply_trend!(snapshots, "H1", h4_h1_direction)
    snapshots.find { |snapshot| snapshot.timeframe == "H4" }
  end

  def apply_trend!(snapshots, timeframe, direction)
    snapshot = snapshots.find { |record| record.timeframe == timeframe }
    ema_values = case direction
    when :bullish then { ema50: 4510.0, ema200: 4490.0 }
    when :bearish then { ema50: 4470.0, ema200: 4490.0 }
    else raise ArgumentError, "Unknown direction: #{direction}"
    end
    snapshot.update!(ema_values)
  end

  def empty_news_context
    NewsContextService.new(events: EconomicEvent.none)
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
      snapshot = create_multi_timeframe_snapshots(
        price: 4500,
        rsi: nil,
        ema50: nil,
        ema200: nil
      ).find { |s| s.timeframe == "H4" }
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
        expect(prompt).to include("H4 timeframe:")
        expect(prompt).to include("price: 4500")
        expect(prompt).to include("D1 timeframe:")
        expect(prompt).to include("H1 timeframe:")
        expect(prompt).to include("News Context:")
        expect(prompt).to include("Trading mode: conservative")
        expect(prompt).to include("Require D1, H4, and H1 trend alignment for BUY or SELL")
        expect(prompt).to include("If confidence is below 70, return WAIT")
        expect(prompt).to include(NewsContextService::CALENDAR_URL)
        expect(prompt).to include("trading_blackout: clear")
        expect(prompt).to include("blackout_window_minutes: 60")
      end
    end

    it "normalizes BUY below the confidence threshold to WAIT" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      chat_client = openai_json_response(
        action: "BUY",
        confidence: 65,
        reason: "Weak setup"
      )

      trade_signal = service_for(snapshot, chat_client: chat_client).call

      expect(trade_signal.action).to eq("WAIT")
      expect(trade_signal.confidence).to eq(0)
      expect(trade_signal.reason).to include("below 70 threshold")
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

    it "includes tactical prompt rules when configured" do
      snapshot = create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)
      chat_client = openai_json_response(action: "WAIT", confidence: 0, reason: "No setup")

      service_for(
        snapshot,
        chat_client: chat_client,
        news_context_service: empty_news_context,
        trading_mode: TradingMode.new("tactical")
      ).call

      expect(chat_client).to have_received(:chat) do |parameters:|
        prompt = parameters[:messages].last[:content]
        expect(prompt).to include("Trading mode: tactical")
        expect(prompt).to include("Allow BUY or SELL when H4 and H1 trends are aligned")
      end
    end

    it "returns WAIT in conservative mode when timeframes are mixed" do
      snapshot = create_mixed_trend_snapshot(
        h4_h1_direction: :bearish,
        d1_direction: :bullish,
        rsi: 40
      )
      chat_client = openai_json_response(
        action: "SELL",
        confidence: 85,
        reason: "Lower timeframe breakdown"
      )

      trade_signal = service_for(snapshot, chat_client: chat_client).call

      expect(trade_signal.action).to eq("WAIT")
      expect(trade_signal.reason).to eq("Mixed signals across timeframes")
    end

    it "allows tactical SELL when H4 and H1 align against a bullish D1" do
      snapshot = create_mixed_trend_snapshot(
        h4_h1_direction: :bearish,
        d1_direction: :bullish,
        rsi: 40
      )
      chat_client = openai_json_response(
        action: "SELL",
        confidence: 80,
        reason: "Lower timeframe breakdown"
      )

      trade_signal = service_for(
        snapshot,
        chat_client: chat_client,
        trading_mode: TradingMode.new("tactical")
      ).call

      expect(trade_signal.action).to eq("SELL")
      expect(trade_signal.confidence).to eq(70)
      expect(trade_signal.reason).to include("Lower timeframe breakdown")
      expect(trade_signal.reason).to include(TradingMode::TACTICAL_REASON)
    end

    it "returns WAIT in tactical mode when the D1 penalty drops confidence below 70" do
      snapshot = create_mixed_trend_snapshot(
        h4_h1_direction: :bearish,
        d1_direction: :bullish,
        rsi: 40
      )
      chat_client = openai_json_response(
        action: "SELL",
        confidence: 75,
        reason: "Moderate setup"
      )

      trade_signal = service_for(
        snapshot,
        chat_client: chat_client,
        trading_mode: TradingMode.new("tactical")
      ).call

      expect(trade_signal.action).to eq("WAIT")
      expect(trade_signal.reason).to include("below 70 threshold")
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
