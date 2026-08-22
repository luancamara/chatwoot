class UpgradeConversationInsightsForEvaluation < ActiveRecord::Migration[7.1]
  def change
    change_table :conversation_insights, bulk: true do |t|
      t.string :conversation_classification
      t.decimal :final_score, precision: 4, scale: 2
      t.boolean :no_response, default: false # rubocop:disable Rails/ThreeStateBooleanColumn
      t.string :abandonment_severity
      t.boolean :media_sent, default: false # rubocop:disable Rails/ThreeStateBooleanColumn
      t.jsonb :automatic_metrics, default: {}
      t.jsonb :penalties, default: []
      t.text :feedback_summary
    end

    change_column :conversation_insights, :quality_score, :decimal, precision: 4, scale: 2 # rubocop:disable Rails/ReversibleMigration

    add_index :conversation_insights, :conversation_classification, name: 'idx_conv_insights_classification'
    add_index :conversation_insights, :final_score, name: 'idx_conv_insights_final_score'
    add_index :conversation_insights, :no_response, name: 'idx_conv_insights_no_response'
  end
end
