class ProcessMarketSnapshotService
  def initialize(snapshot)
    @snapshot = snapshot
  end

  def call
    EndToEndSignalPipelineService.new(@snapshot).call
  end
end
