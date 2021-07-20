CREATE OR ALTER FUNCTION getTotalsForRegion (
	@region_name NVARCHAR(255), 
	@totals_table_name NVARCHAR(255)
)
RETURNS FLOAT AS
	BEGIN

	IF COL_LENGTH(@totals_table_name, 'continent') IS NOT NULL
		BEGIN
			PRINT 'Invalid input to getTotalsForRegion'
			RETURN NULL;
		END

	DECLARE @column_sums NVARCHAR(MAX)='';
	DECLARE @sql NVARCHAR(MAX)='';
	DECLARE @world_condition NVARCHAR(MAX)='';

	SELECT @column_sums += ('SUM'+QUOTENAME(COLUMN_NAME,')')+', ')
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_CATALOG='CovidProject'
	AND TABLE_NAME=@totals_table_name
	AND (DATA_TYPE='FLOAT' OR COLUMN_NAME='continent');	

	IF @region_name='World'
	BEGIN
		SET @world_condition='WHERE @table_name.continent IS NOT NULL';
	END

	SET @sql='SELECT '+@column_sums+' FROM '+@totals_table_name+' '+
	    @world_condition+'GROUP BY continent';


END;