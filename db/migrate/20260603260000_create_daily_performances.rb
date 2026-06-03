class CreateDailyPerformances < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_performances do |t|
      t.date :date, null: false
      t.decimal :profit_loss, precision: 15, scale: 5, null: false, default: 0

      t.timestamps
    end

    add_index :daily_performances, :date, unique: true
  end
end
