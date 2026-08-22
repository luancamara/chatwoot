class UpgradeAdConversionsToCanonicalLedger < ActiveRecord::Migration[7.1]
  def up
    add_canonical_columns
    migrate_and_consolidate_conversions
    replace_canonical_index
    remove_legacy_columns
    create_delivery_table
    mark_legacy_meta_deliveries
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Canonical order consolidation cannot restore duplicate conversion rows'
  end

  private

  def add_canonical_columns
    change_column_null :ad_conversions, :conversation_ad_referral_id, true
    add_column :ad_conversions, :erp_status, :integer
    add_column :ad_conversions, :origin_classification, :string, null: false, default: 'unknown'
    add_column :ad_conversions, :origin_data, :jsonb, null: false, default: {}
    add_column :ad_conversions, :user_data, :jsonb, null: false, default: {}
    add_column :ad_conversions, :last_observed_at, :datetime
  end

  def replace_canonical_index
    remove_index :ad_conversions, name: 'index_ad_conversions_on_referral_and_order'
    add_index :ad_conversions, [:account_id, :erp_order_ref], unique: true, name: 'index_ad_conversions_on_account_and_order'
  end

  def remove_legacy_columns
    change_column_null :ad_conversions, :last_observed_at, false
    remove_column :ad_conversions, :erp_client_id, :integer
    remove_column :ad_conversions, :erp_midia, :integer
  end

  def create_delivery_table
    create_table :ad_conversion_deliveries do |t|
      add_delivery_columns(t)
      t.timestamps
    end

    add_delivery_indexes
  end

  def add_delivery_columns(table)
    table.references :ad_conversion, null: false, foreign_key: true, index: false
    table.string :provider, null: false
    table.string :status, null: false, default: 'pending'
    table.integer :attempts, null: false, default: 0
    table.string :external_event_id
    table.string :external_request_id
    table.string :error_code
    table.text :error_message
    table.jsonb :diagnostic_data, null: false, default: {}
    table.datetime :last_attempted_at
    table.datetime :next_attempt_at
    table.datetime :submitted_at
    table.datetime :accepted_at
    table.datetime :retracted_at
  end

  def add_delivery_indexes
    add_index :ad_conversion_deliveries, [:ad_conversion_id, :provider], unique: true,
                                                                         name: 'index_ad_conversion_deliveries_on_conversion_provider'
    add_index :ad_conversion_deliveries, [:provider, :status, :next_attempt_at],
              name: 'index_ad_conversion_deliveries_for_dispatch'
  end

  def migrate_and_consolidate_conversions
    migration_ad_conversion.reset_column_information
    migration_referral.reset_column_information

    connection.select_rows('SELECT DISTINCT account_id, erp_order_ref FROM ad_conversions').each do |account_id, order_ref|
      conversions = migration_ad_conversion.where(account_id: account_id, erp_order_ref: order_ref).order(updated_at: :desc).to_a
      winner = conversions.first
      last_touch = last_touch_for(conversions, winner)

      winner.update!(
        conversation_ad_referral_id: last_touch&.id,
        erp_status: winner.status == 'cancelled' ? 6 : 4,
        origin_data: legacy_origin_data(winner),
        last_observed_at: winner.updated_at
      )
      migration_ad_conversion.where(id: conversions.drop(1).map(&:id)).delete_all
    end
  end

  def last_touch_for(conversions, winner)
    migration_referral.where(id: conversions.filter_map(&:conversation_ad_referral_id))
                      .where('referred_at <= ?', winner.ordered_at)
                      .order(referred_at: :desc)
                      .first
  end

  def legacy_origin_data(conversion)
    return {} if conversion.erp_midia.blank?

    { 'media_ref' => conversion.erp_midia.to_s }
  end

  def mark_legacy_meta_deliveries
    execute <<~SQL.squish
      INSERT INTO ad_conversion_deliveries
        (ad_conversion_id, provider, status, attempts, external_event_id, diagnostic_data, created_at, updated_at)
      SELECT id, 'meta', 'legacy_unknown', 0, erp_order_ref, '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM ad_conversions
    SQL
  end

  def migration_ad_conversion
    @migration_ad_conversion ||= Class.new(ActiveRecord::Base) do
      self.table_name = 'ad_conversions'
    end
  end

  def migration_referral
    @migration_referral ||= Class.new(ActiveRecord::Base) do
      self.table_name = 'conversation_ad_referrals'
    end
  end
end
