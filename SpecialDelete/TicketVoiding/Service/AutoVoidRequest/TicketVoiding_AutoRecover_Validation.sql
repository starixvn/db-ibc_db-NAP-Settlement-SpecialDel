/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoRecover_Validation]
(
	 @SingleTicketsJSON			NVARCHAR(MAX) = NULL
	,@ParlayTicketsJSON			NVARCHAR(MAX) = NULL
	,@CricketTicketsJSON		NVARCHAR(MAX) = NULL
)
AS
/*	
	Created by:20231227@Max
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20231227@Max: Create new SP [Redmine: #196020]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IssueTypeId TINYINT
	CREATE TABLE #tmpInputTransId (
		TransId BIGINT
		, RequestId INT
		, IssueTypeId TINYINT
		, MatchId INT
		, TicketType TINYINT) --1: single(exclude cancel CO), 2 parlay, 3: cancel CO, 4: Cricket (bettype: 501)
	
	CREATE TABLE #tmpTransIds (
		TransId BIGINT PRIMARY KEY
		, RequestId INT
		, StatusID TINYINT
		, statuswinlost TINYINT
		, betdaqid BIGINT
		, Matchid INT
		, IssueTypeId TINYINT
		, TicketType TINYINT
	)
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT, TicketType TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT)

	--Bet14
	CREATE TABLE #SingleTickets_14 (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT)
	CREATE TABLE #ParlayTickets_14 (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT)

	IF @SingleTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 1
		FROM OPENJSON(@SingleTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT) tbl
	END

	IF @ParlayTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 2
		FROM OPENJSON(@ParlayTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT) tbl
	END

	IF @CricketTicketsJSON IS NOT NULL
	BEGIN		
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 4
		FROM OPENJSON(@CricketTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT) tbl
	END

	SET @IssueTypeId = (SELECT TOP 1 IssueTypeId FROM #tmpInputTransId)
	IF @IssueTypeId IN (22)
	BEGIN
		INSERT INTO #SingleTickets (TransId, RequestId, Matchid, IssueTypeId, TicketType, transdate, winlostdate, statusId)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,t.TicketType
			,b.transdate
			,b.winlostdate
			,b.statusID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType <> 2

		INSERT INTO #ParlayTickets (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,b.transdate
			,b.winlostdate
			,b.statusID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType = 2

		IF EXISTS (SELECT TOP 1 1 FROM #tmpInputTransId t
					INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId)
		BEGIN
			INSERT INTO #SingleTickets_14 (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId)
			SELECT t.TransId
				,t.RequestId
				,t.MatchId
				,t.IssueTypeId
				,b.transdate
				,b.winlostdate
				,b.statusID
			FROM #tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId AND b.bettype NOT IN (9,29,2799,10449)

			INSERT INTO #ParlayTickets_14 (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId)
			SELECT t.TransId
				,t.RequestId
				,t.MatchId
				,t.IssueTypeId
				,b.transdate
				,b.winlostdate
				,b.statusID
			FROM #tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId AND b.bettype IN (9,29,2799,10449)
		END
	END
	
	SELECT TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId FROM #SingleTickets WHERE TicketType = 1 --Single
	SELECT TransId, RequestId, MatchId, IssueTypeId, transdate, winlostdate, statusId FROM #ParlayTickets --Parlay

	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #SingleTickets WHERE TicketType = 4 --Cricket

	SELECT TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId FROM #SingleTickets_14 --Single_14
	SELECT TransId, RequestId, MatchId, IssueTypeId, transdate, winlostdate, statusId FROM #ParlayTickets_14 --Parlay_14

	DROP TABLE #tmpInputTransId
	DROP TABLE #tmpTransIds
	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
	DROP TABLE #SingleTickets_14
	DROP TABLE #ParlayTickets_14
END		
GO


