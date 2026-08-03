class CreateMetaAds < ActiveRecord::Migration[7.1]
  def change
    create_table :meta_ads do |t|
      t.string :ad_id, null: false, index: { unique: true }
      t.string :name
      t.string :adset_id
      t.string :adset_name
      t.string :campaign_id
      t.string :campaign_name
      t.string :thumbnail_url
      t.string :effective_status
      t.datetime :synced_at
      t.string :sync_error

      t.timestamps
    end
  end
end
