USE Ecommerce; 


-- Inserção Cliente
INSERT INTO ClienteInfo (
    ClienteCodigo, 
    Nome, 
    CPF, 
    Email, 
    Telefone, 
    Endereco1, 
    Endereco2, 
    Endereco3, 
    Cidade, 
    Estado, 
    CEP, 
    Pais, 
    NumeroIOSS
)
SELECT 
    ClienteCodigo,
    CompradorNome,
    CompradorCPF,
    CompradorEmail,
    CompradorTelefone,
    EntregaEndereco1,
    EntregaEndereco2,
    EntregaEndereco3,
    EntregaCidade,
    EntregaEstado,
    EntregaCEP,
    EntregaPais,
    IOSSNumero
FROM (
    SELECT 
        ClienteCodigo,
        CompradorNome,
        CompradorCPF,
        CompradorEmail,
        CompradorTelefone,
        EntregaEndereco1,
        EntregaEndereco2,
        EntregaEndereco3,
        EntregaCidade,
        EntregaEstado,
        EntregaCEP,
        EntregaPais,
        IOSSNumero,
        ROW_NUMBER() OVER (PARTITION BY CompradorCPF ORDER BY PedidoID) AS RowNumber
    FROM TempCarga
) AS TC
WHERE RowNumber = 1
AND NOT EXISTS (
    SELECT 1 
    FROM ClienteInfo AS CL 
    WHERE CL.CPF = TC.CompradorCPF
);

-- PRODUTO
INSERT INTO ProdutoInfo (Nome, Preco, ProdutoSKU)
SELECT DISTINCT 
    ProdutoNome, 
    Preco, 
    ProdutoSKU
FROM (
    SELECT 
        ProdutoNome,
        Preco,
        ProdutoSKU,
        ROW_NUMBER() OVER (PARTITION BY ProdutoSKU ORDER BY ProdutoID) AS RowNumber
    FROM TempCarga
) AS TC
WHERE RowNumber = 1
AND NOT EXISTS (
    SELECT 1
    FROM ProdutoInfo AS PR
    WHERE PR.ProdutoSKU = TC.ProdutoSKU
);

-- Pedido
INSERT INTO PedidoInfo (CargaPedidoID, ClienteID, DataPedido, ServicoEnvio, DestinatarioNome, PedidoStatus, DataPagamento)
SELECT TC.PedidoID, CL.ClienteID, TC.DataCompra, TC.ServicoEnvio, TC.DestinatarioNome, 'Pendente', DataPagamento
FROM TempCarga TC
INNER JOIN ClienteInfo CL ON CL.ClienteCodigo = TC.ClienteCodigo
WHERE NOT EXISTS (
    SELECT 1
    FROM PedidoInfo P
    WHERE P.CargaPedidoID = TC.PedidoID
);

-- Item do pedido
INSERT INTO PedidoItem (PedidoID, ProdutoID, Quantidade, Moeda)
SELECT 
    TC.PedidoID,
    PR.ProdutoID,
    TC.Quantidade,
    TC.Moeda
FROM 
    TempCarga TC
INNER JOIN 
    ProdutoInfo PR ON PR.ProdutoSKU = TC.ProdutoSKU;

-- Estoque
INSERT INTO EstoqueInfo (ProdutoSKU, Quantidade, ProdutoID)
SELECT DISTINCT ProdutoSKU, 0, ProdutoID
FROM ProdutoInfo
WHERE ProdutoSKU NOT IN (SELECT ProdutoSKU FROM EstoqueInfo);