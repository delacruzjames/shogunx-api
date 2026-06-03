require "rails_helper"

RSpec.describe DailyPerformance, type: :model do
  describe "validations" do
    it "is valid with date and profit_loss" do
      record = described_class.new(date: Date.current, profit_loss: -50.25)

      expect(record).to be_valid
    end

    it "requires a unique date" do
      described_class.create!(date: Date.current, profit_loss: 0)
      duplicate = described_class.new(date: Date.current, profit_loss: 10)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:date]).to include("has already been taken")
    end
  end

  describe ".for_today" do
    it "returns the record for the current date" do
      record = described_class.create!(date: Time.zone.today, profit_loss: 12.5)

      expect(described_class.for_today).to eq(record)
    end
  end
end
