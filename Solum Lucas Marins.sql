CREATE DATABASE IF NOT EXISTS solum
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE solum;

-- ---------------------------------------------------------------------
-- USUÁRIOS
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,              -- guardar apenas o HASH (bcrypt/argon2)
    telefone VARCHAR(20),
    tipo_usuario ENUM('AUTONOMO', 'FREELANCER', 'MEI') NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_usuario_nome CHECK (TRIM(nome) <> ''),
    CONSTRAINT chk_usuario_email CHECK (email LIKE '%_@_%._%' AND email NOT LIKE '% %')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- CONTAS
-- ---------------------------------------------------------------------
CREATE TABLE contas (
    id_conta INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    banco VARCHAR(100),
    saldo DECIMAL(12,2) NOT NULL DEFAULT 0.00,   -- mantido pelos triggers de transacoes (não editar direto)
    CONSTRAINT chk_conta_nome CHECK (TRIM(nome) <> ''),
    UNIQUE KEY uq_conta_usuario (id_conta, id_usuario),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- CATEGORIAS
-- ---------------------------------------------------------------------
CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    tipo ENUM('ENTRADA', 'SAIDA') NOT NULL,
    CONSTRAINT chk_categoria_nome CHECK (TRIM(nome) <> ''),
    UNIQUE KEY uq_categoria_nome (id_usuario, nome, tipo),
    UNIQUE KEY uq_categoria_usuario_tipo (id_categoria, id_usuario, tipo),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- TRANSAÇÕES
-- FKs compostas garantem que a conta e a categoria pertencem ao MESMO
-- usuário e que o tipo da transação é igual ao tipo da categoria.
-- O CASCADE aqui só age quando o USUÁRIO inteiro é excluído; exclusão
-- direta de conta/categoria em uso é bloqueada pelos triggers abaixo.
-- ---------------------------------------------------------------------
CREATE TABLE transacoes (
    id_transacao INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_conta INT NOT NULL,
    id_categoria INT NOT NULL,
    descricao VARCHAR(255) NOT NULL,
    valor DECIMAL(12,2) NOT NULL,
    data_transacao DATE NOT NULL,
    tipo ENUM('ENTRADA', 'SAIDA') NOT NULL,
    CONSTRAINT chk_transacao_valor CHECK (valor > 0),
    CONSTRAINT chk_transacao_descricao CHECK (TRIM(descricao) <> ''),
    INDEX idx_transacao_usuario_data (id_usuario, data_transacao),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    FOREIGN KEY (id_conta, id_usuario) REFERENCES contas(id_conta, id_usuario) ON DELETE CASCADE,
    FOREIGN KEY (id_categoria, id_usuario, tipo) REFERENCES categorias(id_categoria, id_usuario, tipo) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- FLUXO DE CAIXA (fechamento mensal)
-- ---------------------------------------------------------------------
CREATE TABLE fluxos_caixa (
    id_fluxo_caixa INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    mes TINYINT UNSIGNED NOT NULL,
    ano SMALLINT UNSIGNED NOT NULL,
    saldo_inicial DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_entradas DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_saidas DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    saldo_final DECIMAL(12,2) AS (saldo_inicial + total_entradas - total_saidas) STORED,
    CONSTRAINT chk_fluxo_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT chk_fluxo_ano CHECK (ano BETWEEN 2000 AND 2100),
    CONSTRAINT chk_fluxo_totais CHECK (total_entradas >= 0 AND total_saidas >= 0),
    UNIQUE KEY uq_fluxo_periodo (id_usuario, mes, ano),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- RETIRADAS MENSAIS (pró-labore)
-- ---------------------------------------------------------------------
CREATE TABLE retiradas_mensais (
    id_retirada INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    valor DECIMAL(12,2) NOT NULL,
    mes TINYINT UNSIGNED NOT NULL,
    ano SMALLINT UNSIGNED NOT NULL,
    status ENUM('PLANEJADA', 'REALIZADA', 'CANCELADA') NOT NULL DEFAULT 'PLANEJADA',
    CONSTRAINT chk_retirada_valor CHECK (valor > 0),
    CONSTRAINT chk_retirada_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT chk_retirada_ano CHECK (ano BETWEEN 2000 AND 2100),
    UNIQUE KEY uq_retirada_periodo (id_usuario, mes, ano),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- RESERVA DE ESTABILIZAÇÃO (uma por usuário)
-- ---------------------------------------------------------------------
CREATE TABLE reservas_estabilizacao (
    id_reserva INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL UNIQUE,
    saldo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    percentual_meta DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    data_atualizacao DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_reserva_saldo CHECK (saldo >= 0),
    CONSTRAINT chk_reserva_percentual CHECK (percentual_meta BETWEEN 0 AND 100),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- MEI - CONFIGURAÇÃO DO TETO ANUAL
-- ---------------------------------------------------------------------
CREATE TABLE configuracoes_mei (
    id_configuracao INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    ano SMALLINT UNSIGNED NOT NULL,
    teto_anual DECIMAL(12,2) NOT NULL,
    percentual_alerta DECIMAL(5,2) NOT NULL DEFAULT 80.00,
    CONSTRAINT chk_mei_ano CHECK (ano BETWEEN 2000 AND 2100),
    CONSTRAINT chk_mei_teto CHECK (teto_anual > 0),
    CONSTRAINT chk_mei_alerta CHECK (percentual_alerta BETWEEN 0 AND 100),
    UNIQUE KEY uq_mei_ano (id_usuario, ano),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- MEI - FATURAMENTOS
-- id_transacao (opcional) evita lançar a mesma receita duas vezes;
-- triggers garantem que a transação é do mesmo usuário e é ENTRADA
-- ---------------------------------------------------------------------
CREATE TABLE faturamentos_mei (
    id_faturamento INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_transacao INT NULL UNIQUE,
    data_faturamento DATE NOT NULL,
    descricao VARCHAR(255),
    valor DECIMAL(12,2) NOT NULL,
    CONSTRAINT chk_faturamento_valor CHECK (valor > 0),
    INDEX idx_faturamento_usuario_data (id_usuario, data_faturamento),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    FOREIGN KEY (id_transacao) REFERENCES transacoes(id_transacao) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- IMPOSTOS
-- ---------------------------------------------------------------------
CREATE TABLE impostos (
    id_imposto INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    percentual DECIMAL(5,2),
    periodicidade ENUM('MENSAL', 'TRIMESTRAL', 'ANUAL', 'OUTRA') NOT NULL DEFAULT 'MENSAL',
    valor_estimado DECIMAL(12,2),
    CONSTRAINT chk_imposto_nome CHECK (TRIM(nome) <> ''),
    CONSTRAINT chk_imposto_percentual CHECK (percentual IS NULL OR percentual BETWEEN 0 AND 100),
    CONSTRAINT chk_imposto_valor CHECK (valor_estimado IS NULL OR valor_estimado >= 0),
    UNIQUE KEY uq_imposto_usuario (id_imposto, id_usuario),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- RESERVAS DE IMPOSTO
-- FK composta garante que o imposto é do mesmo usuário
-- ---------------------------------------------------------------------
CREATE TABLE reservas_imposto (
    id_reserva_imposto INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_imposto INT NOT NULL,
    valor_reservado DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    percentual_reserva DECIMAL(5,2),
    data_atualizacao DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status ENUM('ATIVA', 'UTILIZADA', 'FINALIZADA') NOT NULL DEFAULT 'ATIVA',
    CONSTRAINT chk_resimp_valor CHECK (valor_reservado >= 0),
    CONSTRAINT chk_resimp_percentual CHECK (percentual_reserva IS NULL OR percentual_reserva BETWEEN 0 AND 100),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    FOREIGN KEY (id_imposto, id_usuario) REFERENCES impostos(id_imposto, id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- OBRIGAÇÕES (guias / vencimentos de imposto)
-- PAGO  <=>  data_pagamento preenchida (nos dois sentidos)
-- ---------------------------------------------------------------------
CREATE TABLE obrigacoes_imposto (
    id_obrigacao INT AUTO_INCREMENT PRIMARY KEY,
    id_imposto INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    descricao VARCHAR(255),
    data_vencimento DATE NOT NULL,
    valor DECIMAL(12,2),
    data_pagamento DATE NULL,
    status ENUM('PENDENTE', 'PAGO', 'ATRASADO') NOT NULL DEFAULT 'PENDENTE',
    CONSTRAINT chk_obrigacao_nome CHECK (TRIM(nome) <> ''),
    CONSTRAINT chk_obrigacao_valor CHECK (valor IS NULL OR valor >= 0),
    CONSTRAINT chk_obrigacao_pago CHECK ((status = 'PAGO') = (data_pagamento IS NOT NULL)),
    INDEX idx_obrigacao_vencimento (data_vencimento, status),
    FOREIGN KEY (id_imposto) REFERENCES impostos(id_imposto) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- SERVIÇOS
-- ---------------------------------------------------------------------
CREATE TABLE servicos (
    id_servico INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    horas_trabalho DECIMAL(8,2),
    valor_hora DECIMAL(12,2),
    custo_materiais DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    outros_custos DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_servico_nome CHECK (TRIM(nome) <> ''),
    CONSTRAINT chk_servico_horas CHECK (horas_trabalho IS NULL OR horas_trabalho >= 0),
    CONSTRAINT chk_servico_valor_hora CHECK (valor_hora IS NULL OR valor_hora >= 0),
    CONSTRAINT chk_servico_custos CHECK (custo_materiais >= 0 AND outros_custos >= 0),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- PRECIFICAÇÕES (histórico de cálculos por serviço)
-- ---------------------------------------------------------------------
CREATE TABLE precificacoes (
    id_precificacao INT AUTO_INCREMENT PRIMARY KEY,
    id_servico INT NOT NULL,
    margem_lucro DECIMAL(5,2),
    valor_custo DECIMAL(12,2),
    valor_sugerido DECIMAL(12,2),
    data_calculo DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_prec_margem CHECK (margem_lucro IS NULL OR margem_lucro >= 0),
    CONSTRAINT chk_prec_valores CHECK ((valor_custo IS NULL OR valor_custo >= 0)
                                   AND (valor_sugerido IS NULL OR valor_sugerido >= 0)),
    CONSTRAINT chk_prec_sugerido_custo CHECK (valor_custo IS NULL OR valor_sugerido IS NULL
                                              OR valor_sugerido >= valor_custo),
    FOREIGN KEY (id_servico) REFERENCES servicos(id_servico) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- CARTEIRAS DE INVESTIMENTO
-- saldo_total e rentabilidade_total são mantidos pelos triggers de investimentos
-- ---------------------------------------------------------------------
CREATE TABLE carteiras_investimentos (
    id_carteira INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nome VARCHAR(100) NOT NULL DEFAULT 'Carteira principal',
    saldo_total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    rentabilidade_total DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_carteira_nome CHECK (TRIM(nome) <> ''),
    UNIQUE KEY uq_carteira_nome (id_usuario, nome),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- INVESTIMENTOS
-- rentabilidade (%) agora é calculada automaticamente
-- ---------------------------------------------------------------------
CREATE TABLE investimentos (
    id_investimento INT AUTO_INCREMENT PRIMARY KEY,
    id_carteira INT NOT NULL,
    nome VARCHAR(150) NOT NULL,
    tipo ENUM('RENDA_FIXA', 'RENDA_VARIAVEL', 'FUNDOS', 'TESOURO', 'OUTROS') NOT NULL,
    valor_investido DECIMAL(12,2) NOT NULL,
    valor_atual DECIMAL(12,2),
    rentabilidade DECIMAL(8,2) AS (ROUND((valor_atual - valor_investido) / valor_investido * 100, 2)) STORED,
    data_aplicacao DATE,
    data_vencimento DATE NULL,
    CONSTRAINT chk_inv_nome CHECK (TRIM(nome) <> ''),
    CONSTRAINT chk_inv_valor CHECK (valor_investido > 0),
    CONSTRAINT chk_inv_atual CHECK (valor_atual IS NULL OR valor_atual >= 0),
    CONSTRAINT chk_inv_datas CHECK (data_vencimento IS NULL OR data_aplicacao IS NULL
                                    OR data_vencimento >= data_aplicacao),
    FOREIGN KEY (id_carteira) REFERENCES carteiras_investimentos(id_carteira) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- PROPOSTAS DE INVESTIMENTO
-- ---------------------------------------------------------------------
CREATE TABLE propostas_investimento (
    id_proposta INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    valor_sugerido DECIMAL(12,2),
    risco ENUM('BAIXO', 'MEDIO', 'ALTO'),
    prazo_meses SMALLINT UNSIGNED,
    rentabilidade_estimada DECIMAL(8,2),
    status ENUM('DISPONIVEL', 'ACEITA', 'RECUSADA') NOT NULL DEFAULT 'DISPONIVEL',
    data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_prop_nome CHECK (TRIM(nome) <> ''),
    CONSTRAINT chk_prop_valor CHECK (valor_sugerido IS NULL OR valor_sugerido > 0),
    CONSTRAINT chk_prop_prazo CHECK (prazo_meses IS NULL OR prazo_meses > 0),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- METAS FINANCEIRAS
-- ---------------------------------------------------------------------
CREATE TABLE metas_financeiras (
    id_meta INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario INT NOT NULL,
    nome VARCHAR(150) NOT NULL,
    descricao TEXT,
    valor_objetivo DECIMAL(12,2) NOT NULL,
    valor_atual DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    prazo DATE,
    status ENUM('ATIVA', 'CONCLUIDA', 'CANCELADA') NOT NULL DEFAULT 'ATIVA',
    CONSTRAINT chk_meta_nome CHECK (TRIM(nome) <> ''),
    CONSTRAINT chk_meta_objetivo CHECK (valor_objetivo > 0),
    CONSTRAINT chk_meta_atual CHECK (valor_atual >= 0),
    CONSTRAINT chk_meta_concluida CHECK (status <> 'CONCLUIDA' OR valor_atual >= valor_objetivo),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- TRIGGERS
-- Observação: no MySQL/MariaDB, triggers NÃO disparam em exclusões feitas
-- por CASCADE. Por isso a exclusão do usuário inteiro funciona, enquanto
-- a exclusão direta de conta/categoria em uso é bloqueada.
-- =====================================================================
DELIMITER $$

-- ---------- Saldo das contas ----------
CREATE TRIGGER trg_transacoes_ai AFTER INSERT ON transacoes
FOR EACH ROW
BEGIN
    UPDATE contas
       SET saldo = saldo + IF(NEW.tipo = 'ENTRADA', NEW.valor, -NEW.valor)
     WHERE id_conta = NEW.id_conta;
END$$

CREATE TRIGGER trg_transacoes_bu BEFORE UPDATE ON transacoes
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM faturamentos_mei WHERE id_transacao = OLD.id_transacao)
       AND (NEW.tipo <> 'ENTRADA' OR NEW.id_usuario <> OLD.id_usuario) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Transação vinculada a faturamento MEI precisa continuar ENTRADA do mesmo usuário.';
    END IF;
END$$

CREATE TRIGGER trg_transacoes_au AFTER UPDATE ON transacoes
FOR EACH ROW
BEGIN
    UPDATE contas
       SET saldo = saldo
                 - IF(id_conta = OLD.id_conta, IF(OLD.tipo = 'ENTRADA', OLD.valor, -OLD.valor), 0)
                 + IF(id_conta = NEW.id_conta, IF(NEW.tipo = 'ENTRADA', NEW.valor, -NEW.valor), 0)
     WHERE id_conta IN (OLD.id_conta, NEW.id_conta);
END$$

CREATE TRIGGER trg_transacoes_ad AFTER DELETE ON transacoes
FOR EACH ROW
BEGIN
    UPDATE contas
       SET saldo = saldo - IF(OLD.tipo = 'ENTRADA', OLD.valor, -OLD.valor)
     WHERE id_conta = OLD.id_conta;
END$$

-- ---------- Proteção do histórico ----------
CREATE TRIGGER trg_contas_bd BEFORE DELETE ON contas
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM transacoes WHERE id_conta = OLD.id_conta) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Não é possível excluir uma conta que possui transações.';
    END IF;
END$$

CREATE TRIGGER trg_categorias_bd BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM transacoes WHERE id_categoria = OLD.id_categoria) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Não é possível excluir uma categoria que possui transações.';
    END IF;
END$$

-- ---------- Faturamento MEI coerente com a transação ----------
CREATE TRIGGER trg_faturamentos_bi BEFORE INSERT ON faturamentos_mei
FOR EACH ROW
BEGIN
    IF NEW.id_transacao IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM transacoes
         WHERE id_transacao = NEW.id_transacao
           AND id_usuario = NEW.id_usuario
           AND tipo = 'ENTRADA') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A transação vinculada deve ser uma ENTRADA do mesmo usuário.';
    END IF;
END$$

CREATE TRIGGER trg_faturamentos_bu BEFORE UPDATE ON faturamentos_mei
FOR EACH ROW
BEGIN
    IF NEW.id_transacao IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM transacoes
         WHERE id_transacao = NEW.id_transacao
           AND id_usuario = NEW.id_usuario
           AND tipo = 'ENTRADA') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A transação vinculada deve ser uma ENTRADA do mesmo usuário.';
    END IF;
END$$

-- ---------- Totais da carteira de investimentos ----------
CREATE TRIGGER trg_investimentos_ai AFTER INSERT ON investimentos
FOR EACH ROW
BEGIN
    UPDATE carteiras_investimentos c
       SET c.saldo_total = (SELECT COALESCE(SUM(COALESCE(i.valor_atual, i.valor_investido)), 0)
                              FROM investimentos i WHERE i.id_carteira = c.id_carteira),
           c.rentabilidade_total = (SELECT COALESCE(ROUND((SUM(COALESCE(i.valor_atual, i.valor_investido))
                                                         - SUM(i.valor_investido))
                                                         / NULLIF(SUM(i.valor_investido), 0) * 100, 2), 0)
                                      FROM investimentos i WHERE i.id_carteira = c.id_carteira)
     WHERE c.id_carteira = NEW.id_carteira;
END$$

CREATE TRIGGER trg_investimentos_au AFTER UPDATE ON investimentos
FOR EACH ROW
BEGIN
    UPDATE carteiras_investimentos c
       SET c.saldo_total = (SELECT COALESCE(SUM(COALESCE(i.valor_atual, i.valor_investido)), 0)
                              FROM investimentos i WHERE i.id_carteira = c.id_carteira),
           c.rentabilidade_total = (SELECT COALESCE(ROUND((SUM(COALESCE(i.valor_atual, i.valor_investido))
                                                         - SUM(i.valor_investido))
                                                         / NULLIF(SUM(i.valor_investido), 0) * 100, 2), 0)
                                      FROM investimentos i WHERE i.id_carteira = c.id_carteira)
     WHERE c.id_carteira IN (OLD.id_carteira, NEW.id_carteira);
END$$

CREATE TRIGGER trg_investimentos_ad AFTER DELETE ON investimentos
FOR EACH ROW
BEGIN
    UPDATE carteiras_investimentos c
       SET c.saldo_total = (SELECT COALESCE(SUM(COALESCE(i.valor_atual, i.valor_investido)), 0)
                              FROM investimentos i WHERE i.id_carteira = c.id_carteira),
           c.rentabilidade_total = (SELECT COALESCE(ROUND((SUM(COALESCE(i.valor_atual, i.valor_investido))
                                                         - SUM(i.valor_investido))
                                                         / NULLIF(SUM(i.valor_investido), 0) * 100, 2), 0)
                                      FROM investimentos i WHERE i.id_carteira = c.id_carteira)
     WHERE c.id_carteira = OLD.id_carteira;
END$$

DELIMITER ;

-- =====================================================================
-- VIEW: situação real das obrigações (ATRASADO calculado pela data de hoje)
-- =====================================================================
CREATE VIEW vw_obrigacoes_situacao AS
SELECT o.*,
       i.id_usuario,
       CASE
           WHEN o.status = 'PAGO' THEN 'PAGO'
           WHEN o.data_vencimento < CURRENT_DATE THEN 'ATRASADO'
           ELSE 'PENDENTE'
       END AS situacao_atual
  FROM obrigacoes_imposto o
  JOIN impostos i ON i.id_imposto = o.id_imposto;