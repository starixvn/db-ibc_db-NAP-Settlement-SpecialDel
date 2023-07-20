/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_CheckDuplicateTickets]
(
	 @TransIds					VARCHAR(MAX) = NULL
	,@RequestId					INT = 0
	,@ActionId					TINYINT	= 0
	,@FilterBy					TINYINT	= NULL
	,@SubIssueTypeId			TINYINT	= NULL
	,@TransInfoJson				VARCHAR(MAX) = NULL
)
AS
/*  
	Created by:20230717@Max
	Task: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230717@Max: Create new SP [Redmine:#187835]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds			 VARCHAR(MAX) = ''
			,@MovedTransIds				 VARCHAR(MAX) = ''
			,@DifferentMatchTransIds     VARCHAR(MAX) = '' 
			,@SettledTransIds			 VARCHAR(MAX) = ''
			,@UnsupportedTransids		 VARCHAR(MAX) = ''
			,@ExistingReqTransIds		 VARCHAR(MAX) = ''
			,@IsHasWarningRemovedTickets BIT=0
			,@OldActionId				 TINYINT
			,@MatchId					 INT = 0
			,@MarkTransIds 			     VARCHAR(MAX) =''
			,@UnmarkTransIds 			 VARCHAR(MAX) =''
			,@RemoveTransids 			 VARCHAR(MAX) ='' -- Ticket remove will re-cal (if any)
			,@TransInfoJson_Output	VARBINARY(MAX) = NULL

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT, CustID INT)
	DECLARE @tmpMatchId AS TABLE (MatchId INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT, matchcode NVARCHAR(50), IsFinish BIT)
	DECLARE @tmp_Result AS TABLE (MatchId INT, TransInfoJson VARCHAR(MAX), MarkTransIds VARCHAR(MAX), UnmarkTransIds VARCHAR(MAX), SiteDBAffected VARCHAR(20))

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID IN (1, 3, 5, 27, 77) -- SB, NG, VS, VS2, VS3
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	CREATE TABLE #inputTransid (transid BIGINT PRIMARY KEY)
	CREATE TABLE #TransidInRequest (TransId BIGINT PRIMARY KEY)
	CREATE TABLE #validTransId (
		transid			BIGINT PRIMARY KEY
		,isInMatch		BIT
		,StatusId		INT
		,bettype		SMALLINT
		,custId			INT
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,matchid		INT
		,sporttype		SMALLINT
		,betfrom		NVARCHAR(4)
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,betteam		NVARCHAR(10)
		,SubMatchIdList	VARCHAR(2000)
		,CurrencyName	NVARCHAR(50)
		)
	CREATE TABLE #UnsupportedTransids(transid BIGINT PRIMARY KEY)
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
      ,refno BIGINT
	  ,custid	INT	
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
      ,betfrom NVARCHAR(4)
      ,bettype SMALLINT
	  ,betteam NVARCHAR(10)
      ,betid BIGINT
      ,statusID TINYINT
	  ,srecommend INT
	  ,mrecommend INT
	  ,recommend INT
	  ,CurrencyName NVARCHAR(50)
	  ,statuswinlost TINYINT
	  ,SubMatchIdList VARCHAR(2000)
	  ,IsMoved14 BIT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)
	
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,refno
		  ,custid		
		  ,livehomescore 
		  ,liveawayscore 
		  ,liveindicator 
		  ,betfrom
		  ,bettype
		  ,betteam
		  ,betid
		  ,statusID
		  ,srecommend
		  ,mrecommend
		  ,recommend 
		  ,CurrencyName
		  ,statuswinlost
		  ,SubMatchIdList
		  ,IsMoved14
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT mid ,t ,ref ,c ,lh ,la ,li
		,bfr ,btype ,bteam ,bid ,sid 
		,sre ,mre ,re ,curr ,statuswl ,s_mid ,isM ,isP ,sitedb
	FROM string_split(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,ref ,c ,lh ,la ,li
					  ,bfr ,btype ,bteam ,bid ,sid 
					  ,sre ,mre ,re ,curr ,statuswl ,s_mid ,isM ,isP ,sitedb
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, ref BIGINT, c INT, lh SMALLINT, la SMALLINT ,li BIT 
					 ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bid BIGINT ,sid TINYINT 
					 ,sre INT ,mre INT ,re INT ,curr NVARCHAR(50) ,statuswl TINYINT ,s_mid VARCHAR(2000) ,isM BIT ,isP BIT ,sitedb SMALLINT
				)
		) tbl
	WHERE f.value <> ''

	INSERT INTO #inputTransid (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo)
	BEGIN
		SELECT MatchId FROM @tmpMatchId

		SET @InvalidTransIds = @TransIds
		SELECT @InvalidTransIds AS InvalidTransIds

		SELECT @TransInfoJson_Output AS TransInfoJson
		RETURN;
	END

	IF @FilterBy IS NULL
	BEGIN
		SET @MatchId = (SELECT TOP 1 b.matchid
							FROM #tmpTransInfo AS b WITH (NOLOCK)
								INNER JOIN #inputTransid tmp ON b.transid = tmp.transid
							WHERE (1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102) THEN 1
										   WHEN @ActionId = 2 AND b.statusID  <> 101 THEN 1
										   ELSE 0 END) 
									AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype))
	
		IF @MatchId IS NULL
		BEGIN
			SELECT MatchId FROM @tmpMatchId

			SET @InvalidTransIds = @TransIds
			SELECT  @InvalidTransIds AS InvalidTransIds

			SELECT @TransInfoJson_Output AS TransInfoJson
			RETURN;
		END

		INSERT INTO @tmpMatchId (MatchId, homeid, awayid, leagueid,sporttype, matchcode)
		SELECT m.matchid, homeid, awayid, leagueid, sporttype, matchcode
		FROM dbo.match m WITH(NOLOCK) 
		WHERE matchid = @MatchId
	END
	ELSE IF @FilterBy =1
	BEGIN
		SET @MatchId = 29
		INSERT INTO @tmpMatchId (MatchId)
		SELECT @MatchId
	END
	 
	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,isInMatch
		,StatusId
		,bettype
		,custId
		,livehomescore
		,liveawayscore
		,liveindicator
		,matchid
		,sporttype
		,betfrom
		,recommend
		,mrecommend
		,srecommend
		,betteam
		,SubMatchIdList
		,CurrencyName
		)
	SELECT b.transid
		,CASE WHEN b.matchid = @MatchId THEN 1 ELSE 0 END
		,b.statusID
		,b.bettype
		,b.custid
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,m.matchid
		,m.sporttype
		,b.betfrom
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,b.betteam
		,SubMatchIdList
		,CurrencyName
	FROM #tmpTransInfo b
		INNER JOIN #inputTransid tmp ON b.transid = tmp.transid
		LEFT JOIN @tmpMatchId m ON b.matchid = b.matchid
	WHERE 1 = CASE WHEN @FilterBy IS NULL AND b.bettype <> 29 THEN 1
			       WHEN @FilterBy = 1 AND b.bettype = 29 THEN 1
				   ELSE 0 END
		AND b.IsMoved14 = 0

	-- get unsuppored transid
	INSERT #UnsupportedTransids (transid)
	SELECT t.transid
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE 1 = CASE WHEN bt.bettype IS NULL 
						AND (t.bettype <> 29 OR (t.bettype = 29  AND t.betteam <> '1')) --Unsupported System parlay Transids
				   THEN 1
				   ELSE 0 END

	SELECT @UnsupportedTransids = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #UnsupportedTransids t
									FOR XML PATH('')
							), 1, 1, ''), '')
	
	--final valid transid
	DELETE t
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE (1 = CASE WHEN @ActionId <>2 AND StatusId IN (101, 102, 103) THEN 1
				    WHEN @ActionId = 2 AND StatusId IN (101, 103) THEN 1
					ELSE 0 END)
		OR (bt.bettype IS NULL AND 1 = CASE WHEN @FilterBy IS NULL THEN 1 
										    WHEN @FilterBy = 1 AND t.bettype = 29  AND t.betteam <> '1' THEN 1
										    ELSE 0 END 
										   )
		OR t.betfrom ='p'
	
	INSERT INTO #TransidInRequest (TransId)
	SELECT DISTINCT tmp.transid
	FROM dbo.TicketVoiding_Request req WITH (NOLOCK)
		CROSS APPLY (
					SELECT TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
					WHERE RequestId = req.RequestId AND (MatchId = @MatchId OR MatchId = 29)
				) AS tmp
	WHERE  req.RequestId <> @RequestId AND req.ActionId <> 2


	-- invalid transId
	;WITH t_invalid
	AS (
		SELECT temp.transid
			,ISNULL(bm.IsMoved14, 0) AS isMoved
		FROM #inputTransid AS temp
			OUTER APPLY (
			SELECT TOP 1 IsMoved14
			FROM #tmpTransInfo
			WHERE transid = temp.transid AND IsMoved14 = 1
			) bm
			OUTER APPLY (
			SELECT transid
			FROM #UnsupportedTransids
			WHERE transid = temp.transid
			) u
		WHERE NOT EXISTS (SELECT 1 FROM #validTransId WHERE transid = temp.transid )
			AND u.transid IS NULL
		)
	SELECT @InvalidTransIds = @InvalidTransIds + CASE 
			WHEN isMoved = 0 THEN CASE 
					WHEN @InvalidTransIds <> '' THEN ','
					ELSE ''
					END + CAST(transid AS VARCHAR(100))
			ELSE ''
			END
		,@MovedTransIds = @MovedTransIds + CASE 
			WHEN isMoved = 1 THEN CASE 
					WHEN @MovedTransIds <> '' THEN ','
					ELSE ''
					END + CAST(transid AS VARCHAR(100))
			ELSE ''
			END
	FROM t_invalid

	SELECT @DifferentMatchTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
										FROM #validTransId AS v
										WHERE v.isInMatch = 0 AND @MatchId NOT IN (0,29)
										FOR XML PATH('')), 1, 1, '')
										, '')
	IF @ActionId <> 2
	BEGIN
		SELECT @ExistingReqTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #inputTransid t 
											INNER JOIN #TransidInRequest tr ON t.transid = tr.TransId
										FOR XML PATH('')), 1, 1, '')
										, '')

		SELECT @SettledTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
										FROM #validTransId AS v
										WHERE v.StatusId NOT IN (0,1)
										FOR XML PATH('')), 1, 1, '')
										, '')
	END

	/******************************* MARK/ UNMARK/ REMOVE TICKETS **************************************/

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		INSERT INTO @tmpMarkTransId (TransId, CustID)
		SELECT transid, custId
		FROM #validTransId WHERE StatusId IN (0,1)
	END
	ELSE IF @RequestId <> 0
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Remove transid from request => unmark ticket & re-cal ticket
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT transid 
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
			WHERE NOT EXISTS( SELECT TOP 1 1 FROM #validTransId it WHERE rdt.TransId=it.transid) -- exist vs input
					AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
					AND rdt.RequestId = @RequestId
	
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT v.transid 
			FROM #validTransId v
			
			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT transid 
			FROM #validTransId v
			WHERE v.StatusId IN (0,1) AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = v.TransId)-- exist in # request
				AND NOT EXISTS ( SELECT TOP 1 1 FROM @tmpUnmarkTransId um WHERE um.TransId = v.transid)
		
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			INSERT INTO @tmpMarkTransId (TransId, CustID)
			SELECT transid, custId
			FROM #validTransId WHERE StatusId IN (0,1)
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId --Take note
		BEGIN
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT rdt.TransId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
			WHERE rdt.RequestId = @RequestId
			
		END
	END

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,'')
											,'')

	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
												FROM @tmpUnmarkTransId
												FOR XML PATH('')), 1,1,'')
												,'')
	IF @UnmarkTransIds <> ''
	BEGIN
		SET @IsHasWarningRemovedTickets = 1
				
		SELECT @RemoveTransids = @UnmarkTransIds
	END

	/*****************Return table **************************/
	--1. Info match table
	SELECT matchid, homeid, awayid, leagueid, sporttype, matchcode
	FROM @tmpMatchId
		
	--2. Validate Table
	SELECT   @MovedTransIds AS MovedTransIds
			,@DifferentMatchTransIds AS DifferentMatchTransIds
			,@InvalidTransIds AS InvalidTransIds
			,@SettledTransIds AS SettledTransIds
			,@ExistingReqTransIds AS ExistingReqTransIds
			,@UnsupportedTransids AS UnsupportedTransids
			,@IsHasWarningRemovedTickets AS IsHasWarningRemovedTickets

	--4. Transinfo table
	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) m
			SET @MatchId = m.MatchId
			, m.IsFinish = 1
		FROM @tmpMatchId  m 
		WHERE m.IsFinish IS NULL

		IF @@ROWCOUNT = 0 
			BREAK

		SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
			,t.transid AS 't'
			,b.custid AS  'c'           
			,b.bettype AS 'btype'
			,b.betteam AS 'bteam'
			,b.betid AS 'bid'
			,b.IsMixParlay AS 'isP'
			,b.SiteDBGroupID AS 'sitedb'
		FROM #validTransId t
			INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
		WHERE t.matchid = @MatchId
		FOR JSON PATH))

		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,'')
											,'')

		SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
													FROM @tmpUnmarkTransId
													FOR XML PATH('')), 1,1,'')
													,'')

		INSERT INTO @tmp_Result (MatchId, TransInfoJson, MarkTransIds, UnmarkTransIds)
		SELECT @MatchId, CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1), @MarkTransIds, @UnmarkTransIds
	END
	
	
	SELECT MatchId, TransInfoJson, MarkTransIds, UnmarkTransIds, SiteDBAffected FROM @tmp_Result


	DROP TABLE #inputTransid
	DROP TABLE #validTransId
	DROP TABLE #TransidInRequest
	DROP TABLE #UnsupportedTransids
	DROP TABLE #tmpTransInfo
END
