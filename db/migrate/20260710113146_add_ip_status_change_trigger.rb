class AddIpStatusChangeTrigger < ActiveRecord::Migration[8.1]
  # A row is written to ip_status_changes whenever an IP is created or its
  # `enabled` flag flips. Keeping this in the database (not the app) guarantees
  # the history is recorded even for writes that bypass ActiveRecord.
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION log_ip_status_change()
      RETURNS TRIGGER AS $$
      BEGIN
        IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.enabled != NEW.enabled) THEN
          INSERT INTO ip_status_changes (ip_id, status, created_at)
          VALUES (NEW.id, NEW.enabled, NOW());
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER ip_status_change_trigger
      AFTER INSERT OR UPDATE OF enabled ON ips
      FOR EACH ROW
      EXECUTE FUNCTION log_ip_status_change();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS ip_status_change_trigger ON ips;
      DROP FUNCTION IF EXISTS log_ip_status_change();
    SQL
  end
end
