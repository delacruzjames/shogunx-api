class AllowNullTimeframeOnTradeSignals < ActiveRecord::Migration[8.1]
  def change
    change_column_null :trade_signals, :timeframe, true
  end
end
