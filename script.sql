-- Cria o schema
CREATE SCHEMA api;

-- Seta o schema criado como padrão
SET search_path TO api;

-- Cria a role a ser usada por usuários anônimos (API requests)
CREATE ROLE web_anon NOLOGIN;

-- Dá permissão para a role acessar o schema
GRANT USAGE ON SCHEMA api TO web_anon;

-- Cria a tabela
CREATE UNLOGGED TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    "name" VARCHAR(256) NOT NULL,
    "limit" INTEGER NOT NULL,
    balance INTEGER DEFAULT 0,
    transactions JSON DEFAULT '[]'::JSONB
);


CREATE TYPE TIPO_TRANSACAO_ENUM AS ENUM ('c', 'd');

-- Cria a procedure para buscar o extrato do cliente
CREATE OR REPLACE FUNCTION api.get_extrato_cliente(clienteid INTEGER)
RETURNS TABLE (
    saldo JSON,
    ultimas_transacoes JSON
) AS $$

BEGIN
    RETURN QUERY
        SELECT 
            json_build_object(
                'total', c.balance,
                'data_extrato', now()::timestamp,
                'limite', c."limit"
            ) AS saldo,
            COALESCE(json_agg(
                json_build_object(
                    'valor', (t->>'valor')::INTEGER,
                    'tipo', t->>'tipo',
                    'descricao', t->>'descricao',
                    'realizada_em', t->>'realizada_em'
                )
            ) FILTER (WHERE t IS NOT NULL), '[]'::json) AS ultimas_transacoes
        FROM clientes c
        LEFT JOIN jsonb_array_elements(c.transactions::jsonb) t ON true
        WHERE c.id = clienteid
        GROUP BY c.balance, c."limit";

        IF NOT FOUND THEN
            RAISE 
                sqlstate 'PGRST'
                USING message = '{"code":"404","message":"Cliente no existe"}', 
                detail = '{"status":404,"headers":{"X-Powered-By":"josethz00"}}';
        END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Cria a procedure para realizar uma transação
CREATE OR REPLACE FUNCTION api.realizar_transacao(clienteid INTEGER, valor INTEGER, tipo TIPO_TRANSACAO_ENUM, descricao VARCHAR(10))
RETURNS TABLE (
    limite INTEGER,
    saldo INTEGER
) AS $$

BEGIN

    IF (
            length(descricao) > 10 
                OR 
            descricao IS NULL
                OR
            descricao = ''
        ) 
    THEN
        RAISE 
            sqlstate 'PGRST'
            USING message = '{"code":"400","message":"descricao é obrigatória e deve ser <= 10" }',
            detail = '{"status":400,"headers":{"X-Powered-By":"josethz00"}}';
    END IF;
    
    if tipo = 'c' THEN
        RETURN QUERY
            UPDATE clientes 
                SET 
                    balance = balance + valor, 
                    transactions = jsonb_insert(transactions::jsonb, '{0}', json_build_object(
                        'valor', valor,
                        'tipo', tipo,
                        'descricao', descricao,
                        'realizada_em', LOCALTIMESTAMP
                    )::jsonb)::json
                WHERE id = clienteid 
                RETURNING balance, "limit";

                -- verifcar se o resultado é vazio (0 linhas) no caso de o update ter sido contra um cliente que não existe
        IF NOT FOUND THEN
            RAISE 
                sqlstate 'PGRST'
                USING message = '{"code":"404","message":"Cliente no existe"}', 
                detail = '{"status":404,"headers":{"X-Powered-By":"josethz00"}}';
        END IF;

    ELSE
        RETURN QUERY
            UPDATE clientes 
                SET 
                    balance = balance - valor, 
                    transactions = jsonb_insert(transactions::jsonb, '{0}', json_build_object(
                        'valor', valor,
                        'tipo', tipo,
                        'descricao', descricao,
                        'realizada_em', LOCALTIMESTAMP
                    )::jsonb)::json
                WHERE id = clienteid 
                RETURNING balance, "limit";

        -- verifcar se o resultado é vazio (0 linhas) no caso de o update ter sido contra um cliente que não existe
        IF NOT FOUND THEN
            RAISE 
                sqlstate 'PGRST'
                USING message = '{"code":"404","message":"Cliente no existe"}', 
                detail = '{"status":404,"headers":{"X-Powered-By":"josethz00"}}';
        END IF;


    END IF;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION atualiza_saldo()
    RETURNS TRIGGER AS $$

BEGIN

    IF NEW.balance < (NEW."limit" * -1) THEN
        RAISE sqlstate 'PGRST' USING
            message = '{"code":"422","message":"sem dinhero"}',
            detail = '{"status":422,"headers":{"X-Powered-By":"josethz00"}}';
    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER dispara_check_saldo
BEFORE UPDATE ON api.clientes
FOR EACH ROW
EXECUTE PROCEDURE atualiza_saldo();

-- Permitir que a role web_anon execute operações de leitura na tabela clientes
GRANT SELECT ON api.clientes TO web_anon;
GRANT UPDATE ON api.clientes TO web_anon;
GRANT INSERT ON api.clientes TO web_anon;

-- Insert de dados iniciais
DO $$
BEGIN
    INSERT INTO clientes ("name", "limit")
    VALUES
    ('pablo marcal', 1000 * 100),
    ('primo rico', 800 * 100),
    ('vasco', 10000 * 100),
    ('larissa manoela', 100000 * 100),
    ('juliete', 5000 * 100);
END; $$;
