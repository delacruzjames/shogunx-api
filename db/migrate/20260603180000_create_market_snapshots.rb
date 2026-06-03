class CreateMarketSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :market_snapshots do |t|
      t.string :symbol, null: false
      t.string :timeframe, null: false
      t.decimal :price, precision: 18, scale: 8
      t.decimal :rsi, precision: 8, scale: 4
      t.decimal :ema50, precision: 18, scale: 8
      t.decimal :ema200, precision: 18, scale: 8
      t.decimal :support, precision: 18, scale: 8
      t.decimal :resistance, precision: 18, scale: 8

      t.timestamps
    end
  end
end
