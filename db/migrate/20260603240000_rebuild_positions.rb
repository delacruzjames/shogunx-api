class RebuildPositions < ActiveRecord::Migration[8.1]
  def up
    drop_table :positions, if_exists: true

    create_table :positions do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.string :ticket, null: false
      t.string :symbol, null: false
      t.string :action, null: false
      t.decimal :entry_price, precision: 15, scale: 5, null: false
      t.decimal :stop_loss, precision: 15, scale: 5, null: false
      t.decimal :take_profit, precision: 15, scale: 5, null: false
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.string :status, null: false, default: "open"

      t.timestamps
    end

    add_index :positions, :ticket, unique: true
  end

  def down
    drop_table :positions, if_exists: true

    create_table :positions do |t|
      t.string "action", null: false
      t.decimal "close_price", precision: 18, scale: 8
      t.datetime "closed_at"
      t.datetime "created_at", null: false
      t.bigint "mt4_ticket", null: false
      t.decimal "open_price", precision: 18, scale: 8, null: false
      t.datetime "opened_at", null: false
      t.bigint "order_id", null: false
      t.decimal "profit", precision: 18, scale: 8
      t.string "status", default: "open", null: false
      t.decimal "stop_loss", precision: 18, scale: 8, null: false
      t.string "symbol", null: false
      t.decimal "take_profit", precision: 18, scale: 8, null: false
      t.datetime "updated_at", null: false
      t.decimal "volume", precision: 10, scale: 2, null: false
      t.index ["mt4_ticket"], name: "index_positions_on_mt4_ticket", unique: true
      t.index ["order_id"], name: "index_positions_on_order_id", unique: true
    end

    add_foreign_key :positions, :orders
  end
end
