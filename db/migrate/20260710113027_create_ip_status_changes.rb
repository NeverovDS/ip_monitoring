class CreateIpStatusChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :ip_status_changes do |t|
      t.references :ip, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :status, null: false

      t.datetime :created_at, null: false
    end
  end
end
