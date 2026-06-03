class AddForexfactoryFieldsToEconomicEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :economic_events, :source, :string, null: false, default: "manual"
    add_column :economic_events, :external_id, :string

    add_index :economic_events, :external_id, unique: true
    add_index :economic_events, :source
  end
end
