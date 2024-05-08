/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_CheckQueue]
(
	 @SingleTicketsJSON		NVARCHAR(MAX) = NULL
	,@ParlayTicketsJSON		NVARCHAR(MAX) = NULL
	,@CricketTicketsJSON	NVARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20221201@Max
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20221201@Max: Create new SP [Redmine: #180625]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230814@Max: [TVS] Reduced Over - Update rule for action "auto void" [Redmine: #191762]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20240305@July: [TVS] Abnormal Bet - Void settled tickets for Auto Void actions [Redmine: #195506]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240424@Max: [TVS] Abnormal Bet - Remove some auto void actions & Remove AB (Real Member) issue type [Redmine: #202949]

	Param's explanation:
	 Note : Call for ActionId IN (1,9) -- Auto void winning, VoidResultKeyed
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpInputTransId (TransId BIGINT, RequestId INT, MatchId INT, IsMixParlay BIT DEFAULT(0), IssueTypeId TINYINT, VoidActionId TINYINT, IsCricket BIT DEFAULT(0))

	IF @SingleTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, VoidActionId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.VoidActionId, tbl.MatchId
		FROM OPENJSON(@SingleTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, VoidActionId TINYINT, MatchId INT) tbl
	END

	IF @ParlayTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IsMixParlay, IssueTypeId, VoidActionId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, 1, tbl.IssueTypeId, tbl.VoidActionId, tbl.Matchid
		FROM OPENJSON(@ParlayTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, VoidActionId TINYINT, MatchId INT) tbl
	END

	IF @CricketTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, IsCricket, VoidActionId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, 1, tbl.VoidActionId, tbl.MatchId
		FROM OPENJSON(@CricketTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, VoidActionId TINYINT, MatchId INT) tbl
	END

	--Remove request has already exists waiting in queue
	DELETE t
	FROM #tmpInputTransId t
		CROSS APPLY (
			SELECT q.Action, q.StatusId
			FROM dbo.TicketVoiding_AutoVoidQueue q WITH (NOLOCK) 
			WHERE t.RequestId IN (SELECT CAST(value AS INT) FROM STRING_SPLIT(q.RequestIds,',')) AND t.MatchId = q.MatchId
			)q
	WHERE q.Action IN ('CAL','VoidResultKeyed')
		AND q.StatusId = 0
	
	--Get statusWL of tiket
	SELECT DISTINCT t.RequestId, t.VoidActionId, t.MatchId
	FROM(
		SELECT DISTINCT t.RequestId, t.VoidActionId, t.MatchId
		FROM #tmpInputTransId t 
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE b.statuswinlost IS NOT NULL 
			AND 1 = CASE WHEN t.IssueTypeId IN (19,21,23) THEN 1
						WHEN t.IssueTypeId NOT IN (19,23) AND b.statusID IN (0,1) THEN 1
						ELSE 0
					END
		UNION ALL
		SELECT DISTINCT t.RequestId, t.VoidActionId, t.MatchId
		FROM #tmpInputTransId t 
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE b.statuswinlost IS NOT NULL AND b.statusID IN (0,1) --Abnormal bet
			
		UNION ALL
		SELECT DISTINCT t.RequestId, t.VoidActionId, t.MatchId
		FROM #tmpInputTransId t 
			INNER JOIN dbo.bettransm b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.IsMixParlay = 1
			AND t.IssueTypeId IN (19,21,23) 
			AND b.statuswinlost IS NOT NULL 
	)t

	--Invalid Transid
	SELECT t.RequestId, t.TransId
	FROM #tmpInputTransId t 
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
	WHERE 1 = CASE WHEN b.statusID IN (101, 102, 103) THEN 1
				   WHEN t.IssueTypeId IN (11) AND b.statusID NOT IN (0,1) THEN 1
				ELSE 0 END
		AND t.IsMixParlay = 0
		AND t.IsCricket = 0
	UNION ALL
	SELECT t.RequestId, t.TransId
	FROM #tmpInputTransId t 
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId
	WHERE 1 = CASE WHEN b.statusID IN (101, 102, 103) THEN 1
				   WHEN t.IssueTypeId IN (11) AND b.statusID NOT IN (0,1) THEN 1
				ELSE 0 END
		AND t.IsMixParlay = 0
		AND t.IsCricket = 0

	SELECT t.RequestId, t.TransId
	FROM #tmpInputTransId t 
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
	WHERE 1 = CASE WHEN b.statusID IN (101, 102, 103) THEN 1
				   WHEN t.IssueTypeId IN (11) AND b.statusID NOT IN (0,1) THEN 1
				ELSE 0 END
		AND t.IsMixParlay = 1

	SELECT t.RequestId, t.TransId
	FROM #tmpInputTransId t 
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
	WHERE 1 = CASE WHEN b.statusID IN (101, 102, 103) THEN 1
				   WHEN t.IssueTypeId IN (11) AND b.statusID NOT IN (0,1) THEN 1
				ELSE 0 END
		AND t.IsCricket = 1

	DROP TABLE #tmpInputTransId
END		
GO


