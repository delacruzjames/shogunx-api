class MarketSnapshotIngestService
  SNAPSHOT_FIELDS = %i[price rsi ema50 ema200 support resistance].freeze

  def initialize(params)
    @params = params
  end

  def call
    validate_payload!
    snapshots = MarketSnapshot::ANALYSIS_TIMEFRAMES.map { |timeframe| create_snapshot!(timeframe) }
    snapshots.find { |snapshot| snapshot.timeframe == MarketSnapshot::PRIMARY_TIMEFRAME } || snapshots.first
  end

  private

  def validate_payload!
    MarketSnapshot::ANALYSIS_TIMEFRAMES.each do |timeframe|
      data = metrics_for(timeframe)
      missing = SNAPSHOT_FIELDS.select { |field| data[field].nil? }
      next if missing.empty?

      record = MarketSnapshot.new(symbol: symbol, timeframe: timeframe)
      record.errors.add(:base, "Missing required market data for #{timeframe}: #{missing.join(', ')}")
      raise ActiveRecord::RecordInvalid, record
    end
  end

  def create_snapshot!(timeframe)
    MarketSnapshot.create!(snapshot_attributes(timeframe))
  end

  def snapshot_attributes(timeframe)
    data = metrics_for(timeframe)
    {
      symbol: symbol,
      timeframe: timeframe,
      price: data[:price],
      rsi: data[:rsi],
      ema50: data[:ema50],
      ema200: data[:ema200],
      support: data[:support],
      resistance: data[:resistance]
    }
  end

  def metrics_for(timeframe)
    if multi_timeframe_payload?
      extract_metrics(timeframes_payload[timeframe] || timeframes_payload[timeframe.to_sym])
    else
      extract_metrics(@params)
    end
  end

  def extract_metrics(source)
    return {} if source.blank?

    SNAPSHOT_FIELDS.index_with { |field| cast_metric(source[field] || source[field.to_s]) }
  end

  def cast_metric(value)
    return nil if value.nil? || value == ""

    value.is_a?(String) ? value.to_f : value
  end

  def symbol
    @params[:symbol].presence || @params["symbol"].presence || MarketSummaryService::DEFAULT_SYMBOL
  end

  def multi_timeframe_payload?
    timeframes_payload.present?
  end

  def timeframes_payload
    raw = @params[:timeframes] || @params["timeframes"]
    return nil if raw.blank?

    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
  end
end
