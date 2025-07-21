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

DECLARE @ListCust VARCHAR(MAX) = '[{"c":245676239,"a":88},{"c":3256056,"a":88},{"c":245676799,"a":88},{"c":52486443,"a":88},{"c":127741436,"a":88},{"c":245673299,"a":88},{"c":232183171,"a":88},{"c":200909548,"a":88},{"c":70430952,"a":88},{"c":245675164,"a":88},{"c":88252406,"a":88},{"c":85917322,"a":88},{"c":243797384,"a":88},{"c":245412870,"a":88},{"c":13322366,"a":88},{"c":25054168,"a":88},{"c":236048492,"a":88},{"c":26491667,"a":88},{"c":2197993,"a":660},{"c":2197981,"a":660},{"c":105826741,"a":320},{"c":106881359,"a":28600},{"c":243979082,"a":20},{"c":245691602,"a":20},{"c":242326316,"a":20},{"c":245709107,"a":20},{"c":243813593,"a":20},{"c":231534818,"a":20},{"c":244739732,"a":20},{"c":240314138,"a":20},{"c":188636508,"a":20},{"c":117293482,"a":20},{"c":243613807,"a":20},{"c":115264451,"a":20},{"c":245644407,"a":20},{"c":195165205,"a":20},{"c":232082691,"a":20},{"c":130092106,"a":20},{"c":234260522,"a":20},{"c":245732943,"a":20},{"c":238655841,"a":20},{"c":191951505,"a":20},{"c":245456820,"a":20},{"c":237128790,"a":20},{"c":240208250,"a":20},{"c":187148876,"a":20},{"c":180793192,"a":20},{"c":180793562,"a":20},{"c":236672087,"a":20},{"c":245670604,"a":20},{"c":242899822,"a":20},{"c":222763712,"a":20},{"c":239676284,"a":20},{"c":243854295,"a":20},{"c":241975585,"a":20},{"c":232173921,"a":20},{"c":244034070,"a":20},{"c":245303520,"a":20},{"c":241314778,"a":20},{"c":152650185,"a":20},{"c":244534813,"a":20},{"c":245914896,"a":20},{"c":236529815,"a":20},{"c":245734204,"a":20},{"c":237689673,"a":20},{"c":245688668,"a":20},{"c":245723796,"a":20},{"c":245699276,"a":20},{"c":243788962,"a":20},{"c":244220517,"a":20},{"c":230604674,"a":20},{"c":236874415,"a":20},{"c":234772946,"a":20},{"c":237700790,"a":20},{"c":243800047,"a":20},{"c":219612714,"a":20},{"c":195188904,"a":20},{"c":219076633,"a":20},{"c":241919481,"a":20},{"c":230750910,"a":20},{"c":244127421,"a":20},{"c":237739621,"a":20},{"c":245066037,"a":20},{"c":245553453,"a":20},{"c":227734673,"a":20},{"c":202594732,"a":20},{"c":194264480,"a":20},{"c":244042023,"a":20},{"c":245310667,"a":20},{"c":239692349,"a":20},{"c":230537931,"a":20},{"c":233517782,"a":20},{"c":133751496,"a":20},{"c":245702045,"a":20},{"c":245697688,"a":20},{"c":240092653,"a":20},{"c":230750836,"a":20},{"c":190658911,"a":20}]'

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