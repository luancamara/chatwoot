class CreateConversationRiskMonitorConfigs < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_risk_monitor_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true, index: { unique: true }
      t.references :management_team, foreign_key: { to_table: :teams }
      t.references :complaint_label, foreign_key: { to_table: :labels }
      t.references :critical_label, foreign_key: { to_table: :labels }
      t.boolean :enabled, null: false, default: false

      t.timestamps
    end
  end
end
