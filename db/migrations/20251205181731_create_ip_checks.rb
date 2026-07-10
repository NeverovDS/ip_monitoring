# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:ip_checks) do
      primary_key :id
      foreign_key :ip_id, :ips, null: false, on_delete: :cascade
      column :rtt, :float
      column :created_at, :timestamp, null: false
    end
  end
end
