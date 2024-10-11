sqlcmd -S (localdb)\MSSQLLocalDB -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\CriarBD.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\Log_Criacao.txt"
pause
sqlcmd -S (localdb)\MSSQLLocalDB -d Ecommerce -Q "set nocount on; select * from TempCarga" -s ";" -W -w 999 -o "C:\Users\Maresia\Desktop\5SBD\carga.csv"
pause
sqlcmd -S (localdb)\MSSQLLocalDB -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\upload arquivo.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\Log_Upload_CSV.txt"
pause
sqlcmd -S (localdb)\MSSQLLocalDB -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\inserção from temporaria.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\Log_Insert.txt"
pause
sqlcmd -S (localdb)\MSSQLLocalDB -d Ecommerce -E -i "C:\Users\Maresia\Desktop\5SBD\processamento.sql" -o "C:\Users\Maresia\Desktop\5SBD\logs\ProcessarPedidosPendentes.log"
