/*
	Created by: 20210322@Louisa: Prevent Update/Delete a large of data manually ( effected > 1000 rows)
	THIS TRIGGER RUN ON LOCAL TEST ENVIRONMENT ONLY
*/

--- DB206/bodb02
USE bodb02
GO

----------1. INPUT ---------------------------------------------

----Apply on 10 tables DB206
declare @table VARCHAR(MAX) = 
'bettrans
,bettransg
,BettransInfo
,bettransLC
,bettransm
,bettransRnG
,match
,ResultDetail
,ResultDetailES
,ResultDetailOS'

-------------/ END INPUT -------------------------------------------------------------------------------------

DECLARE @tbl_table TABLE ( table_name VARCHAR(100) )
SELECT @table = REPLACE (REPLACE (REPLACE (@table, CHAR(13), ''), CHAR(10), ''), CHAR(9), '')

INSERT INTO @tbl_table (table_name ) SELECT val FROM dbo.f_SplitString (@table, ',')


----------2. GERNERATE SCRIPT TRIGER -------------------------------------------------------------------------
SELECT '
/* DB206/bodb02 */
USE bodb02
GO

	CREATE	TRIGGER [dbo].[trg_DML_'+ t.table_name +'_LOCAL] ON [dbo].['+ t.table_name +']
	FOR DELETE, UPDATE, INSERT	AS

	BEGIN
		SET NOCOUNT ON;

		DECLARE  @UpdatedRows BIGINT  = 0
				,@InsertedRows BIGINT = 0
				,@cnt INT			  = - 1
				,@action VARCHAR(1)   = NULL

			
			SELECT @UpdatedRows  = COUNT(1) FROM DELETED
			SELECT @InsertedRows = COUNT(1) FROM INSERTED
			SELECT @cnt			 = COUNT(1) FROM [dbo].['+ t.table_name +']  WITH(NOLOCK)
			SELECT @action		 = CASE WHEN @UpdatedRows  =  @InsertedRows THEN ''U''
										WHEN @UpdatedRows  > 0 THEN ''D''		
										WHEN @InsertedRows > 0 THEN ''I''
										ELSE @action
									END	
		
		IF (@UpdatedRows = 0 AND @InsertedRows = 0)
			RETURN

		IF ( SUSER_SNAME() LIKE ''%spvn%'' 
				OR SUSER_SNAME() LIKE ''dba%'' 
				OR SUSER_SNAME() LIKE ''%dba'' 
				OR SUSER_SNAME() IN (''testteam'',''sputeam'')
			)

		BEGIN			
			IF ( @action IN (''U'',''D'') AND  @UpdatedRows > 1000)
			BEGIN
				RAISERROR(''In LOCAL evironment, please Update/Delete by batch less than or equal to 1000'', 16, 1)
				ROLLBACK
			END

			ELSE IF ( @action IN (''I'') AND @InsertedRows > 500 )
			BEGIN
				RAISERROR(''In LOCAL evironment, please Insert by batch 500'', 16, 1)
				ROLLBACK
			END

			ELSE IF	( @action = ''U'' AND @UpdatedRows = @cnt ) --update all data
					OR (@action =''D'' AND @cnt = 0  ) -- delete all data
			BEGIN
				RAISERROR(''In LOCAL evironment, please limit data by WHERE statement'', 16, 1)
				ROLLBACK
			END

		END
	END
	GO
'
FROM @tbl_table t

----------/END GERNERATE SCRIPT --------------------------------------------------------------------------------






