# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :ips do
      primary_key :id
      column :ip_address, :inet, null: false
      column :enabled, :boolean, default: false
      column :created_at, :timestamp
      column :updated_at, :timestamp
    end

    add_index :ips, :ip_address, unique: true
  end
end
