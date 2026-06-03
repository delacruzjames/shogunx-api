class CreateTradeSignals < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_signals do |t|
      t.string :symbol, null: false
      t.string :action, null: false
      t.integer :confidence, null: false
      t.string :timeframe, null: false
      t.text :reason
      t.datetime :expires_at

      t.timestamps
    end
  end
end
