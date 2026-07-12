class CreateIps < ActiveRecord::Migration[8.1]
  def change
    create_table :ips do |t|
      t.inet :ip_address, null: false
      t.boolean :enabled, null: false, default: false

      t.timestamps
    end

    add_index :ips, :ip_address, unique: true
  end
end
