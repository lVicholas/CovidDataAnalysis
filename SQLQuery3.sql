DECLARE @test NVARCHAR(MAX)='';
DECLARE @sql NVARCHAR(MAX)='';

SELECT @test += 'SUM' + QUOTENAME(COLUMN_NAME,')') + ' ,'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG='CovidProject'
	AND TABLE_NAME='cases_deaths'
	AND COLUMN_NAME LIKE '%total%'
	OR COLUMN_NAME='population';

SET @test=LEFT(@test, LEN(@test)-1);

SET @sql = 'SELECT continent, '+@test+' FROM cases_deaths GROUP BY continent;';
PRINT @sql;
EXEC sp_executesql @sql;
GO