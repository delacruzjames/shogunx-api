require "rails_helper"

RSpec.describe "Api::V1::Signals", type: :request do
  describe "POST /api/v1/signals" do
    let(:wait_payload) do
      {
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87,
        rsi: 45.0,
        ema50: 4490.0,
        ema200: 4470.0,
        support: 4438.85,
        resistance: 4496.63
      }
    end

    let(:buy_payload) do
      {
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87,
        rsi: 68.0,
        ema50: 4490.0,
        ema200: 4470.0,
        support: 3350.0,
        resistance: 3380.0
      }
    end

    it "creates a market snapshot and returns HOLD when analysis is WAIT" do
      stub_openai_wait(reason: "No actionable setup")

      expect {
        post api_v1_signals_path, params: wait_payload, as: :json
      }.to change(MarketSnapshot, :count).by(3)
        .and change(TradeSignal, :count).by(1)
        .and change(Order, :count).by(0)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "action" => "HOLD",
        "reason" => "No actionable setup"
      )
    end

    it "returns executable instructions when the pipeline approves a trade" do
      post api_v1_signals_path, params: buy_payload, as: :json

      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body["action"]).to eq("BUY_LIMIT")
      expect(body["symbol"]).to eq("XAUUSD")
      expect(body["order_id"]).to eq(Order.find_by!(tp_leg: 1).id)
      expect(body["entry_price"]).to eq("3350.0")
      expect(body["stop_loss"]).to eq("3335.0")
      expect(body["take_profit"]).to eq("3370.0")
      expect(Order.pending.count).to eq(3)
      expect(Order.pending.order(:tp_leg).pluck(:tp_leg, :take_profit)).to eq(
        [ [ 1, 3370.0 ], [ 2, 3380.0 ], [ 3, 3380.0 ] ]
      )
    end

    it "returns HOLD with rejection reason when risk blocks the trade" do
      snapshot = MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 3350,
        rsi: 60,
        ema50: 3360,
        ema200: 3340,
        support: 3350,
        resistance: 3380
      )
      trade_signal = TradeSignal.create!(
        market_snapshot: snapshot,
        symbol: "XAUUSD",
        action: "BUY",
        confidence: 75,
        timeframe: "H4"
      )
      order = Order.create!(
        trade_signal: trade_signal,
        action: "BUY",
        entry_type: "BUY_LIMIT",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        risk_reward: 2.0,
        status: :triggered
      )
      Position.create!(
        order: order,
        ticket: "signals-spec-#{SecureRandom.hex(4)}",
        symbol: "XAUUSD",
        action: "BUY",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        opened_at: Time.current
      )

      post api_v1_signals_path, params: buy_payload, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["action"]).to eq("HOLD")
      expect(response.parsed_body["reason"]).to eq("duplicate signal action")
      expect(TradeSignal.last.rejection_reason).to eq("duplicate signal action")
    end

    it "accepts flat JSON like the MT4 EA (no :signal wrapper)" do
      post api_v1_signals_path,
        params: buy_payload.to_json,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "ACCEPT" => "application/json"
        }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["action"]).to eq("BUY_LIMIT")
      expect(response.parsed_body).not_to have_key("signal")
    end

    it "returns errors when required fields are missing" do
      post api_v1_signals_path, params: { symbol: "XAUUSD" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)

      body = response.parsed_body
      expect(body["status"]).to eq("error")
      expect(body["errors"].join).to include("Missing required market data")
    end
  end
end
