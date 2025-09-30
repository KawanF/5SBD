@echo off
echo Iniciando ETL do Ecommerce...
echo.

echo [1/5] Criando banco de dados...
sqlcmd -S DESKTOP-G969SDI -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\CriarBD.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\Log_Criacao.txt"
if %errorlevel% neq 0 (
    echo ERRO na criacao do banco!
    pause
    exit /b %errorlevel%
)
echo Concluido!
echo.

echo [2/5] Fazendo upload do CSV...
sqlcmd -S DESKTOP-G969SDI -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\upload arquivo.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\Log_Upload_CSV.txt"
if %errorlevel% neq 0 (
    echo ERRO no upload!
    pause
    exit /b %errorlevel%
)
echo Concluido!
echo.

echo [3/5] Inserindo dados das tabelas temporarias...
sqlcmd -S DESKTOP-G969SDI -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\inserção from temporaria.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\Log_Insert.txt"
if %errorlevel% neq 0 (
    echo ERRO na insercao!
    pause
    exit /b %errorlevel%
)
echo Concluido!
echo.

echo [4/5] Adicionando estoque inicial...
sqlcmd -S DESKTOP-G969SDI -d Ecommerce -E -Q "UPDATE EstoqueInfo SET Quantidade = Quantidade + 10 WHERE EstoqueID IN (1, 2);" -o "C:\Users\Maresia\Desktop\5SBD\logs\Log_Estoque.txt"
if %errorlevel% neq 0 (
    echo ERRO ao adicionar estoque!
    pause
    exit /b %errorlevel%
)
echo Concluido!
echo.

echo [5/5] Processando pedidos...
sqlcmd -S DESKTOP-G969SDI -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\processamento.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\ProcessarPedidosPendentes.log"
if %errorlevel% neq 0 (
    echo ERRO no processamento!
    pause
    exit /b %errorlevel%
)
echo Concluido!
echo.

echo ========================================
echo ETL concluido com sucesso!
echo ========================================
pause