class CreateTradePerformances < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_performances do |t|
      t.references :position, null: false, foreign_key: true, index: { unique: true }
      t.string :symbol, null: false
      t.string :action, null: false
      t.decimal :entry_price, precision: 15, scale: 5, null: false
      t.decimal :exit_price, precision: 15, scale: 5, null: false
      t.decimal :profit_loss, precision: 15, scale: 5, null: false
      t.datetime :opened_at, null: false
      t.datetime :closed_at, null: false

      t.timestamps
    end
  end
end
