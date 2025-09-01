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
        ROW_NUMBER() OVER (PARTITION BY CompradorEmail ORDER BY PedidoID) AS RowNumber
    FROM TempCarga
) AS TC
WHERE RowNumber = 1
AND NOT EXISTS (
    SELECT 1 
    FROM ClienteInfo AS CL 
    WHERE CL.Email = TC.CompradorEmail
);

-- Produto
INSERT INTO ProdutoInfo (Nome, Preco, SKU)
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
    WHERE PR.SKU = TC.ProdutoSKU
);

-- Pedido
INSERT INTO PedidoInfo (CargaPedidoID, ClienteID, DataPedido, DataPagamento, frete, total, ServicoEnvio, DestinatarioNome, PedidoStatus)
SELECT 
    TC.PedidoID,
    CL.ClienteID,
    TC.DataCompra,
    TC.DataPagamento,
    MAX(TC.Frete) AS frete,
    SUM(TC.Preco * TC.Quantidade) + MAX(TC.Frete) AS total,
    TC.ServicoEnvio,
    TC.DestinatarioNome,
    'Pendente'
FROM TempCarga TC
INNER JOIN ClienteInfo CL ON CL.ClienteCodigo = TC.ClienteCodigo
WHERE NOT EXISTS (
    SELECT 1
    FROM PedidoInfo P
    WHERE P.CargaPedidoID = TC.PedidoID
)
GROUP BY TC.PedidoID, CL.ClienteID, TC.DataCompra, TC.DataPagamento, TC.ServicoEnvio, TC.DestinatarioNome;

-- Item do pedido
INSERT INTO PedidoItem (PedidoID, ProdutoID, Quantidade, Moeda)
SELECT 
    PI.PedidoID,
    PR.ProdutoID,
    TC.Quantidade,
    TC.Moeda
FROM TempCarga TC
INNER JOIN ProdutoInfo PR ON PR.SKU = TC.ProdutoSKU
INNER JOIN PedidoInfo PI ON PI.CargaPedidoID = TC.PedidoID;

-- Estoque
INSERT INTO EstoqueInfo (ProdutoSKU, Quantidade)
SELECT DISTINCT ProdutoSKU, 0
FROM ProdutoInfo
WHERE ProdutoSKU NOT IN (SELECT ProdutoSKU FROM EstoqueInfo)
GROUP BY ProdutoSKU;
