/*
	Created by: 20210322@Louisa: Prevent Update/Delete a large of data manually ( effected > 1000 rows)
	THIS TRIGGER RUN ON LOCAL TEST ENVIRONMENT ONLY

	26 Tables applied:
		bettrans		bettrans14
		bettransg		bettransg14
		BettransInfo	BettransInfo14
		bettransLC		bettransLC14
		bettransm		bettransm14
		bettransRnG		bettransRnG14
		zzzbettrans
		zzzbettransm

		match			match14
		Match3rd		Match3rd14

		ResultDetail		ResultDetail14
		ResultDetail3rd		ResultDetail3rd14
		ResultDetailES		ResultDetailES14
		ResultDetailOS		ResultDetailOS14
*/

--- DB206/bodb02
USE bodb02
GO

----------1. INPUT ---------------------------------------------
declare @table VARCHAR(MAX) = 
'bettrans
,bettrans14
,bettransg		
,bettransg14
,BettransInfo
,BettransInfo14
,bettransLC
,bettransLC14
,bettransm
,bettransm14
,bettransRnG
,bettransRnG14
,zzzbettrans
,zzzbettransm
,match
,match14
,Match3rd
,Match3rd14
,ResultDetail
,ResultDetail14
,ResultDetail3rd
,ResultDetail3rd14
,ResultDetailES
,ResultDetailES14
,ResultDetailOS
,ResultDetailOS14'

--DECLARE @sql_account VARCHAR(MAX) = 
--'spvn\louisa.vo
--,spvn\kaka.huynh
--,spvn\dora.le
--,spvn\megan.dinh
--,spvn\tommy.nguyen
--,spvn\Neil.dao
--,spvn\jane.dinh
--,spvn\harley.nguyen
--,spvn\dory.vu
--,spvn\elio.nguyen'
-------------/ END INPUT -------------------------------------------------------------------------------------

DECLARE @Trigger_UPDATE_DELETE VARCHAR(MAX) = ''

DECLARE @tbl_table TABLE ( table_name VARCHAR(100) )
SELECT @table = REPLACE (REPLACE (REPLACE (@table, CHAR(13), ''), CHAR(10), ''), CHAR(9), '')

INSERT INTO @tbl_table (table_name ) SELECT val FROM dbo.f_SplitString (@table, ',')


SELECT '
/* DB206/bodb02 */
USE bodb02
GO

CREATE	TRIGGER [dbo].[trg_UpdateDelete_'+ t.table_name +'] ON [dbo].['+ t.table_name +']
FOR DELETE, UPDATE	AS

BEGIN
	SET NOCOUNT ON;
		DECLARE @AffectedRows BIGINT = 0
				, @cnt INT			 =  - 1

    SELECT @AffectedRows = COUNT(1) FROM DELETED
	SELECT @cnt =    COUNT(1) FROM [dbo].['+ t.table_name +']  WITH(NOLOCK)

	IF ( @AffectedRows >=  1000 
		AND  SUSER_SNAME() LIKE ''%spvn%''
		AND SUSER_SNAME() NOT LIKE  ''%bodb%'' )
	BEGIN
		RAISERROR(''Please UPDATE/DELETE by batch less than 1000'', 16, 1)
		ROLLBACK
	END

	IF ( @cnt = @AffectedRows )
	BEGIN
		RAISERROR(''Please limit data by WHERE statement'', 16, 1)
		ROLLBACK
	END

END
GO
'
FROM @tbl_table t







