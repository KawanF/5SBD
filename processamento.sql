USE Ecommerce;
GO

-- Excluir a procedure se existir
IF OBJECT_ID('GerenciarPedidosClientes', 'P') IS NOT NULL
    DROP PROCEDURE GerenciarPedidosClientes;
GO

-- Criar a procedure
CREATE PROCEDURE GerenciarPedidosClientes
AS
BEGIN

    -- Criar tabela temporária
    IF OBJECT_ID('tempdb..#RelatorioPedidosClientes') IS NOT NULL
        DROP TABLE #RelatorioPedidosClientes;

    CREATE TABLE #RelatorioPedidosClientes (
        CargaPedidoID INT,
        ProdutoSKU VARCHAR(50), 
        Quantidade INT,
        ClienteID INT,
        PrecoProduto DECIMAL(10, 2),
        TotalValor DECIMAL(10, 2)
    );

    -- Inserir dados na tabela temporária
    INSERT INTO #RelatorioPedidosClientes (CargaPedidoID, ProdutoSKU, Quantidade, ClienteID, PrecoProduto, TotalValor)
    SELECT DISTINCT
        p.CargaPedidoID,
        prod.ProdutoSKU,
        pi.Quantidade,
        p.ClienteID,
        prod.Preco,
        pi.Quantidade * prod.Preco AS TotalValor
    FROM PedidoItem pi
    JOIN PedidoInfo p ON pi.PedidoID = p.PedidoID
    JOIN ProdutoInfo prod ON pi.ProdutoID = prod.ProdutoID;

    -- Ordenar os resultados da tabela pelo TotalValor em ordem decrescente
    SELECT * INTO #PedidosClientesOrdenados
    FROM #RelatorioPedidosClientes
    ORDER BY TotalValor DESC;

    -- Consulta final da tabela temporária agrupada pelo ClienteID
    SELECT ClienteID, SUM(Quantidade) AS QtdTotal, SUM(TotalValor) AS ValorTotal
    INTO #ResumoAtendimento
    FROM #PedidosClientesOrdenados
    GROUP BY ClienteID;

    -- Processar os pedidos
    DECLARE @CliID INT, @PedID INT, @QtdNecessaria INT, @QtdEmEstoque INT, @SkuProduto VARCHAR(50);

    -- Percorrer os resultados da tabela temporária e processar os pedidos
    DECLARE cursorClientes CURSOR FOR
    SELECT ClienteID
    FROM #ResumoAtendimento;

    OPEN cursorClientes;
    FETCH NEXT FROM cursorClientes INTO @CliID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Obter pedidos para o cliente atual
        DECLARE cursorPedidos CURSOR FOR
        SELECT CargaPedidoID
        FROM PedidoInfo
        WHERE ClienteID = @CliID;

        OPEN cursorPedidos;
        FETCH NEXT FROM cursorPedidos INTO @PedID;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Verificar se é possível atender o pedido
            DECLARE @PodeProcessar BIT = 1;
            DECLARE cursorItens CURSOR FOR
            SELECT Quantidade, ProdutoSKU
            FROM #PedidosClientesOrdenados
            WHERE CargaPedidoID = @PedID;
            OPEN cursorItens;
            FETCH NEXT FROM cursorItens INTO @QtdNecessaria, @SkuProduto;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Verificar estoque
                SELECT @QtdEmEstoque = Quantidade
                FROM EstoqueInfo
                WHERE ProdutoSKU = @SkuProduto;

                IF @QtdEmEstoque < @QtdNecessaria
                BEGIN
                    -- Não há estoque suficiente para atender o pedido
                    SET @PodeProcessar = 0;
                    BREAK;
                END

                FETCH NEXT FROM cursorItens INTO @QtdNecessaria, @SkuProduto;
            END
            CLOSE cursorItens;
            DEALLOCATE cursorItens;

            IF @PodeProcessar = 1
            BEGIN
                -- Atender o pedido
                DECLARE @ProdutoID INT;
                SELECT @ProdutoID = ProdutoID FROM PedidoItem WHERE PedidoID = @PedID;

                DECLARE cursorProcess CURSOR FOR
                SELECT Quantidade, ProdutoSKU
                FROM #PedidosClientesOrdenados
                WHERE CargaPedidoID = @PedID;
                OPEN cursorProcess;
                FETCH NEXT FROM cursorProcess INTO @QtdNecessaria, @SkuProduto;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    -- Atualizar estoque
                    UPDATE EstoqueInfo
                    SET Quantidade = Quantidade - @QtdNecessaria
                    WHERE ProdutoSKU = @SkuProduto;

                    FETCH NEXT FROM cursorProcess INTO @QtdNecessaria, @SkuProduto;
                END
                CLOSE cursorProcess;
                DEALLOCATE cursorProcess;

                -- Atualizar status do pedido
                UPDATE PedidoInfo
                SET PedidoStatus = 'Processado'
                WHERE PedidoID = @PedID;

                -- Inserir na tabela CompraInfo com ProdutoID e DataCompra da tabela temporária 
                INSERT INTO CompraInfo (PedidoID, ProdutoID, DataCompra, CompraStatus)
                SELECT @PedID, @ProdutoID, tc.DataCompra, 'Processado'
                FROM dbo.TempCarga tc
                WHERE tc.PedidoID = @PedID;

                -- Inserir na tabela AtendimentoInfo
                INSERT INTO AtendimentoInfo (PedidoID, Valor, AtendimentoStatus, DataAtendimento)
                VALUES (@PedID, (SELECT SUM(TotalValor) FROM #PedidosClientesOrdenados WHERE CargaPedidoID = @PedID), 'Processado', GETDATE());
            END
            ELSE
            BEGIN
                -- Não há estoque suficiente para atender o pedido
                UPDATE PedidoInfo
                SET PedidoStatus = 'Pendente'
                WHERE PedidoID = @PedID;

                -- Inserir na tabela CompraInfo com DataCompra da tabela temporária TempCarga
                INSERT INTO CompraInfo (PedidoID, ProdutoID, DataCompra, CompraStatus)
                SELECT @PedID, @ProdutoID, tc.DataCompra, 'Pendente' 
                FROM dbo.TempCarga tc
                WHERE tc.PedidoID = @PedID;

                -- Inserir na tabela AtendimentoInfo com status "Pendente"
                INSERT INTO AtendimentoInfo (PedidoID, Valor, AtendimentoStatus, DataAtendimento)
                VALUES (@PedID, (SELECT SUM(TotalValor) FROM #PedidosClientesOrdenados WHERE CargaPedidoID = @PedID), 'Pendente', GETDATE());
            END

            FETCH NEXT FROM cursorPedidos INTO @PedID;
        END
        CLOSE cursorPedidos;
        DEALLOCATE cursorPedidos;

        FETCH NEXT FROM cursorClientes INTO @CliID;
    END
    CLOSE cursorClientes;
    DEALLOCATE cursorClientes;

    -- Exibir os resultados para verificação 
    SELECT * FROM AtendimentoInfo;

END;
GO

-- Executar a procedure GerenciarPedidosClientes
EXEC GerenciarPedidosClientes;
