/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: 20250721@Max
	Task: Credit Reward - PROD - Give reward to member - July 2025 [Redmine: #233023]  
	DB: DBSIC-bodb02
	
	Revisions:
		- 20250721@Max: Created [Redmine: #233023]

	Param's Explanation:  					
*/
USE bodb02
GO
DECLARE @ProgramId SMALLINT		= 2
	   ,@WalletId  TINYINT		= 2
	   ,@Creator   INT			= 10278938		

DECLARE @ListCust VARCHAR(MAX) = '[{"c":52486443,"a":88},{"c":88252406,"a":88},{"c":243797384,"a":88},{"c":245412870,"a":88},{"c":13322366,"a":88},{"c":26491667,"a":88},{"c":2197993,"a":660},{"c":2197981,"a":660},{"c":105826741,"a":320},{"c":245691602,"a":20},{"c":243813593,"a":20},{"c":244739732,"a":20},{"c":117293482,"a":20},{"c":245644407,"a":20},{"c":130092106,"a":20},{"c":245732943,"a":20},{"c":191951505,"a":20},{"c":240208250,"a":20},{"c":187148876,"a":20},{"c":180793562,"a":20},{"c":239676284,"a":20},{"c":241975585,"a":20},{"c":244034070,"a":20},{"c":245303520,"a":20},{"c":152650185,"a":20},{"c":245914896,"a":20},{"c":237689673,"a":20},{"c":245723796,"a":20},{"c":243788962,"a":20},{"c":244220517,"a":20},{"c":236874415,"a":20},{"c":234772946,"a":20},{"c":243800047,"a":20},{"c":219612714,"a":20},{"c":219076633,"a":20},{"c":244127421,"a":20},{"c":245553453,"a":20},{"c":133751496,"a":20}]'

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
SELECT	tbl.c, tbl.a
FROM OPENJSON(@ListCust) WITH (
			 c INT		'$.c'
			,a MONEY	'$.a'
) AS tbl
WHERE EXISTS (
    SELECT TOP 1 1
    FROM [CustDB].[dbo].custInfo AS ci WITH(NOLOCK)
        OUTER APPLY  (SELECT CASE WHEN cps.CloseInfo > 0 THEN 1 ELSE 0 END AS closed
							,CASE WHEN cps.SuspendInfo > 0 THEN 1 ELSE 0 END AS reject
					  FROM [CustDB].dbo.CustProductStatus AS cps  WITH(NOLOCK)
					  WHERE cps.CustID = ci.custid 
					) AS cs
    WHERE ci.custid = tbl.c
        AND ISNULL(cs.Closed,ci.closed) = 0
        AND ISNULL(ISNULL(cs.reject,ci.reject), 0) = 0
)

DECLARE @SId INT
EXEC [dbo].[NAP_SabaProgramStatus_Ins] @ProgramId = @ProgramId, @IsTest = 0, @SId = @SId OUTPUT

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