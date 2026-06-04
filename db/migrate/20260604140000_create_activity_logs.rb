class CreateActivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_logs do |t|
      t.string :category, null: false
      t.string :level, null: false, default: "info"
      t.text :message, null: false
      t.jsonb :metadata, null: false, default: {}
      t.references :market_snapshot, foreign_key: true
      t.references :trade_signal, foreign_key: true
      t.references :order, foreign_key: true

      t.timestamps
    end

    add_index :activity_logs, :created_at
    add_index :activity_logs, :category
  end
end
