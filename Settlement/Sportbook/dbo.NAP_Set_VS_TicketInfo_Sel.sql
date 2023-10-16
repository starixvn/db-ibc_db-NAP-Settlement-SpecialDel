/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_VS_TicketInfo_Sel
	@MatchId		INT  = 0 
   ,@TransIDs		VARCHAR(MAX) = '' 
AS
/*  
	Created: 20231016@Aries  
	Task: Auto Send Announcement When Refund VS [Redmine:#195333]
	DB: DBTXN/BODB02  

	Revisions:  
		- 20231016@Aries: Created [Redmine:#195333]
		
	Param explanation:  
  
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @Sporttype			INT
	DECLARE  @parlayBettype		SMALLINT
	DECLARE  @tmpBettype 		TABLE (bettype SMALLINT)
	DECLARE  @tmpRefno 			TABLE (refno BIGINT)

	CREATE TABLE #TicketInfo(transid BIGINT, custid INT, recommend INT, mrecommend INT, srecommend INT)
	CREATE TABLE #tmpTransId(transid BIGINT)

	SELECT @sportType 	= sportType 
	FROM dbo.match m WITH(NOLOCK) 
	WHERE m.matchid = @MatchId

	IF @Sporttype = 178 AND @MatchId > 0
	BEGIN
		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.matchid = @MatchId
			AND b.StatusID IN (0,111,112,113)
		RETURN
	END
	ELSE IF @Sporttype = 180 AND @MatchId > 0
	BEGIN
		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b  WITH (ROWLOCK, UPDLOCK)
		WHERE b.matchid = @matchid
			AND b.bettype IN (1201, 1203, 1204, 1205, 1206, 1224, 1220, 1235, 1236)
			AND b.StatusID IN (0,111,112,113)
		RETURN
	END
	ELSE IF @Sporttype IN (190,191,192,194,195,196,197,193) AND @MatchId > 0
	BEGIN
		SET  @parlayBettype  = 2799

		INSERT INTO @tmpBettype(bettype)
		SELECT f.bettype
		FROM dbo.f_Set_VS_BetRadar_GetBettypes () AS f
		WHERE f.SportType = @SportType	

		INSERT INTO @tmpRefno (refno)
		SELECT bm.refno 
		FROM dbo.bettransm bm WITH(ROWLOCK)
		WHERE matchid = @matchid
			AND EXISTS (SELECT 1 FROM @tmpBettype AS f WHERE f.bettype = bm.bettype)
		

		SELECT b.transid,b.statusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.matchid = @MatchId
			AND EXISTS (SELECT 1 FROM @tmpBettype AS f WHERE f.bettype = b.bettype)
			AND b.StatusID IN (0,111,112,113)
		
		UNION ALL

		SELECT p.transid,p.statusID
		FROM dbo.bettrans AS p WITH(NOLOCK)
		WHERE p.matchid = @parlayBettype
			AND p.bettype = @parlayBettype
			AND EXISTS (SELECT 1 FROM @tmpRefno AS r WHERE r.refno = p.refno)
			AND p.StatusID IN (0,111,112,113)

		RETURN
	END
	
	INSERT INTO #tmpTransId(transid)
	SELECT value 
	FROM STRING_SPLIT(@TransIDs,',')

	INSERT INTO #TicketInfo(transid,custid,recommend,mrecommend,srecommend) 
	SELECT b.transid,b.custid,b.recommend,b.mrecommend,b.srecommend
	FROM #tmpTransId AS t 
		INNER JOIN  dbo.bettrans AS b WITH(NOLOCK) ON t.transid = b.transid
	WHERE b.StatusID = 103

	;WITH CTE_TicketInfo AS 
	(
		SELECT DISTINCT ct.custid, ci.username
		FROM #TicketInfo AS tt
			CROSS APPLY (VALUES(tt.custid),(tt.recommend),(tt.mrecommend),(tt.srecommend)) AS ct (custid)
			INNER JOIN CustDB.dbo.custinfo AS ci WITH(NOLOCK) ON ct.custid = ci.custid
	)
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
		INNER JOIN CTE_TicketInfo AS u ON t.custid = u.custid
		INNER JOIN CTE_TicketInfo AS r ON t.recommend = r.custid
		INNER JOIN CTE_TicketInfo AS m ON t.mrecommend = m.custid
		INNER JOIN CTE_TicketInfo AS s ON t.srecommend = s.custid
	
END
GO