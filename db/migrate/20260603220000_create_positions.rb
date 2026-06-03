class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.string :symbol, null: false
      t.string :action, null: false
      t.decimal :volume, precision: 10, scale: 2, null: false
      t.decimal :open_price, precision: 18, scale: 8, null: false
      t.decimal :stop_loss, precision: 18, scale: 8, null: false
      t.decimal :take_profit, precision: 18, scale: 8, null: false
      t.string :status, null: false, default: "open"
      t.bigint :mt4_ticket, null: false
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.decimal :close_price, precision: 18, scale: 8
      t.decimal :profit, precision: 18, scale: 8

      t.timestamps
    end

    add_index :positions, :mt4_ticket, unique: true
  end
end
