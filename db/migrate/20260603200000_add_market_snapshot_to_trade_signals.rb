class AddMarketSnapshotToTradeSignals < ActiveRecord::Migration[8.1]
  def change
    add_reference :trade_signals, :market_snapshot, null: false, foreign_key: true
  end
end
