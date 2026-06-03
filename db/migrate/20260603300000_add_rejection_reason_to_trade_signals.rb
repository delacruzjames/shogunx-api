class AddRejectionReasonToTradeSignals < ActiveRecord::Migration[8.1]
  def change
    add_column :trade_signals, :rejection_reason, :string
  end
end
