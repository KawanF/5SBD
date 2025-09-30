USE Ecommerce;
GO

-- Remove procedure se existir
IF OBJECT_ID('GerenciarPedidosClientes', 'P') IS NOT NULL
    DROP PROCEDURE GerenciarPedidosClientes;
GO

-- Cria procedure principal
CREATE PROCEDURE GerenciarPedidosClientes
AS
BEGIN

    -- Cria tabela temporária para relatório de pedidos
    IF OBJECT_ID('tempdb..#RelatorioPedidosClientes') IS NOT NULL
        DROP TABLE #RelatorioPedidosClientes;

    CREATE TABLE #RelatorioPedidosClientes (
        CargaPedidoID INT,
        ProdutoSKU VARCHAR(50), 
        Quantidade INT,
        ClienteID INT,
        PrecoProduto DECIMAL(10, 2),
        TotalValor DECIMAL(10, 2),
        ProdutoID INT
    );

    -- Popula tabela temporária com dados consolidados
    INSERT INTO #RelatorioPedidosClientes (CargaPedidoID, ProdutoSKU, Quantidade, ClienteID, PrecoProduto, TotalValor, ProdutoID)
    SELECT DISTINCT
        p.CargaPedidoID,
        prod.ProdutoSKU,
        pi.Quantidade,
        p.ClienteID,
        prod.Preco,
        pi.Quantidade * prod.Preco AS TotalValor,
        prod.ProdutoID
    FROM PedidoItem pi
    JOIN PedidoInfo p ON pi.PedidoID = p.PedidoID
    JOIN ProdutoInfo prod ON pi.ProdutoID = prod.ProdutoID;

    -- Ordena pedidos por valor total (maior primeiro)
    SELECT * INTO #PedidosClientesOrdenados
    FROM #RelatorioPedidosClientes
    ORDER BY TotalValor DESC;

    -- Declara variáveis para processamento
    DECLARE @CliID INT, @PedID INT, @QtdNecessaria INT, @QtdEmEstoque INT, @SkuProduto VARCHAR(50), @ProdutoID INT;

    -- Cursor para percorrer clientes
    DECLARE cursorClientes CURSOR FOR
    SELECT DISTINCT ClienteID
    FROM #PedidosClientesOrdenados;

    OPEN cursorClientes;
    FETCH NEXT FROM cursorClientes INTO @CliID;

    -- Loop principal por cliente
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Cursor para pedidos do cliente atual
        DECLARE cursorPedidos CURSOR FOR
        SELECT DISTINCT CargaPedidoID
        FROM #PedidosClientesOrdenados
        WHERE ClienteID = @CliID;

        OPEN cursorPedidos;
        FETCH NEXT FROM cursorPedidos INTO @PedID;

        -- Processa cada pedido do cliente
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @PodeProcessar BIT = 1;
            
            -- Cursor para verificar itens do pedido
            DECLARE cursorItens CURSOR FOR
            SELECT Quantidade, ProdutoSKU, ProdutoID
            FROM #PedidosClientesOrdenados
            WHERE CargaPedidoID = @PedID;
            
            OPEN cursorItens;
            FETCH NEXT FROM cursorItens INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
            
            -- Verifica estoque para todos os itens
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Obtém quantidade em estoque
                SELECT @QtdEmEstoque = Quantidade
                FROM EstoqueInfo
                WHERE ProdutoSKU = @SkuProduto;

                -- Se estoque insuficiente, marca pedido como não processável
                IF @QtdEmEstoque < @QtdNecessaria
                BEGIN
                    SET @PodeProcessar = 0;
                    BREAK;
                END
                FETCH NEXT FROM cursorItens INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
            END
            CLOSE cursorItens;
            DEALLOCATE cursorItens;

            -- Se pode processar o pedido completo
            IF @PodeProcessar = 1
            BEGIN
                -- Cursor para processar cada item
                DECLARE cursorProcess CURSOR FOR
                SELECT Quantidade, ProdutoSKU, ProdutoID
                FROM #PedidosClientesOrdenados
                WHERE CargaPedidoID = @PedID;
                
                OPEN cursorProcess;
                FETCH NEXT FROM cursorProcess INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
                
                -- Processa cada item: atualiza estoque e registra compra
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    -- Baixa estoque
                    UPDATE EstoqueInfo
                    SET Quantidade = Quantidade - @QtdNecessaria
                    WHERE ProdutoSKU = @SkuProduto;

                    -- Registra compra processada
                    INSERT INTO CompraInfo (PedidoID, ProdutoID, DataCompra, CompraStatus)
                    SELECT @PedID, @ProdutoID, tc.DataCompra, 'Processado'
                    FROM dbo.TempCarga tc
                    WHERE tc.PedidoID = @PedID;

                    FETCH NEXT FROM cursorProcess INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
                END
                CLOSE cursorProcess;
                DEALLOCATE cursorProcess;

                -- Atualiza status do pedido para processado
                UPDATE PedidoInfo
                SET PedidoStatus = 'Processado'
                WHERE CargaPedidoID = @PedID;

                -- Registra atendimento completo
                INSERT INTO AtendimentoInfo (PedidoID, Valor, AtendimentoStatus, DataAtendimento)
                VALUES (@PedID, (SELECT SUM(TotalValor) FROM #PedidosClientesOrdenados WHERE CargaPedidoID = @PedID), 'Processado', GETDATE());
            END
            ELSE
            BEGIN
                -- Pedido não pode ser processado por falta de estoque
                UPDATE PedidoInfo
                SET PedidoStatus = 'Pendente'
                WHERE CargaPedidoID = @PedID;

                -- Cursor para itens pendentes
                DECLARE cursorPendente CURSOR FOR
                SELECT ProdutoID
                FROM #PedidosClientesOrdenados
                WHERE CargaPedidoID = @PedID;
                
                OPEN cursorPendente;
                FETCH NEXT FROM cursorPendente INTO @ProdutoID;
                
                -- Registra compras com status pendente
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    INSERT INTO CompraInfo (PedidoID, ProdutoID, DataCompra, CompraStatus)
                    SELECT @PedID, @ProdutoID, tc.DataCompra, 'Pendente'
                    FROM dbo.TempCarga tc
                    WHERE tc.PedidoID = @PedID;

                    FETCH NEXT FROM cursorPendente INTO @ProdutoID;
                END
                CLOSE cursorPendente;
                DEALLOCATE cursorPendente;

                -- Registra atendimento pendente
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

    -- Retorna resultados finais
    SELECT * FROM AtendimentoInfo;
END;
GO

-- Executa a procedure
EXEC GerenciarPedidosClientes;