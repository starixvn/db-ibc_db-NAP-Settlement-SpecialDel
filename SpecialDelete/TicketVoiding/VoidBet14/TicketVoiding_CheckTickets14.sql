/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CheckTickets14]
(
	 @TransIds	VARCHAR(MAX) = NULL
)
AS
/*  
	Created by: July
	Date: 20211123
	Task: TVS - Void Archived Tickets
	DB: DBTXN/bodb02   

	Revisions:  
		- 20211123@July: Create new SP [Redmine: #140180]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds			 VARCHAR(MAX) = ''
			,@IsExistSingle				 BIT = 0
			,@IsExistParlay				 BIT = 0
			,@IsExistFM					 BIT = 0
			,@IsExistFM2				 BIT = 0
			,@MatchProcessXML			 XML = NULL
			,@MatchParlayProcessXML	     XML = NULL
			,@TotalRefnoParlay		     INT = 0
			,@ThreadHold			     INT = 0 -- over threadhold, the parlay process will be locked in systemsetting	

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblMatchParlay AS TABLE (MatchId INT, RefNo BIGINT)
					
	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	CREATE TABLE #validTransId (
		transid		BIGINT PRIMARY KEY
		,StatusId	INT
		,bettype	SMALLINT
		,custId		INT
		,matchid	INT
		,betfrom	NVARCHAR(1)
		,refno		BIGINT
		)

	IF (@TransIds IS NULL
		OR LEN(@TransIds) = 0
			) RETURN;

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,StatusId
		,bettype
		,custId
		,matchid
		,betfrom
		,refno
		)
	SELECT b14.transid
		,statusID
		,bettype
		,custid
		,matchid
		,betfrom
		,refno
	FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
		INNER JOIN #transIdTemp tmp ON b14.transid = tmp.transid
	
	--final valid transid
	DELETE t
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE StatusId IN (101, 102, 103)
		OR bt.bettype IS NULL
		OR t.betfrom ='p'
		
	-- invalid transId
	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM #validTransId WHERE transid = t.transid)
										FOR XML PATH('')), 1, 1, ''), '')

	---Prepare for lock match---
	SELECT @IsExistSingle	= MAX(CASE WHEN t.Bettype NOT IN (9, 29, 2799, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
		  ,@IsExistFM		= MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
		  ,@IsExistFM2		= MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
		  ,@IsExistParlay	= MAX(CASE WHEN t.Bettype IN (9, 29, 2799) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
	FROM #validTransId AS t
		OUTER APPLY (
				SELECT GroupId
				FROM dbo.f_TVS_CheckingProcessGroupBettypes()
				WHERE Bettype = t.Bettype
		)f
	
	SET @MatchProcessXML = (
		SELECT DISTINCT MatchId "@MatchId"
			,CASE 
				WHEN f.GroupId IS NULL THEN 1 --SB
				WHEN f.GroupId = 1 THEN 6 -- Fast Market
				WHEN f.GroupId = 2 THEN 7 -- Fast market 228
				ELSE 0
				END AS "@KeyID" 
		FROM #validTransId t
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
		WHERE bettype NOT IN (9,29,2799)
		FOR XML PATH('r'), ROOT('root')
		)
	
	--Lock Refno process - SportBook
	EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT DISTINCT MatchId, refno
	FROM #validTransId 
	WHERE bettype IN (9,29,2799)
	SET @TotalRefnoParlay = @@ROWCOUNT

	IF @TotalRefnoParlay <= @ThreadHold
	BEGIN
		SET @MatchParlayProcessXML = (
		SELECT  MatchId "@MatchId"
				,refno AS "@RefNo"
		FROM @tblMatchParlay 
		FOR XML PATH('r'), ROOT('root'))
	END	
	ELSE
	BEGIN
		SET @MatchParlayProcessXML = NULL
	END

	-- return table result
	SELECT @InvalidTransIds AS InvalidTransIds
			,@IsExistSingle AS IsExistSingle
			,@IsExistParlay AS IsExistParlay
			,@IsExistFM AS IsExistFM
			,@IsExistFM2 AS IsExistFM2
			,@MatchProcessXML AS MatchProcessXML
			,@MatchParlayProcessXML AS MatchParlayProcessXML

	DROP TABLE #transIdTemp
	DROP TABLE #validTransId
END