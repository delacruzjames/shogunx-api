require "rails_helper"

RSpec.describe TradingMode do
  def summary_with_trends(d1:, h4:, h1:)
    {
      symbol: "XAUUSD",
      timeframes: {
        "D1" => { trend: d1 },
        "H4" => { trend: h4 },
        "H1" => { trend: h1 }
      }
    }
  end

  def tradable_analysis(action:, confidence:, reason: "Setup looks good")
    {
      action: action,
      confidence: confidence,
      timeframe: "H4",
      reason: reason
    }
  end

  describe ".current" do
    after { described_class.reset! }

    it "defaults to conservative" do
      original = ENV.delete("SHOGUNX_TRADING_MODE")
      described_class.reset!

      expect(described_class.current).to be_conservative
    ensure
      ENV["SHOGUNX_TRADING_MODE"] = original if original
      described_class.reset!
    end

    it "loads tactical from the environment" do
      original = ENV["SHOGUNX_TRADING_MODE"]
      ENV["SHOGUNX_TRADING_MODE"] = "tactical"
      described_class.reset!

      expect(described_class.current).to be_tactical
    ensure
      if original.nil?
        ENV.delete("SHOGUNX_TRADING_MODE")
      else
        ENV["SHOGUNX_TRADING_MODE"] = original
      end
      described_class.reset!
    end
  end

  describe "#apply_tradable_analysis" do
    let(:min_confidence) { 70 }

    context "in conservative mode" do
      let(:mode) { described_class.new("conservative") }

      it "allows BUY when D1, H4, and H1 are bullish" do
        summary = summary_with_trends(d1: "bullish", h4: "bullish", h1: "bullish")
        analysis = tradable_analysis(action: "BUY", confidence: 80)

        result = mode.apply_tradable_analysis(analysis, summary, min_confidence: min_confidence)

        expect(result[:action]).to eq("BUY")
        expect(result[:confidence]).to eq(80)
      end

      it "returns WAIT when timeframes are mixed" do
        summary = summary_with_trends(d1: "bullish", h4: "bearish", h1: "bearish")
        analysis = tradable_analysis(action: "SELL", confidence: 85)

        result = mode.apply_tradable_analysis(analysis, summary, min_confidence: min_confidence)

        expect(result[:action]).to eq("WAIT")
        expect(result[:reason]).to eq("Mixed signals across timeframes")
      end

      it "returns WAIT when confidence is below the threshold" do
        summary = summary_with_trends(d1: "bearish", h4: "bearish", h1: "bearish")
        analysis = tradable_analysis(action: "SELL", confidence: 65)

        result = mode.apply_tradable_analysis(analysis, summary, min_confidence: min_confidence)

        expect(result[:action]).to eq("WAIT")
        expect(result[:reason]).to include("below 70 threshold")
      end
    end

    context "in tactical mode" do
      let(:mode) { described_class.new("tactical") }

      it "allows SELL when H4 and H1 are bearish even if D1 is bullish" do
        summary = summary_with_trends(d1: "bullish", h4: "bearish", h1: "bearish")
        analysis = tradable_analysis(action: "SELL", confidence: 80, reason: "Lower timeframe breakdown")

        result = mode.apply_tradable_analysis(analysis, summary, min_confidence: min_confidence)

        expect(result[:action]).to eq("SELL")
        expect(result[:confidence]).to eq(70)
        expect(result[:reason]).to include("Lower timeframe breakdown")
        expect(result[:reason]).to include(TradingMode::TACTICAL_REASON)
      end

      it "does not apply a penalty when D1 agrees" do
        summary = summary_with_trends(d1: "bearish", h4: "bearish", h1: "bearish")
        analysis = tradable_analysis(action: "SELL", confidence: 78)

        result = mode.apply_tradable_analysis(analysis, summary, min_confidence: min_confidence)

        expect(result[:action]).to eq("SELL")
        expect(result[:confidence]).to eq(78)
        expect(result[:reason]).not_to include(TradingMode::TACTICAL_REASON)
      end

      it "returns WAIT when the D1 penalty drops confidence below 70" do
        summary = summary_with_trends(d1: "bullish", h4: "bearish", h1: "bearish")
        analysis = tradable_analysis(action: "SELL", confidence: 75)

        result = mode.apply_tradable_analysis(analysis, summary, min_confidence: min_confidence)

        expect(result[:action]).to eq("WAIT")
        expect(result[:reason]).to include("below 70 threshold")
      end

      it "returns WAIT when H4 and H1 are not aligned" do
        summary = summary_with_trends(d1: "bearish", h4: "bearish", h1: "bullish")
        analysis = tradable_analysis(action: "SELL", confidence: 85)

        result = mode.apply_tradable_analysis(analysis, summary, min_confidence: min_confidence)

        expect(result[:action]).to eq("WAIT")
        expect(result[:reason]).to eq("H4 and H1 trends not aligned")
      end
    end
  end

  describe "#infer_daily_signal" do
    let(:min_confidence) { 70 }

    it "returns nil in conservative mode" do
      summary = summary_with_trends(d1: "bullish", h4: "bearish", h1: "bearish")
      mode = described_class.new("conservative")

      expect(mode.infer_daily_signal(summary, min_confidence: min_confidence)).to be_nil
    end

    it "infers SELL when H4 and H1 are bearish and D1 disagrees" do
      summary = summary_with_trends(d1: "bullish", h4: "bearish", h1: "bearish")
      mode = described_class.new("tactical")

      result = mode.infer_daily_signal(summary, min_confidence: min_confidence)

      expect(result[:action]).to eq("SELL")
      expect(result[:confidence]).to eq(70)
      expect(result[:timeframe]).to eq("H1")
      expect(result[:reason]).to include(TradingMode::TACTICAL_REASON)
    end

    it "infers BUY with a D1 agreement bonus" do
      summary = summary_with_trends(d1: "bullish", h4: "bullish", h1: "bullish")
      mode = described_class.new("tactical")

      result = mode.infer_daily_signal(summary, min_confidence: min_confidence)

      expect(result[:action]).to eq("BUY")
      expect(result[:confidence]).to eq(85)
    end

    it "returns nil when H4 and H1 are not aligned" do
      summary = summary_with_trends(d1: "bearish", h4: "bearish", h1: "bullish")
      mode = described_class.new("tactical")

      expect(mode.infer_daily_signal(summary, min_confidence: min_confidence)).to be_nil
    end
  end
end
