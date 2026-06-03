class CreateExecutionAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :execution_audit_logs do |t|
      t.references :order, foreign_key: true
      t.references :position, foreign_key: true
      t.string :source, null: false
      t.string :event_status, null: false
      t.string :ticket
      t.decimal :entry_price, precision: 15, scale: 5
      t.decimal :profit_loss, precision: 15, scale: 5
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :execution_audit_logs, :source
    add_index :execution_audit_logs, [ :order_id, :created_at ]
    add_index :execution_audit_logs, [ :position_id, :created_at ]
  end
end
