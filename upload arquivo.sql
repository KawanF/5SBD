BULK INSERT dbo.TempCarga
FROM 'C:\Users\Maresia\Desktop\5SBD\carga.csv'
WITH (
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2
);
