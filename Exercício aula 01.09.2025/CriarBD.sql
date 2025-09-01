USE 5SBD; 

-- Tabela temporária
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TempCarga]') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.TempCarga (
        ProdutoID INT PRIMARY KEY,
        PedidoID INT,
        ItemID INT,
        ClienteCodigo VARCHAR(6),
        DataCompra DATE,
        DataPagamento DATE,
        CompradorEmail VARCHAR(255),
        CompradorNome VARCHAR(255),
        CompradorCPF VARCHAR(14),
        CompradorTelefone VARCHAR(20),
        ProdutoSKU VARCHAR(50),
        ProdutoNome VARCHAR(255),
        Quantidade INT,
        Moeda VARCHAR(3),
        Preco DECIMAL(10, 2),
        ServicoEnvio VARCHAR(50),
        DestinatarioNome VARCHAR(255),
        EntregaEndereco1 VARCHAR(255),
        EntregaEndereco2 VARCHAR(255),
        EntregaEndereco3 VARCHAR(255),
        EntregaCidade VARCHAR(100),
        EntregaEstado VARCHAR(100),
        EntregaCEP VARCHAR(20),
        EntregaPais VARCHAR(100),
        IOSSNumero VARCHAR(20),
        Frete DECIMAL(10,2)
    );
END;

-- Cliente
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ClienteInfo]') AND type in (N'U'))
BEGIN
    CREATE TABLE ClienteInfo (
        ClienteID INT PRIMARY KEY IDENTITY,
        ClienteCodigo VARCHAR(6), 
        Nome VARCHAR(255),
        CPF VARCHAR(14),
        Email VARCHAR(255),
        Telefone VARCHAR(20),
        Endereco1 VARCHAR(255),
        Endereco2 VARCHAR(255),
        Endereco3 VARCHAR(255),
        Cidade VARCHAR(100),
        Estado VARCHAR(100),
        CEP VARCHAR(20),
        Pais VARCHAR(100),
        NumeroIOSS VARCHAR(20)
    );
END;

-- Pedido com total e frete
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PedidoInfo]') AND type in (N'U'))
BEGIN
    CREATE TABLE PedidoInfo (
        PedidoID INT IDENTITY(1,1) PRIMARY KEY,
        CargaPedidoID INT,
        ClienteID INT,
        DataPedido DATE,
        DataPagamento DATE,
        total DECIMAL(10,2),
        frete DECIMAL(10,2),
        ServicoEnvio VARCHAR(50),
        DestinatarioNome VARCHAR(255),
        PedidoStatus VARCHAR(50),
        FOREIGN KEY (ClienteID) REFERENCES ClienteInfo(ClienteID)
    );
END;

-- Produto
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProdutoInfo]') AND type in (N'U'))
BEGIN
    CREATE TABLE ProdutoInfo (
        ProdutoID INT IDENTITY(1,1) PRIMARY KEY,
        Nome VARCHAR(255),
        SKU VARCHAR(50) UNIQUE,
        Preco DECIMAL(10,2)
    );
END;

-- Item do pedido
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PedidoItem]') AND type in (N'U'))
BEGIN
    CREATE TABLE PedidoItem (
        ItemID INT PRIMARY KEY IDENTITY,
        PedidoID INT,
        ProdutoID INT,
        Quantidade INT,
        Moeda VARCHAR(3),
        FOREIGN KEY (PedidoID) REFERENCES PedidoInfo(PedidoID),
        FOREIGN KEY (ProdutoID) REFERENCES ProdutoInfo(ProdutoID)
    );
END;

-- Estoque
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EstoqueInfo]') AND type in (N'U'))
BEGIN
    CREATE TABLE EstoqueInfo (
        EstoqueID INT IDENTITY(1,1) PRIMARY KEY,
        ProdutoSKU VARCHAR(50),
        Quantidade INT,
        FOREIGN KEY (ProdutoSKU) REFERENCES ProdutoInfo(SKU)
    );
END;

-- Atendimento
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AtendimentoInfo]') AND type in (N'U'))
BEGIN
    CREATE TABLE AtendimentoInfo (
        AtendimentoID INT PRIMARY KEY IDENTITY,
        PedidoID INT,
        Valor DECIMAL(10, 2),
        AtendimentoStatus VARCHAR(50),
        DataAtendimento DATE,
        FOREIGN KEY (PedidoID) REFERENCES PedidoInfo(PedidoID)
    );
END;

-- Compra
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CompraInfo]') AND type in (N'U'))
BEGIN
    CREATE TABLE CompraInfo (
        CompraID INT PRIMARY KEY IDENTITY,
        PedidoID INT,
        ProdutoID INT,
        DataCompra DATE,
        CompraStatus VARCHAR(50),
        FOREIGN KEY (PedidoID) REFERENCES PedidoInfo(PedidoID),
        FOREIGN KEY (ProdutoID) REFERENCES ProdutoInfo(ProdutoID)
    );
END;
