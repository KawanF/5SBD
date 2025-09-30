USE Ecommerce;
GO

IF OBJECT_ID('GerenciarPedidosClientes', 'P') IS NOT NULL
    DROP PROCEDURE GerenciarPedidosClientes;
GO

CREATE PROCEDURE GerenciarPedidosClientes
AS
BEGIN

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

    SELECT * INTO #PedidosClientesOrdenados
    FROM #RelatorioPedidosClientes
    ORDER BY TotalValor DESC;

    DECLARE @CliID INT, @PedID INT, @QtdNecessaria INT, @QtdEmEstoque INT, @SkuProduto VARCHAR(50), @ProdutoID INT;

    DECLARE cursorClientes CURSOR FOR
    SELECT DISTINCT ClienteID
    FROM #PedidosClientesOrdenados;

    OPEN cursorClientes;
    FETCH NEXT FROM cursorClientes INTO @CliID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE cursorPedidos CURSOR FOR
        SELECT DISTINCT CargaPedidoID
        FROM #PedidosClientesOrdenados
        WHERE ClienteID = @CliID;

        OPEN cursorPedidos;
        FETCH NEXT FROM cursorPedidos INTO @PedID;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @PodeProcessar BIT = 1;
            DECLARE cursorItens CURSOR FOR
            SELECT Quantidade, ProdutoSKU, ProdutoID
            FROM #PedidosClientesOrdenados
            WHERE CargaPedidoID = @PedID;
            
            OPEN cursorItens;
            FETCH NEXT FROM cursorItens INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
            
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT @QtdEmEstoque = Quantidade
                FROM EstoqueInfo
                WHERE ProdutoSKU = @SkuProduto;

                IF @QtdEmEstoque < @QtdNecessaria
                BEGIN
                    SET @PodeProcessar = 0;
                    BREAK;
                END
                FETCH NEXT FROM cursorItens INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
            END
            CLOSE cursorItens;
            DEALLOCATE cursorItens;

            IF @PodeProcessar = 1
            BEGIN
                DECLARE cursorProcess CURSOR FOR
                SELECT Quantidade, ProdutoSKU, ProdutoID
                FROM #PedidosClientesOrdenados
                WHERE CargaPedidoID = @PedID;
                
                OPEN cursorProcess;
                FETCH NEXT FROM cursorProcess INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
                
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    UPDATE EstoqueInfo
                    SET Quantidade = Quantidade - @QtdNecessaria
                    WHERE ProdutoSKU = @SkuProduto;

                    INSERT INTO CompraInfo (PedidoID, ProdutoID, DataCompra, CompraStatus)
                    SELECT @PedID, @ProdutoID, tc.DataCompra, 'Processado'
                    FROM dbo.TempCarga tc
                    WHERE tc.PedidoID = @PedID;

                    FETCH NEXT FROM cursorProcess INTO @QtdNecessaria, @SkuProduto, @ProdutoID;
                END
                CLOSE cursorProcess;
                DEALLOCATE cursorProcess;

                UPDATE PedidoInfo
                SET PedidoStatus = 'Processado'
                WHERE CargaPedidoID = @PedID;

                INSERT INTO AtendimentoInfo (PedidoID, Valor, AtendimentoStatus, DataAtendimento)
                VALUES (@PedID, (SELECT SUM(TotalValor) FROM #PedidosClientesOrdenados WHERE CargaPedidoID = @PedID), 'Processado', GETDATE());
            END
            ELSE
            BEGIN
                UPDATE PedidoInfo
                SET PedidoStatus = 'Pendente'
                WHERE CargaPedidoID = @PedID;

                DECLARE cursorPendente CURSOR FOR
                SELECT ProdutoID
                FROM #PedidosClientesOrdenados
                WHERE CargaPedidoID = @PedID;
                
                OPEN cursorPendente;
                FETCH NEXT FROM cursorPendente INTO @ProdutoID;
                
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

    SELECT * FROM AtendimentoInfo;
END;
GO

EXEC GerenciarPedidosClientes;