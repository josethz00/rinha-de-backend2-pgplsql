create schema api;

set search_path to api;

create role web_anon nologin;

grant usage on schema api to web_anon;

CREATE UNLOGGED TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR (256) NOT NULL,
    limite INTEGER NOT NULL,
    balance INTEGER DEFAULT 0,
    transacoes JSONB DEFAULT '[]'::JSONB
);

CREATE OR REPLACE FUNCTION api.get_extrato_cliente(clienteid INTEGER)
RETURNS TABLE (
    limite INTEGER,
    saldo INTEGER
) AS $$
    BEGIN
        RETURN QUERY
            SELECT
                c.limite,
                c.balance
            FROM
                clientes c
            WHERE
                c.id = clienteid
            LIMIT 1;
    END;
$$ LANGUAGE plpgsql IMMUTABLE;


grant select on api.clientes to web_anon;

DO $$
BEGIN
INSERT INTO clientes (nome, limite)
  VALUES
    ('pablo marcal', 1000 * 100),
    ('primo rico', 800 * 100),
    ('vasco', 10000 * 100),
    ('larissa manoela', 100000 * 100),
    ('juliete', 5000 * 100);
END; $$