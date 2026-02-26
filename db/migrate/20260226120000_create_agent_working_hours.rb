class CreateAgentWorkingHours < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_working_hours do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.integer :day_of_week, null: false
      t.integer :open_hour
      t.integer :open_minutes
      t.integer :close_hour
      t.integer :close_minutes
      t.boolean :closed_all_day, default: false
      t.timestamps
    end

    add_index :agent_working_hours, [:account_id, :user_id, :day_of_week],
              unique: true, name: 'idx_agent_wh_account_user_day'
    add_foreign_key :agent_working_hours, :accounts
    add_foreign_key :agent_working_hours, :users
  end
end
