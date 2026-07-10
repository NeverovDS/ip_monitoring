# frozen_string_literal: true

Sequel.migration do
  change do
    run <<-SQL
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
end
