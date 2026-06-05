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
      expect(body["meta"]["page"]).to eq(1)
      expect(body["meta"]["per_page"]).to eq(20)
    end

    it "paginates activity newest first" do
      25.times { |i| ActivityLogService.record(category: "system", message: "Event #{i}") }

      get api_v1_activity_logs_path, params: { page: 1, per_page: 20 }

      body = response.parsed_body
      expect(body["data"].size).to eq(20)
      expect(body["data"].first["message"]).to eq("Event 24")
      expect(body["meta"]["page"]).to eq(1)
      expect(body["meta"]["per_page"]).to eq(20)
      expect(body["meta"]["total_count"]).to eq(25)
      expect(body["meta"]["total_pages"]).to eq(2)

      get api_v1_activity_logs_path, params: { page: 2, per_page: 20 }

      page2 = response.parsed_body
      expect(page2["data"].size).to eq(5)
      expect(page2["data"].first["message"]).to eq("Event 4")
    end

    it "respects the limit parameter as per_page" do
      3.times { |i| ActivityLogService.record(category: "system", message: "Event #{i}") }

      get api_v1_activity_logs_path, params: { limit: 2 }

      expect(response.parsed_body["data"].size).to eq(2)
      expect(response.parsed_body["meta"]["per_page"]).to eq(2)
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
