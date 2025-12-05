--
-- PostgreSQL database dump
--

\restrict OszfBd8NLO09QzDFea7InbeqBcGip5fAa9S4vvcC3tUviSXNSKXK8UY0I5tfNIC

-- Dumped from database version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE IF EXISTS myapp;
--
-- Name: myapp; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE myapp WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';


ALTER DATABASE myapp OWNER TO postgres;

\unrestrict OszfBd8NLO09QzDFea7InbeqBcGip5fAa9S4vvcC3tUviSXNSKXK8UY0I5tfNIC
\connect myapp
\restrict OszfBd8NLO09QzDFea7InbeqBcGip5fAa9S4vvcC3tUviSXNSKXK8UY0I5tfNIC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: organizations; Type: TABLE; Schema: public; Owner: appuser
--

CREATE TABLE public.organizations (
    id uuid NOT NULL,
    name text NOT NULL,
    slug text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.organizations OWNER TO appuser;

--
-- Name: resources; Type: TABLE; Schema: public; Owner: appuser
--

CREATE TABLE public.resources (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    provider text NOT NULL,
    type text NOT NULL,
    name text NOT NULL,
    tags jsonb DEFAULT '{}'::jsonb NOT NULL,
    cost numeric(14,2) DEFAULT 0 NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT resources_provider_chk CHECK ((provider = ANY (ARRAY['AWS'::text, 'Azure'::text, 'GCP'::text]))),
    CONSTRAINT resources_status_chk CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'deleted'::text])))
);


ALTER TABLE public.resources OWNER TO appuser;

--
-- Name: users; Type: TABLE; Schema: public; Owner: appuser
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    organization_id uuid NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    role text DEFAULT 'user'::text NOT NULL,
    password_hash text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_role_chk CHECK ((role = ANY (ARRAY['admin'::text, 'user'::text, 'readonly'::text])))
);


ALTER TABLE public.users OWNER TO appuser;

--
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: appuser
--

COPY public.organizations (id, name, slug, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: resources; Type: TABLE DATA; Schema: public; Owner: appuser
--

COPY public.resources (id, organization_id, provider, type, name, tags, cost, status, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: appuser
--

COPY public.users (id, organization_id, email, name, role, password_hash, created_at, updated_at) FROM stdin;
\.


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: appuser
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: resources resources_pkey; Type: CONSTRAINT; Schema: public; Owner: appuser
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT resources_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: appuser
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: organizations_name_lower_uq; Type: INDEX; Schema: public; Owner: appuser
--

CREATE UNIQUE INDEX organizations_name_lower_uq ON public.organizations USING btree (lower(name));


--
-- Name: organizations_slug_lower_uq; Type: INDEX; Schema: public; Owner: appuser
--

CREATE UNIQUE INDEX organizations_slug_lower_uq ON public.organizations USING btree (lower(slug)) WHERE (slug IS NOT NULL);


--
-- Name: resources_org_idx; Type: INDEX; Schema: public; Owner: appuser
--

CREATE INDEX resources_org_idx ON public.resources USING btree (organization_id);


--
-- Name: resources_org_provider_type_name_uq; Type: INDEX; Schema: public; Owner: appuser
--

CREATE UNIQUE INDEX resources_org_provider_type_name_uq ON public.resources USING btree (organization_id, provider, type, name);


--
-- Name: resources_provider_idx; Type: INDEX; Schema: public; Owner: appuser
--

CREATE INDEX resources_provider_idx ON public.resources USING btree (provider);


--
-- Name: resources_status_idx; Type: INDEX; Schema: public; Owner: appuser
--

CREATE INDEX resources_status_idx ON public.resources USING btree (status);


--
-- Name: resources_tags_gin_idx; Type: INDEX; Schema: public; Owner: appuser
--

CREATE INDEX resources_tags_gin_idx ON public.resources USING gin (tags);


--
-- Name: users_org_email_lower_uq; Type: INDEX; Schema: public; Owner: appuser
--

CREATE UNIQUE INDEX users_org_email_lower_uq ON public.users USING btree (organization_id, lower(email));


--
-- Name: users_org_idx; Type: INDEX; Schema: public; Owner: appuser
--

CREATE INDEX users_org_idx ON public.users USING btree (organization_id);


--
-- Name: users_role_idx; Type: INDEX; Schema: public; Owner: appuser
--

CREATE INDEX users_role_idx ON public.users USING btree (role);


--
-- Name: resources resources_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: appuser
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT resources_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: users users_organization_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: appuser
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- Name: DATABASE myapp; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON DATABASE myapp TO appuser;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO appuser;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO appuser;


--
-- Name: DEFAULT PRIVILEGES FOR TYPES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TYPES TO appuser;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO appuser;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO appuser;


--
-- PostgreSQL database dump complete
--

\unrestrict OszfBd8NLO09QzDFea7InbeqBcGip5fAa9S4vvcC3tUviSXNSKXK8UY0I5tfNIC

