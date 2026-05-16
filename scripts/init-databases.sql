-- Init script for the reckon-portal stack.
--
-- The postgres image creates the database named by POSTGRES_DB on
-- first boot (reckon_portal_prod by default). The umbrella also has
-- a second app (reckon_martha_projects) that wants its own database;
-- create it here so the Phoenix release boots clean.
--
-- Runs ONCE on a fresh postgres data volume (docker-entrypoint-initdb.d).
-- Subsequent restarts are no-ops; rerun by wiping the volume.

CREATE DATABASE reckon_martha_projects;
