/*<info serverAlias="DBSIG-bodb02,DBCTG-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_VS_TicketInfo_Sel
	@MatchId		INT  = 0 
   ,@Sporttype		SMALLINT = 0
   ,@TransIDs		VARCHAR(MAX) = '' 
   ,@ResourceIds	VARCHAR(500) = NULL
AS
/*  
	Created: 20231016@Aries  
	Task: Auto Send Announcement When Refund VS [Redmine:#195333]
	DB: DBTXN/BODB02  

	Revisions:  
		- 20231016@Aries: Created [Redmine:#195333]
		- 20240118@Louisa: Integrate VS4 - Cock Fighting [Redmine: #199700]
		- 20240704@Aries: VS5 - Virtually Sports [Redmine:#207309]
		- 20240918@Aries: Betradar VS - Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing  [Redmine:#210875]
		- 20241023@Louisa: Modify code for VS6 and Change Service Alias from DBTXN to DBSIG,DBCTG  [Redmine:#210733]
		- 20250312@Jane: Integration VS7 - Kiron [Redmine:#219147]
		
	Param explanation:  
		- @MatchId: Get list ticket running, won, lose, draw
		- @TransIDs: Get info ticket
		- Execute SP with  only one parameter @MatchId or @TransIDs
		- @ResourceIds = 'Q3,Q4,00'
  
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @parlayBettype		SMALLINT
	DECLARE  @tmpBettype 		TABLE (bettype SMALLINT, betid BIGINT)
	DECLARE  @IsCentral			BIT = 0
	DECLARE @tmp_ResourceId		TABLE ( ResourceId VARCHAR(20) )

	CREATE TABLE #TicketInfo(transid BIGINT, custid INT, recommend INT, mrecommend INT, srecommend INT)
	CREATE TABLE #tmpTransId(transid BIGINT)
	CREATE TABLE #CustInfo(custid INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON),username NVARCHAR(100))
	CREATE TABLE #tmpRefno(refno BIGINT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON), statusID tinyint)

	SET @IsCentral = [dbo].[f_CheckServerCentral]()

	SELECT @parlayBettype  = CASE WHEN @Sporttype = 188 THEN 10449
								  WHEN @Sporttype IN (190,191,192,194,195,196,197,193) THEN 2799
								  WHEN @Sporttype IN (147) THEN 11099	
						          ELSE 0
						      END
	---VS3,4
	IF @Sporttype IN (147,178,179, 188) AND @MatchId > 0 AND ISNULL(@TransIDs,'') = ''
	BEGIN
		IF @Sporttype IN (147, 188)
		BEGIN
			INSERT INTO #tmpRefno (refno,statusID)
			SELECT bm.refno, bm.statusID
			FROM dbo.bettransm AS bm WITH(NOLOCK)
			WHERE matchid = @matchid
				AND bm.statusID IN (0,111,112,113)
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
		END

		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.matchid = @MatchId
			AND b.StatusID IN (0,111,112,113)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		
		UNION ALL
		SELECT p.transid,r.statusID
		FROM dbo.bettrans AS p WITH(NOLOCK)
			INNER JOIN #tmpRefno AS r ON r.refno = p.refno
		WHERE p.matchid = @parlayBettype
			AND p.bettype = @parlayBettype
			AND p.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE p.SiteDBGroupID END

		RETURN
	END
	--VS1
	ELSE IF @Sporttype IN (180,186) AND @MatchId > 0 AND ISNULL(@TransIDs,'') = ''
	BEGIN
		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b  WITH (NOLOCK)
		WHERE b.matchid = @matchid
			AND b.bettype IN (1201, 1203, 1204, 1205, 1206, 1224, 1220, 1235, 1236)
			AND b.StatusID IN (0,111,112,113)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		RETURN
	END
	ELSE IF @Sporttype IN (177,198) AND @MatchId > 0 AND ISNULL(@TransIDs,'') = ''
	BEGIN
		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b  WITH (NOLOCK)
		WHERE b.matchid = @matchid
			AND b.bettype IN (2770,2771)
			AND b.StatusID IN (0,111,112,113)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		RETURN
	END
	--VS2
	ELSE IF @Sporttype IN (190,191,192,194,195,196,197,193) AND @MatchId > 0 AND ISNULL(@TransIDs,'') = ''
	BEGIN
		INSERT INTO @tmpBettype(bettype)
		SELECT f.bettype
		FROM dbo.f_Set_VS_BetRadar_GetBettypes () AS f
		WHERE f.SportType = @SportType	

		INSERT INTO #tmpRefno (refno,statusID)
		SELECT bm.refno, bm.statusID
		FROM dbo.bettransm AS bm WITH(NOLOCK)
		WHERE matchid = @matchid
			AND EXISTS (SELECT 1 FROM @tmpBettype AS f WHERE f.bettype = bm.bettype)
			AND bm.statusID IN (0,111,112,113)
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
		

		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.matchid = @MatchId
			AND EXISTS (SELECT 1 FROM @tmpBettype AS f WHERE f.bettype = b.bettype)
			AND b.StatusID IN (0,111,112,113)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		
		UNION ALL

		SELECT p.transid,r.statusID
		FROM dbo.bettrans AS p WITH(NOLOCK)
			INNER JOIN #tmpRefno AS r ON r.refno = p.refno
		WHERE p.matchid = @parlayBettype
			AND p.bettype = @parlayBettype
			AND p.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE p.SiteDBGroupID END

		RETURN
	END
	-- VS7
	ELSE IF @Sporttype IN (125,126,127) AND @MatchId > 0 AND ISNULL(@TransIDs,'') = ''
	BEGIN
		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b  WITH (NOLOCK)
		WHERE b.matchid = @matchid
			AND b.bettype IN (15500,15501)
			AND b.StatusID IN (0,111,112,113)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		RETURN
	END
	ELSE IF ISNULL(@ResourceIds,'') <> ''
	BEGIN
		INSERT INTO @tmp_ResourceId ( ResourceId )
		SELECT v.value AS ResourceID FROM STRING_SPLIT(@ResourceIds, ',')v

		INSERT INTO @tmpBettype ( bettype, betid )
		SELECT sp.bettype, sp.betid 
		FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			INNER JOIN @tmp_ResourceId r
				ON r.ResourceID = sp.ResourceID
		WHERE sp.SportType = @Sporttype

		INSERT INTO @tmpBettype ( bettype, betid )
		SELECT sp.bettype, sp.betid 
		FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			INNER JOIN  @tmp_ResourceId r
				ON sp.RefResourceId = r.ResourceID 
		WHERE sp.SportType = @Sporttype
			AND ISNULL(sp.RefResourceID,'') <> ''

		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b  WITH (NOLOCK)
			INNER JOIN @tmpBettype bt 
				ON b.bettype = bt.bettype AND (bt.betid = 0 OR bt.betid = b.betid)
		WHERE b.matchid = @matchid
			AND b.StatusID IN (0,111,112,113)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		RETURN
	END
	
	------------------------------------------------------------------------
	INSERT INTO #tmpTransId(transid)
	SELECT value 
	FROM STRING_SPLIT(@TransIDs,',')

	INSERT INTO #TicketInfo(transid,custid,recommend,mrecommend,srecommend) 
	SELECT b.transid,b.custid,b.recommend,b.mrecommend,b.srecommend
	FROM #tmpTransId AS t 
		INNER JOIN  dbo.bettrans AS b WITH(NOLOCK) ON t.transid = b.transid
		OUTER APPLY(SELECT TOP 1 bm.statusID
					FROM dbo.bettransm AS bm WITH(NOLOCK)
					WHERE bm.refno = b.refno
						AND bm.statusID = 103
						AND b.matchid = @parlayBettype
						AND b.bettype = @parlayBettype
						AND bm.matchid =  @MatchId
					) AS p
	WHERE (b.statusID = 103 OR p.statusID IS NOT NULL)
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

	INSERT INTO #CustInfo(custid,username)
	SELECT DISTINCT ct.custid, ci.username
	FROM #TicketInfo AS tt
		CROSS APPLY (VALUES(tt.custid),(tt.recommend),(tt.mrecommend),(tt.srecommend)) AS ct (custid)
		INNER JOIN CustDB.dbo.custinfo AS ci WITH(NOLOCK) ON ct.custid = ci.custid

	SELECT t.transid
		  ,t.custid AS MemberId
		  ,u.UserName AS MemberUserName
		  ,t.recommend AS AgentId
		  ,r.UserName AS AgentUserName
		  ,t.mrecommend AS MasterId
		  ,m.UserName AS MasterUserName
		  ,t.srecommend AS SuperId
		  ,s.Username AS SuperUserName
	FROM #TicketInfo AS t
		INNER JOIN #CustInfo AS u ON t.custid = u.custid
		LEFT JOIN #CustInfo AS r ON t.recommend = r.custid
		LEFT JOIN #CustInfo AS m ON t.mrecommend = m.custid
		LEFT JOIN #CustInfo AS s ON t.srecommend = s.custid
	
END
GO