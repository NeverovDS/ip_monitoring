class CreateIpChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :ip_checks do |t|
      t.references :ip, null: false, foreign_key: { on_delete: :cascade }
      t.float :rtt # nil = unreachable (counts toward packet loss)

      t.datetime :created_at, null: false
    end
  end
end
