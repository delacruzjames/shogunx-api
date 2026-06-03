require "rails_helper"

RSpec.describe "Api::V1::Dashboard", type: :request do
  describe "GET /api/v1/dashboard" do
    it "returns read-only dashboard overview JSON" do
      get api_v1_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")

      body = response.parsed_body
      expect(body).to include(
        "generated_at",
        "xauusd_price",
        "latest_signal",
        "signal_confidence",
        "order_status",
        "open_position_status",
        "daily_pnl",
        "total_trades_today"
      )
    end
  end
end
