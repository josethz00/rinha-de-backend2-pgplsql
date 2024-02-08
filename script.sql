create schema api;

create role web_anon nologin;

grant usage on schema api to web_anon;

use api;

CREATE UNLOGGED TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR (256) NOT NULL,
    limite INTEGER NOT NULL,
    balance INTEGER DEFAULT 0
);

CREATE UNLOGGED TABLE IF NOT EXISTS transactions (
    id SERIAL PRIMARY KEY,
    value INTEGER NOT NULL,
    type CHAR(1) NOT NULL,
    description VARCHAR(10),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

grant select on api.clientes to web_anon;

DO $$
BEGIN
INSERT INTO users (nome, limite)
  VALUES
    ('pablo marcal', 1000 * 100),
    ('primo rico', 800 * 100),
    ('vasco', 10000 * 100),
    ('larissa manoela', 100000 * 100),
    ('juliete', 5000 * 100);
END; $$