/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: 20240919@Aries
	Task: Rebate & Retention - Implement Script to Insert Member List  [Redmine: #211046]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240919@Aries: Created [Redmine: #211046]

	Param's Explanation:  					
*/
USE bodb02
GO
DECLARE @ProgramId SMALLINT		= 1
	   ,@WalletId  TINYINT		= 2
	   ,@Creator   INT			= 10278938		

DECLARE @ListCust VARCHAR(MAX) = '[{"c":1, "a":100},{"c":2, "a":100}]'

DROP TABLE IF EXISTS #@tmpCust2k
CREATE TABLE #@tmpCust2k(c INT,a  MONEY)

DROP TABLE IF EXISTS #tmpCust
CREATE TABLE #tmpCust(id INT IDENTITY (1,1) PRIMARY KEY, c INT,a  MONEY)


DECLARE @ParamCust VARCHAR(MAX) = ''
DECLARE  @StartRow	INT 
		,@StopRow	INT 
		,@MaxRow	INT  -- Keep the total row of your data
		,@Threshold INT  -- the number of each batch


INSERT INTO #tmpCust(c,a)
SELECT	c, a
FROM OPENJSON(@ListCust) WITH (
			 c INT		'$.c'
			,a MONEY	'$.a'
) 

DECLARE @SId INT
EXEC [dbo].[NAP_SabaProgramStatus_Ins] @ProgramId = @ProgramId, @IsTest = 1, @SId = @SId OUTPUT

PRINT @SId

DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(id) FROM #tmpCust)
SET @Threshold = 2000

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold


WHILE (@MaxRow IS NOT NULL)
BEGIN
	PRINT @StartRow
	PRINT @StopRow

	SET @ParamCust = (SELECT c,a FROM #tmpCust AS tc WHERE tc.id BETWEEN @StartRow AND @StopRow FOR JSON AUTO)
	EXEC [NAP_SabaWalletTicket_Ins] @SId = @SId,@ProgramId = @ProgramId, @WalletId = @WalletId, @Creator = @Creator,  @ListCust = @ParamCust

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.100' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END

EXEC [NAP_SabaProgramStatus_Upd]  @SId = @SId ,@StatusId = 2