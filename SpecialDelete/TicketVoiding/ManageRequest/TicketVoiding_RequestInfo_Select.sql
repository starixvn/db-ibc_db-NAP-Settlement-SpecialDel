/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestInfo_Select]
(
	@RequestId		INT	= NULL
   ,@MatchId		INT = 0
)
AS
/*	Created by: 20181212@Zane
	Task: Optimize Voiding Workflow [Redmine:#145719]
	DB: DBCTG/bodb02
	
	Revisions: 		
		- 20201229@Zane: Create new SP [Redmine:#145719]
		- 20210607@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20220113@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220413@July: TVS - New issue type Wrong OU and Wrong 1H OU [Redmine: #170220]
		- 20221201@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230529@July: Support case Cricket main in table match -> child in table match14 [Redmine: #188153]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240319@July: [TVS] SP tuning for EC2024 [Redmine: #200840]
		- 20240422@Max: [TVS] Abnormal Bet - Add single tickets of many matches to a request [Redmine: #196027]
		- 20240520@July: HotFix - [TVS] Wrong display No. of Tickets [Redmine: #205304]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @IssueTypeId TINYINT

	CREATE TABLE #tmpResult (
		 RequestId					 INT
		,MatchId					 INT
		,LastVoidedBy				 INT
		,VoidingHistoryId			 INT
		,TotalSingleProcessed		 INT DEFAULT (0)
		,TotalParlayProcessed		 INT DEFAULT (0)
		,TotalCancelCashOutProcessed INT DEFAULT (0)
		,TotalResettleProcessed		 INT DEFAULT (0)
	)
	
	SELECT @IssueTypeId = IssueTypeId FROM dbo.TicketVoiding_Request WITH (NOLOCK) WHERE RequestId = @RequestId

	INSERT INTO #tmpResult(RequestId, VoidingHistoryId, LastVoidedBy, MatchId)
	SELECT DISTINCT rd.RequestId
			,vh.VoidingHistoryId
			,vh.UserId
			,@MatchId
	FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON rd.RequestId = vh.RequestId	
		INNER JOIN dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					ON vh.VoidingHistoryId = s.VoidingHistoryId 
					AND vh.RequestId = s.requestId
					AND (rd.MatchId = s.matchID OR s.matchID = 0)
	WHERE	rd.RequestId = @RequestId 
		AND 1 = CASE WHEN @IssueTypeId = 11 AND @MatchId = 0 THEN 1
					WHEN rd.MatchId = @MatchId THEN 1
				ELSE 0 END
	
	IF @IssueTypeId NOT IN (22) --NOT Recover Ticket
	BEGIN
		-- single ticket
		;WITH CTE_Single AS(
			SELECT vh.RequestId
					,SUM( CASE 
							WHEN @IssueTypeId NOT IN (1,10,3,12,24) AND z.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1
							WHEN @IssueTypeId IN (1,10,3,12,24) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
							ELSE 0 END
					) AS TotalVoidedSingle
					,SUM(CASE WHEN z.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END) AS TotalVoidedParlay
					,SUM(CASE WHEN @IssueTypeId IN (1,10,3,12,24) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOut -- Apply for DA,RC,WC
			FROM #tmpResult vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) 
						ON vh.VoidingHistoryId = z.VoidingHistoryId AND z.VoidingHistoryId IS NOT NULL
			GROUP BY vh.RequestId
		)
		UPDATE vh 
			SET TotalSingleProcessed = t.TotalVoidedSingle
				,TotalParlayProcessed = t.TotalVoidedParlay
				,TotalCancelCashOutProcessed = t.TotalCancelCashOut
		FROM #tmpResult vh
			INNER JOIN CTE_Single t ON vh.RequestId = t.RequestId
		
		--parlay ticket
		;WITH CTE_Parlay AS(
			SELECT vh.RequestId
				 , COUNT(1) AS TotalVoidedParlay
			FROM #tmpResult vh
				INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK) 
					ON zm.VoidingHistoryId = vh.VoidingHistoryId AND zm.VoidingHistoryId IS NOT NULL
			GROUP BY vh.RequestId
		)
		UPDATE vh
			SET TotalParlayProcessed = t.TotalVoidedParlay
		FROM #tmpResult vh
			INNER JOIN CTE_Parlay t ON vh.RequestId = t.RequestId
	END
	ELSE --Recover Ticket
	BEGIN
		DECLARE @tmp_TransId AS TABLE (RequestId INT, TransId BIGINT, MatchId INT, IsProcessed TINYINT)

		INSERT INTO @tmp_TransId(RequestId, TransId, MatchId, IsProcessed)
		SELECT t.RequestId, s.TransId, s.MatchId, s.IsProcessed
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpResult t ON t.RequestId = s.Requestid AND s.MatchId = t.MatchId
		WHERE s.IsProcessed IS NOT NULL

		DELETE t
		FROM @tmp_TransId t
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON t.TransId = z.transid AND z.comstatus <> 'CO'

		UPDATE t 
		SET TotalSingleProcessed = ISNULL(rt.TotalSingleProcessed,0)
			,TotalParlayProcessed = ISNULL(rt.TotalParlayProcessed,0)
			,TotalResettleProcessed= ISNULL(rt.TotalResettleProcessed,0) 
		FROM	#tmpResult t
		CROSS APPLY (SELECT 
						SUM(CASE WHEN s.MatchId NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END) AS TotalSingleProcessed
						,SUM(CASE WHEN s.MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END) AS TotalParlayProcessed
						,SUM(CASE WHEN s.IsProcessed = 2 THEN 1 ELSE 0 END) AS TotalResettleProcessed
					FROM @tmp_TransId s
					WHERE s.RequestId = t.RequestId
				)rt	
	END
	
	--Return Data
	SELECT TOP(1)
			t.RequestId
			,MatchId
			,v.Username AS LastPerformedBy
			,t.TotalSingleProcessed
			,t.TotalParlayProcessed
			,t.TotalCancelCashOutProcessed
			,t.TotalResettleProcessed
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
	ORDER BY t.VoidingHistoryId DESC
	
	DROP TABLE #tmpResult	
END
