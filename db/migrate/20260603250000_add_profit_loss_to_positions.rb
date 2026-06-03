class AddProfitLossToPositions < ActiveRecord::Migration[8.1]
  def change
    add_column :positions, :profit_loss, :decimal, precision: 15, scale: 5
  end
end
