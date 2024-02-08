-- Create the schema
CREATE SCHEMA api;

-- Set the search path
SET search_path TO api;

-- Create the role
CREATE ROLE web_anon NOLOGIN;

-- Grant usage on the schema to the role
GRANT USAGE ON SCHEMA api TO web_anon;

-- Create the table
CREATE UNLOGGED TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(256) NOT NULL,
    limite INTEGER NOT NULL,
    balance INTEGER DEFAULT 0,
    transacoes JSONB DEFAULT '[]'::JSONB
);

-- Create or replace the function
CREATE OR REPLACE FUNCTION api.get_extrato_cliente(clienteid INTEGER)
RETURNS TABLE (
    limite INTEGER,
    saldo INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.limite, c.balance
    FROM clientes c
    WHERE c.id = clienteid;

    IF NOT FOUND THEN
        RAISE 
            sqlstate 'PGRST'
            USING message = '{"code":"404","message":"Cliente no existe"}', 
            detail = '{"status":404,"headers":{"X-Powered-By":"josethz00"}}';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant permissions
GRANT SELECT ON api.clientes TO web_anon;

-- Insert initial data
DO $$
BEGIN
    INSERT INTO clientes (nome, limite)
    VALUES
    ('pablo marcal', 1000 * 100),
    ('primo rico', 800 * 100),
    ('vasco', 10000 * 100),
    ('larissa manoela', 100000 * 100),
    ('juliete', 5000 * 100);
END; $$;
