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

ActiveRecord::Schema[8.1].define(version: 2026_06_03_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "trade_signals", force: :cascade do |t|
    t.string "action", null: false
    t.integer "confidence", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.text "reason"
    t.string "symbol", null: false
    t.string "timeframe", null: false
    t.datetime "updated_at", null: false
  end
end
