class AddResponseReassignmentToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :inboxes, :response_reassignment_mode, :integer, default: 0, null: false
    add_column :inboxes, :response_reassignment_notify_user_id, :bigint
  end
end
