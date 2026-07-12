SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: log_ip_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_ip_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.enabled != NEW.enabled) THEN
    INSERT INTO ip_status_changes (ip_id, status, created_at)
    VALUES (NEW.id, NEW.enabled, NOW());
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ip_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ip_checks (
    id bigint NOT NULL,
    ip_id bigint NOT NULL,
    rtt double precision,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ip_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ip_checks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_checks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_checks_id_seq OWNED BY public.ip_checks.id;


--
-- Name: ip_status_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ip_status_changes (
    id bigint NOT NULL,
    ip_id bigint NOT NULL,
    status boolean NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ip_status_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ip_status_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_status_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_status_changes_id_seq OWNED BY public.ip_status_changes.id;


--
-- Name: ips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ips (
    id bigint NOT NULL,
    ip_address inet NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ips_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ips_id_seq OWNED BY public.ips.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: ip_checks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_checks ALTER COLUMN id SET DEFAULT nextval('public.ip_checks_id_seq'::regclass);


--
-- Name: ip_status_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_status_changes ALTER COLUMN id SET DEFAULT nextval('public.ip_status_changes_id_seq'::regclass);


--
-- Name: ips id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ips ALTER COLUMN id SET DEFAULT nextval('public.ips_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: ip_checks ip_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_checks
    ADD CONSTRAINT ip_checks_pkey PRIMARY KEY (id);


--
-- Name: ip_status_changes ip_status_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_status_changes
    ADD CONSTRAINT ip_status_changes_pkey PRIMARY KEY (id);


--
-- Name: ips ips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ips
    ADD CONSTRAINT ips_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_ip_checks_on_ip_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_checks_on_ip_id ON public.ip_checks USING btree (ip_id);


--
-- Name: index_ip_status_changes_on_ip_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_status_changes_on_ip_id ON public.ip_status_changes USING btree (ip_id);


--
-- Name: index_ips_on_ip_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ips_on_ip_address ON public.ips USING btree (ip_address);


--
-- Name: ips ip_status_change_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ip_status_change_trigger AFTER INSERT OR UPDATE OF enabled ON public.ips FOR EACH ROW EXECUTE FUNCTION public.log_ip_status_change();


--
-- Name: ip_status_changes fk_rails_2d0f8884bc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_status_changes
    ADD CONSTRAINT fk_rails_2d0f8884bc FOREIGN KEY (ip_id) REFERENCES public.ips(id) ON DELETE CASCADE;


--
-- Name: ip_checks fk_rails_c608089efe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_checks
    ADD CONSTRAINT fk_rails_c608089efe FOREIGN KEY (ip_id) REFERENCES public.ips(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260710113146'),
('20260710113027'),
('20260710113026'),
('20260710113025');

