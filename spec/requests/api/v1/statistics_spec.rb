require "rails_helper"

RSpec.describe "Api::V1::Statistics", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  def create_trade(profit_loss:, closed_at: Time.current)
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: 3350
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
      status: :closed
    )
    position = Position.create!(
      order: order,
      ticket: "api-stats-#{SecureRandom.hex(4)}",
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350.50,
      stop_loss: 3335,
      take_profit: 3380,
      status: :closed,
      profit_loss: profit_loss,
      opened_at: 2.hours.ago,
      closed_at: closed_at
    )

    TradePerformance.create!(
      position: position,
      symbol: position.symbol,
      action: position.action,
      entry_price: position.entry_price,
      exit_price: 3375.50,
      profit_loss: profit_loss,
      opened_at: position.opened_at,
      closed_at: position.closed_at
    )
  end

  describe "GET /api/v1/statistics" do
    it "returns dashboard-ready trade statistics" do
      travel_to Time.zone.local(2026, 6, 3, 12, 0, 0) do
        create_trade(profit_loss: 75, closed_at: Time.current)

        get api_v1_statistics_path, params: { from: "2026-06-03", to: "2026-06-03", daily_days: 1 }

        expect(response).to have_http_status(:ok)

        body = response.parsed_body
        expect(body["summary"]["total_trades"]).to eq(1)
        expect(body["summary"]["wins"]).to eq(1)
        expect(body["summary"]["total_profit_loss"]).to eq("75.0")
        expect(body["daily_pnl"]).to be_an(Array)
        expect(body["monthly_pnl"]).to be_an(Array)
        expect(body["generated_at"]).to be_present
      end
    end
  end
end
