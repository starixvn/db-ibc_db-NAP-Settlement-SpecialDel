/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: 20250318@Aries
	Task: Credit Reward - PROD - Give reward to member - 21 Mar 2025  [Redmine: #220594]  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20250318@Aries: Created [Redmine: #220594]

	Param's Explanation:  					
*/
USE bodb02
GO
DECLARE @ProgramId SMALLINT		= 2
	   ,@WalletId  TINYINT		= 2
	   ,@Creator   INT			= 10278938		

DECLARE @ListCust VARCHAR(MAX) = '[{"c":121046273,"a":88},{"c":28850995,"a":88},{"c":160794318,"a":88},{"c":210027855,"a":88},{"c":52220241,"a":88},{"c":196950193,"a":88},{"c":60272949,"a":88},{"c":56353201,"a":88},{"c":201126224,"a":88},{"c":97784023,"a":88},{"c":183663919,"a":88},{"c":92018841,"a":88},{"c":172089306,"a":88},{"c":51639637,"a":88},{"c":114110585,"a":88},{"c":18343465,"a":88},{"c":79717525,"a":88},{"c":72165034,"a":88},{"c":52078174,"a":88},{"c":48932057,"a":88},{"c":128816592,"a":88},{"c":208472800,"a":88},{"c":204235254,"a":88},{"c":76954748,"a":88},{"c":133566774,"a":88},{"c":207392514,"a":88},{"c":207345198,"a":88},{"c":70426796,"a":88},{"c":71028837,"a":88},{"c":32380406,"a":88},{"c":74671872,"a":88},{"c":117261524,"a":88},{"c":42507004,"a":88}]'

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