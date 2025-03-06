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

DECLARE @ListCust VARCHAR(MAX) = '[{"c":92501690,"a":100},{"c":92503144,"a":100},{"c":92503636,"a":100},{"c":93000273,"a":100},{"c":93000796,"a":100},{"c":93000908,"a":100},{"c":93000938,"a":100},{"c":93001096,"a":100},{"c":93001105,"a":100},{"c":93004365,"a":100},{"c":93004421,"a":100},{"c":93004477,"a":100},{"c":93004681,"a":100},{"c":93004702,"a":100},{"c":93004858,"a":100},{"c":93004913,"a":100},{"c":93004953,"a":100},{"c":93004985,"a":100},{"c":93005045,"a":100},{"c":93005096,"a":100},{"c":93005167,"a":100},{"c":93005247,"a":100},{"c":93005294,"a":100},{"c":93005316,"a":100},{"c":93005702,"a":100},{"c":93005770,"a":100},{"c":93006741,"a":100},{"c":93007172,"a":100},{"c":93007561,"a":100},{"c":93007712,"a":100},{"c":93007720,"a":100},{"c":93007814,"a":100},{"c":93008057,"a":100},{"c":93009317,"a":100},{"c":93009322,"a":100},{"c":93082490,"a":100},{"c":93082497,"a":100},{"c":93082563,"a":100},{"c":93083144,"a":100},{"c":93083334,"a":100},{"c":93083534,"a":100},{"c":93083573,"a":100},{"c":93083677,"a":100},{"c":93083775,"a":100},{"c":93083813,"a":100},{"c":93083919,"a":100},{"c":93083960,"a":100},{"c":93085629,"a":100},{"c":93085663,"a":100},{"c":93085772,"a":100},{"c":93090638,"a":100},{"c":93090742,"a":100},{"c":93090847,"a":100},{"c":93090938,"a":100},{"c":93090963,"a":100},{"c":93091109,"a":100},{"c":93157627,"a":100},{"c":93157673,"a":100},{"c":93157697,"a":100},{"c":93157799,"a":100},{"c":93157853,"a":100},{"c":94164650,"a":100},{"c":94409754,"a":100},{"c":94411008,"a":100},{"c":94837100,"a":100},{"c":149888795,"a":100},{"c":154748460,"a":100},{"c":154750024,"a":100},{"c":154750146,"a":100},{"c":211382908,"a":100},{"c":211947506,"a":100},{"c":211947510,"a":100},{"c":211947511,"a":100},{"c":211947517,"a":100},{"c":211947520,"a":100},{"c":211947523,"a":100},{"c":211947524,"a":100},{"c":211950178,"a":100},{"c":211950179,"a":100},{"c":211950180,"a":100},{"c":211950182,"a":100},{"c":211950183,"a":100},{"c":211950186,"a":100},{"c":211950189,"a":100},{"c":211952289,"a":100},{"c":211952586,"a":100},{"c":211952597,"a":100},{"c":211952600,"a":100},{"c":211952604,"a":100},{"c":211952606,"a":100},{"c":214493609,"a":100}]'

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