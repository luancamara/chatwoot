class RenameCrmClosedStages < ActiveRecord::Migration[7.1]
  STAGE_RENAMES = { 'Venda' => 'Ganho', 'Perda' => 'Perdido' }.freeze

  def up
    STAGE_RENAMES.each { |from, to| rename_stage(from, to) }
  end

  def down
    STAGE_RENAMES.each { |from, to| rename_stage(to, from) }
  end

  private

  def rename_stage(from, to)
    execute(<<~SQL.squish)
      UPDATE conversations
      SET custom_attributes = jsonb_set(custom_attributes, '{crm_funnel_stage}', '"#{to}"')
      WHERE custom_attributes->>'crm_funnel_stage' = '#{from}'
    SQL
  end
end
