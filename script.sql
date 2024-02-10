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
    nome VARCHAR(256) NOT NULL,
    limite INTEGER NOT NULL,
    balance INTEGER DEFAULT 0,
    transacoes JSONB DEFAULT '[]'::JSONB
);


CREATE TYPE TIPO_TRANSACAO_ENUM AS ENUM ('c', 'd');

-- Cria a procedure para buscar o extrato do cliente
CREATE OR REPLACE FUNCTION api.get_extrato_cliente(clienteid INTEGER)
RETURNS TABLE (
    saldo JSONB,
    ultimas_transacoes JSONB
) AS $$

BEGIN
    RETURN QUERY
        SELECT 
            jsonb_agg(
                jsonb_build_object(
                    'total', c.balance,
                    'data_extrato', now()::timestamp,
                    'limite', c.limite
                )
            ),
            c.transacoes
        FROM clientes c
        WHERE c.id = clienteid
        GROUP BY c.transacoes;

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
    saldo_atual INTEGER,
    limite_atual INTEGER
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
                    transacoes = jsonb_insert(
                        transacoes, 
                        '{0}', 
                        jsonb_build_object(
                            'tipo', 'c',
                            'valor', valor,
                            'descricao', descricao,
                            'realizada_em', LOCALTIMESTAMP
                        )
                    )
                WHERE id = clienteid 
                RETURNING balance, limite;
    ELSE
        RETURN QUERY
            UPDATE clientes 
                SET 
                    balance = balance - valor, 
                    transacoes = jsonb_insert(
                        transacoes, 
                        '{0}', 
                        jsonb_build_object(
                            'tipo', 'c',
                            'valor', valor,
                            'descricao', descricao,
                            'realizada_em', LOCALTIMESTAMP
                        )
                    )
                WHERE id = clienteid 
                RETURNING balance, limite;
    END IF;

END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION atualiza_saldo()
    RETURNS TRIGGER AS $$

BEGIN

    IF NEW.balance < (NEW.limite * -1) THEN
        RAISE 
            sqlstate 'PGRST'
            USING message = '{"code":"422","message": "sem saldo"}',
            detail = '{"status":422,"headers":{"X-Powered-By":"josethz00"}}';
    END IF;

    RETURN NEW;

END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER dispara_check_saldo
AFTER UPDATE ON api.clientes
FOR EACH ROW
EXECUTE PROCEDURE atualiza_saldo();

-- Permitir que a role web_anon execute operações de leitura na tabela clientes
GRANT SELECT ON api.clientes TO web_anon;
GRANT UPDATE ON api.clientes TO web_anon;
GRANT INSERT ON api.clientes TO web_anon;

-- Insert de dados iniciais
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
