class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :trade_signal, null: false, foreign_key: true
      t.string :action, null: false
      t.string :entry_type, null: false
      t.decimal :entry_price, precision: 18, scale: 8, null: false
      t.decimal :stop_loss, precision: 18, scale: 8, null: false
      t.decimal :take_profit, precision: 18, scale: 8, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :opened_at
      t.datetime :closed_at
      t.datetime :expires_at

      t.timestamps
    end
  end
end
