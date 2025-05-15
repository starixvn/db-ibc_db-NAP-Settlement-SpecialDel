/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TotalVoidedTicket_Select]
( 
	@RequestInfo VARCHAR(MAX) = NULL
)
AS;
/*	Created by: 20220822@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine:#175412]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20220822@July: Create new SP - get total voided ticket [Redmine:#175412]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		- 20230529@July: Support case Cricket main in table match -> child in table match14 [Redmine: #188153]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240319@July: [TVS] SP tuning for EC2024 [Redmine: #200840]
		- 20240424@Max: [TVS] Abnormal Bet - Remove some auto void actions & Remove AB (Real Member) issue type [Redmine: #202949]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240916@Max: [TVS] Support void wrong odds for Sportsbook [Redmine: #186029]
		- 20241021@Max: [TVS] New Issue Type - Other Issues [Redmine: #211913]
		- 20241122@July: Wrong Market Offered - Enhance the way to add request & Update 'copy' message template [Redmine: #212928]
		- 20250515@Lani: [TVS] New Issue Type - Match Early Completed [Redmine: #226438]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE  @SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #tmpMatchVoidingHistory (
		 RequestId			INT
		,VoidingHistoryId	INT
		,MatchId			INT
		,IssueTypeId		TINYINT
		,RequestDetailId	INT
	)
	CREATE NONCLUSTERED INDEX IX_tmpMatchVoidingHistory_VoidingHistoryId ON #tmpMatchVoidingHistory (VoidingHistoryId)

	CREATE TABLE #tmpResult(
		 RequestId			INT
		,MatchId			INT
		,IssueTypeId		TINYINT
		,RequestDetailId	INT
		,TotalSingleProcessed	INT DEFAULT (0)
		,TotalParlayProcessed	INT DEFAULT (0)
		,TotalCancelCashOutProcessed INT DEFAULT (0)
		,TotalResettleProcessed	INT DEFAULT (0)
	)

	INSERT INTO #tmpMatchVoidingHistory( 
		 RequestId			
		,VoidingHistoryId	
		,IssueTypeId	
		,MatchId
		,RequestDetailId
	)
	SELECT req, vh, it, mid, ISNULL(id,0)
	FROM STRING_SPLIT(@RequestInfo, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_RequestInfo) t
		CROSS APPLY (
				SELECT req, vh, it, mid, id
				FROM OPENJSON(t.Decompress_RequestInfo) 
				WITH( req INT, vh INT, it TINYINT, mid INT, id INT)
			)tbl
	WHERE f.value <> ''

	INSERT INTO #tmpResult (RequestId, MatchId, IssueTypeId, RequestDetailId)
	SELECT DISTINCT RequestId, MatchId, IssueTypeId, ISNULL(RequestDetailId,0)
	FROM #tmpMatchVoidingHistory
	
	-- single ticket	
	;WITH CTE_Single AS(
			SELECT	vh.RequestId, vh.MatchId, vh.RequestDetailId
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (1,10,3,12,24,25,18,27) AND f.bettype IS NULL THEN 1
							WHEN vh.IssueTypeId IN (1,10,3,12,24,25,18,27) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
						ELSE 0 END
					) AS TotalSingleProcessed
					,SUM(CASE WHEN f.bettype IS NOT NULL THEN 1 ELSE 0 END) AS TotalParlayProcessed
					,SUM(CASE WHEN vh.IssueTypeId IN (1,10,3,12,24) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOutProcessed -- Apply for DA,RC,WC
			FROM #tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId AND z.VoidingHistoryId IS NOT NULL
				LEFT JOIN f_TVS_SpeciallyBettypes() f ON f.TypeId IN (0,1) AND f.Bettype = z.bettype
			WHERE z.SiteDBGroupID = @SiteDBGroupID AND vh.IssueTypeId NOT IN (22) --Recover Ticket
			GROUP BY vh.RequestId, vh.MatchId, vh.RequestDetailId
	)
	UPDATE vh 
		SET TotalSingleProcessed = t.TotalSingleProcessed
			,TotalParlayProcessed = t.TotalParlayProcessed
			,TotalCancelCashOutProcessed = t.TotalCancelCashOutProcessed
	FROM #tmpResult vh
		INNER JOIN CTE_Single t ON vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR vh.MatchId = 0)
									AND vh.RequestDetailId = t.RequestDetailId

	--parlay ticket
	;WITH CTE_Parlay AS(
		SELECT	vh.RequestId, vh.MatchId, vh.RequestDetailId
					,COUNT(1) AS TotalParlayProcessed
			FROM	#tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId AND zm.VoidingHistoryId IS NOT NULL
			WHERE zm.SiteDBGroupID = @SiteDBGroupID AND vh.IssueTypeId NOT IN (11,13,17,22) --Except AB,AC,ARC,RT
			GROUP BY vh.RequestId, vh.MatchId, vh.RequestDetailId
	)
	UPDATE vh
		SET TotalParlayProcessed = t.TotalParlayProcessed
	FROM	#tmpResult vh
		INNER JOIN CTE_Parlay t ON vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR vh.MatchId = 0)
									AND vh.RequestDetailId = t.RequestDetailId
									
	IF EXISTS (SELECT TOP 1 1 FROM #tmpMatchVoidingHistory WHERE IssueTypeId = 22)
	BEGIN
		DECLARE @tmp_TransId AS TABLE (RequestId INT, TransId BIGINT, MatchId INT, IsProcessed TINYINT)

		INSERT INTO @tmp_TransId(RequestId, TransId, MatchId, IsProcessed)
		SELECT t.RequestId, s.TransId, s.MatchId, s.IsProcessed
		FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpResult t ON t.RequestId = s.Requestid
		WHERE s.IsProcessed IS NOT NULL AND s.IssueTypeId = 22
			AND s.SiteDBGroupID = @SiteDBGroupID

		DELETE t
		FROM @tmp_TransId t
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON t.TransId = z.transid AND z.comstatus <> 'CO'
		WHERE z.SiteDBGroupID = @SiteDBGroupID

		UPDATE t 
		SET TotalSingleProcessed = ISNULL(rt.TotalSingleProcessed,0)
			,TotalParlayProcessed = ISNULL(rt.TotalParlayProcessed,0)
			,TotalResettleProcessed= ISNULL(rt.TotalResettleProcessed,0) 
		FROM	#tmpResult t
		CROSS APPLY (SELECT 
						SUM(CASE WHEN f.bettype IS NULL THEN 1 ELSE 0 END) AS TotalSingleProcessed
						,SUM(CASE WHEN f.bettype IS NOT NULL THEN 1 ELSE 0 END) AS TotalParlayProcessed
						,SUM(CASE WHEN s.IsProcessed = 2 THEN 1 ELSE 0 END) AS TotalResettleProcessed
					FROM @tmp_TransId s
						LEFT JOIN f_TVS_SpeciallyBettypes() f ON f.TypeId IN (0,1) AND f.Bettype = s.MatchId
					WHERE s.RequestId = t.RequestId
				)rt	
		WHERE t.IssueTypeId = 22 --Recover Ticket
	END

	SELECT  RequestId			
		   ,CASE WHEN IssueTypeId IN (13,17,22) THEN NULL ELSE matchid END AS matchid
		   ,RequestDetailId 
		   ,TotalSingleProcessed	
		   ,TotalParlayProcessed	
		   ,TotalCancelCashOutProcessed
		   ,TotalResettleProcessed
	FROM #tmpResult

	DROP TABLE #tmpResult
	DROP TABLE #tmpMatchVoidingHistory
END
GO
