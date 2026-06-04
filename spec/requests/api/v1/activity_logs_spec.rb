require "rails_helper"

RSpec.describe "Api::V1::ActivityLogs", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  describe "GET /api/v1/activity_logs" do
    it "returns recent pipeline activity newest first" do
      ActivityLogService.record(category: "system", message: "Older event", level: "info")
      travel 1.second
      ActivityLogService.record(category: "analysis", message: "Newer event", level: "success")

      get api_v1_activity_logs_path

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["data"].first["message"]).to eq("Newer event")
      expect(body["data"].first["category"]).to eq("analysis")
      expect(body["meta"]["limit"]).to eq(100)
    end

    it "respects the limit parameter" do
      3.times { |i| ActivityLogService.record(category: "system", message: "Event #{i}") }

      get api_v1_activity_logs_path, params: { limit: 2 }

      expect(response.parsed_body["data"].size).to eq(2)
      expect(response.parsed_body["meta"]["limit"]).to eq(2)
    end

    it "returns only newer rows when since_id is set (chronological)" do
      first = ActivityLogService.record(category: "system", message: "First")
      ActivityLogService.record(category: "analysis", message: "Second")

      get api_v1_activity_logs_path, params: { since_id: first.id }

      body = response.parsed_body
      expect(body["meta"]["incremental"]).to eq(true)
      expect(body["data"].size).to eq(1)
      expect(body["data"].first["message"]).to eq("Second")
      expect(body["data"].first["id"]).to be > first.id
    end
  end
end
