require "rails_helper"

RSpec.describe NewsSyncJob, type: :job do
  describe "#perform" do
    it "syncs high-impact USD events from ForexFactory" do
      sync = instance_double(
        ForexFactoryCalendarSyncService,
        call: ForexFactoryCalendarSyncService::Result.new(success?: true, imported_count: 2, errors: [])
      )
      allow(ForexFactoryCalendarSyncService).to receive(:new).with(force: true).and_return(sync)

      described_class.perform_now

      expect(ForexFactoryCalendarSyncService).to have_received(:new).with(force: true)
      expect(sync).to have_received(:call)
    end

    it "logs when the sync fails" do
      sync = instance_double(
        ForexFactoryCalendarSyncService,
        call: ForexFactoryCalendarSyncService::Result.new(success?: false, imported_count: 0, errors: [ "offline" ])
      )
      allow(ForexFactoryCalendarSyncService).to receive(:new).with(force: true).and_return(sync)
      allow(Rails.logger).to receive(:warn)

      described_class.perform_now

      expect(Rails.logger).to have_received(:warn).with("[NewsSyncJob] ForexFactory sync failed: offline")
    end
  end
end
