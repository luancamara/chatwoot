class CreateConversationEvaluationReports < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_evaluation_reports do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id
      t.string :report_type, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.jsonb :data, default: {}
      t.timestamps
    end

    add_index :conversation_evaluation_reports,
              [:account_id, :user_id, :report_type, :period_start],
              unique: true, name: 'idx_eval_reports_unique'
    add_foreign_key :conversation_evaluation_reports, :accounts
    add_foreign_key :conversation_evaluation_reports, :users
  end
end
