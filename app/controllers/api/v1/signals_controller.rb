module Api
  module V1
    class SignalsController < BaseController
      SNAPSHOT_KEYS = %i[symbol timeframe price rsi ema50 ema200 support resistance].freeze
      TIMEFRAME_METRIC_KEYS = %i[price rsi ema50 ema200 support resistance].freeze
      TIMEFRAME_KEYS = MarketSnapshot::ANALYSIS_TIMEFRAMES.freeze

      def create
        snapshot = MarketSnapshotIngestService.new(snapshot_params).call
        log_snapshot_received(snapshot)
        result = EndToEndSignalPipelineService.new(snapshot).call
        render json: result
      rescue ActiveRecord::RecordInvalid => error
        render json: {
          status: "error",
          errors: error.record.errors.full_messages
        }, status: :unprocessable_content
      end

      private

      def log_snapshot_received(snapshot)
        ActivityLogService.record(
          category: "snapshot",
          level: "info",
          message: "Market snapshot received from MT4 (#{snapshot.symbol} #{snapshot.timeframe})",
          metadata: {
            symbol: snapshot.symbol,
            timeframe: snapshot.timeframe,
            price: snapshot.price,
            snapshot_id: snapshot.id
          },
          market_snapshot: snapshot
        )
      end

      # MT4 posts raw JSON; nested timeframes are plain hashes (not ActionController::Parameters).
      def snapshot_params
        raw = params.to_unsafe_h.deep_symbolize_keys
        payload = raw.slice(*SNAPSHOT_KEYS)

        timeframes = raw[:timeframes]
        if timeframes.is_a?(Hash)
          payload[:timeframes] = timeframes.each_with_object({}) do |(key, metrics), normalized|
            next unless TIMEFRAME_KEYS.include?(key.to_s)

            normalized[key.to_s] = metrics.to_h.deep_symbolize_keys.slice(*TIMEFRAME_METRIC_KEYS)
          end
        end

        payload
      end
    end
  end
end
