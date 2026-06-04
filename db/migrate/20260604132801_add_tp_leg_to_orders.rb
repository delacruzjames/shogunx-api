class AddTpLegToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :tp_leg, :integer, null: false, default: 1
  end
end
