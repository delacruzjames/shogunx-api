class AlignOrdersWithSpec < ActiveRecord::Migration[8.1]
  def change
    change_column :orders, :entry_price, :decimal, precision: 15, scale: 5, null: false
    change_column :orders, :stop_loss, :decimal, precision: 15, scale: 5, null: false
    change_column :orders, :take_profit, :decimal, precision: 15, scale: 5, null: false
    add_column :orders, :risk_reward, :decimal, precision: 10, scale: 2
  end
end
