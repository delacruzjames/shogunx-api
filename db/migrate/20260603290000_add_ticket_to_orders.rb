class AddTicketToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :ticket, :string
    add_index :orders, :ticket, unique: true, where: "ticket IS NOT NULL"
  end
end
