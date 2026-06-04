# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_04_132801) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "daily_performances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.decimal "profit_loss", precision: 15, scale: 5, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_daily_performances_on_date", unique: true
  end

  create_table "economic_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "external_id"
    t.string "impact", null: false
    t.datetime "scheduled_at", null: false
    t.string "source", default: "manual", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["currency", "impact"], name: "index_economic_events_on_currency_and_impact"
    t.index ["external_id"], name: "index_economic_events_on_external_id", unique: true
    t.index ["scheduled_at"], name: "index_economic_events_on_scheduled_at"
    t.index ["source"], name: "index_economic_events_on_source"
  end

  create_table "execution_audit_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "entry_price", precision: 15, scale: 5
    t.string "event_status", null: false
    t.bigint "order_id"
    t.jsonb "payload", default: {}, null: false
    t.bigint "position_id"
    t.decimal "profit_loss", precision: 15, scale: 5
    t.string "source", null: false
    t.string "ticket"
    t.datetime "updated_at", null: false
    t.index ["order_id", "created_at"], name: "index_execution_audit_logs_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_execution_audit_logs_on_order_id"
    t.index ["position_id", "created_at"], name: "index_execution_audit_logs_on_position_id_and_created_at"
    t.index ["position_id"], name: "index_execution_audit_logs_on_position_id"
    t.index ["source"], name: "index_execution_audit_logs_on_source"
  end

  create_table "market_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "ema200", precision: 18, scale: 8
    t.decimal "ema50", precision: 18, scale: 8
    t.decimal "price", precision: 18, scale: 8
    t.decimal "resistance", precision: 18, scale: 8
    t.decimal "rsi", precision: 8, scale: 4
    t.decimal "support", precision: 18, scale: 8
    t.string "symbol", null: false
    t.string "timeframe", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.decimal "entry_price", precision: 15, scale: 5, null: false
    t.string "entry_type", null: false
    t.datetime "expires_at"
    t.datetime "opened_at"
    t.decimal "risk_reward", precision: 10, scale: 2
    t.string "status", default: "pending", null: false
    t.decimal "stop_loss", precision: 15, scale: 5, null: false
    t.decimal "take_profit", precision: 15, scale: 5, null: false
    t.string "ticket"
    t.integer "tp_leg", default: 1, null: false
    t.bigint "trade_signal_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket"], name: "index_orders_on_ticket", unique: true, where: "(ticket IS NOT NULL)"
    t.index ["trade_signal_id"], name: "index_orders_on_trade_signal_id"
  end

  create_table "positions", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.decimal "entry_price", precision: 15, scale: 5, null: false
    t.datetime "opened_at", null: false
    t.bigint "order_id", null: false
    t.decimal "profit_loss", precision: 15, scale: 5
    t.string "status", default: "open", null: false
    t.decimal "stop_loss", precision: 15, scale: 5, null: false
    t.string "symbol", null: false
    t.decimal "take_profit", precision: 15, scale: 5, null: false
    t.string "ticket", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_positions_on_order_id", unique: true
    t.index ["ticket"], name: "index_positions_on_ticket", unique: true
  end

  create_table "trade_performances", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "closed_at", null: false
    t.datetime "created_at", null: false
    t.decimal "entry_price", precision: 15, scale: 5, null: false
    t.decimal "exit_price", precision: 15, scale: 5, null: false
    t.datetime "opened_at", null: false
    t.bigint "position_id", null: false
    t.decimal "profit_loss", precision: 15, scale: 5, null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["position_id"], name: "index_trade_performances_on_position_id", unique: true
  end

  create_table "trade_signals", force: :cascade do |t|
    t.string "action", null: false
    t.integer "confidence", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "market_snapshot_id", null: false
    t.text "reason"
    t.string "rejection_reason"
    t.string "symbol", null: false
    t.string "timeframe"
    t.datetime "updated_at", null: false
    t.index ["market_snapshot_id"], name: "index_trade_signals_on_market_snapshot_id"
  end

  add_foreign_key "execution_audit_logs", "orders"
  add_foreign_key "execution_audit_logs", "positions"
  add_foreign_key "orders", "trade_signals"
  add_foreign_key "positions", "orders"
  add_foreign_key "trade_performances", "positions"
  add_foreign_key "trade_signals", "market_snapshots"
end
