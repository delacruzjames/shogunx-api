class CreateEconomicEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :economic_events do |t|
      t.string :currency, null: false
      t.string :impact, null: false
      t.string :title
      t.datetime :scheduled_at, null: false

      t.timestamps
    end

    add_index :economic_events, :scheduled_at
    add_index :economic_events, [ :currency, :impact ]
  end
end
