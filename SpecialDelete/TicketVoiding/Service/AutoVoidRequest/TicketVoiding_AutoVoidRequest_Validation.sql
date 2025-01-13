/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Validation]
(
	 @SingleTicketsJSON			NVARCHAR(MAX) = NULL
	,@ParlayTicketsJSON			NVARCHAR(MAX) = NULL
	,@CancelCashOutTicketsJSON	NVARCHAR(MAX) = NULL
	,@CricketTicketsJSON		NVARCHAR(MAX) = NULL
)
AS
/*	
	Created by:20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230517@Max: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230814@Max: [TVS] Reduced Over - Update rule for action "auto void" [Redmine: #191762]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20231016@Max: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240305@July: [TVS] Abnormal Bet - Void settled tickets for Auto Void actions [Redmine: #195506]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240424@Max: [TVS] Abnormal Bet - Remove some auto void actions & Remove AB (Real Member) issue type [Redmine: #202949]
		- 20240516@Max: [TVS] Web get data via API [Redmine: #204974]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20240925@July: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
		- 20250109@Max: [TVS] Update for voiding bettype Net Possion 501 [Redmine: #216611]
		- 20241218@July: [TVS] Enhance the error message when voiding tickets are failed [Redmine: #213398]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IssueTypeId TINYINT
		, @ActionId TINYINT

	CREATE TABLE #tmpInputTransId (
		TransId BIGINT
		, RequestId INT
		, IssueTypeId TINYINT
		, MatchId INT
		, TicketType TINYINT --1: single(exclude cancel CO), 2 parlay, 3: cancel CO, 4: Cricket (bettype: 501)
		, VoidActionId TINYINT 
		, SiteDBGroupID SMALLINT
	) 
	
	CREATE TABLE #tmpTransIds (
		TransId BIGINT PRIMARY KEY
		, RequestId INT
		, StatusID TINYINT
		, statuswinlost TINYINT
		, betdaqid BIGINT
		, Matchid INT
		, IssueTypeId TINYINT
		, TicketType TINYINT
		, transdate DATETIME
		, winlostdate DATETIME
		, CheckTimeCancelCashOut DATETIME
		, SiteDBGroupID SMALLINT
	)

	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT, TicketType TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT, SiteDBGroupID SMALLINT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT, SiteDBGroupID SMALLINT)
	CREATE TABLE #SingleTickets_ReSettle (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT, TicketType TINYINT, SiteDBGroupID SMALLINT)
	CREATE TABLE #ParlayTickets_ReSettle (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT, SiteDBGroupID SMALLINT)
	CREATE TABLE #CancelCashOutTickets (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT, transdate DATETIME, winlostdate DATETIME, CheckTimeCancelCashOut DATETIME, SiteDBGroupID SMALLINT)
	--Void14 (Abnormal Account only)
	CREATE TABLE #SingleTickets_14 (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT, SiteDBGroupID SMALLINT)
	CREATE TABLE #ParlayTickets_14 (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT, transdate DATETIME, winlostdate DATETIME, statusId INT, SiteDBGroupID SMALLINT)

	CREATE TABLE #Tickets_Result (
		TransId BIGINT
		, RequestId INT
		, Matchid INT
		, IssueTypeId TINYINT
		, TicketType TINYINT
		, transdate DATETIME
		, winlostdate DATETIME
		, statusId INT
		, ValidationType TINYINT
		, CheckTimeCancelCashOut DATETIME
		, SiteDBGroupID SMALLINT
	)
	CREATE INDEX IX_ValidationType ON #Tickets_Result (ValidationType)

	IF @SingleTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType, VoidActionId, SiteDBGroupID)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 1, tbl.VoidActionId, tbl.SiteDBGroupID
		FROM OPENJSON(@SingleTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT, VoidActionId TINYINT, SiteDBGroupID SMALLINT) tbl
	END

	IF @ParlayTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType, VoidActionId, SiteDBGroupID)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 2, tbl.VoidActionId, tbl.SiteDBGroupID
		FROM OPENJSON(@ParlayTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT, VoidActionId TINYINT, SiteDBGroupID SMALLINT) tbl
	END

	IF @CancelCashOutTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType, VoidActionId, SiteDBGroupID)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 3, tbl.VoidActionId, tbl.SiteDBGroupID
		FROM OPENJSON(@CancelCashOutTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT, VoidActionId TINYINT, SiteDBGroupID SMALLINT) tbl
	END

	IF @CricketTicketsJSON IS NOT NULL
	BEGIN		
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType, VoidActionId, SiteDBGroupID)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 4, tbl.VoidActionId, tbl.SiteDBGroupID
		FROM OPENJSON(@CricketTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT, VoidActionId TINYINT, SiteDBGroupID SMALLINT) tbl
	END

	SELECT TOP 1 @IssueTypeId = IssueTypeId 
		,@ActionId = VoidActionId 
	FROM #tmpInputTransId

	IF @IssueTypeId IN (11) AND @ActionId = 1 --For: action auto void winning
	BEGIN
		INSERT INTO #tmpTransIds (TransId, RequestId, StatusID, statuswinlost, MatchId, IssueTypeId, TicketType, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,b.statusID
			,b.statuswinlost
			,t.MatchId
			,t.IssueTypeId
			,t.TicketType
			,t.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE b.statusID IN (0,1)
		
		IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds WHERE statuswinlost IS NOT NULL)
		BEGIN
			INSERT INTO #SingleTickets (TransId, RequestId, Matchid, IssueTypeId, TicketType, SiteDBGroupID)
			SELECT t.TransId, t.RequestId, t.Matchid, t.IssueTypeId, t.TicketType, t.SiteDBGroupID
			FROM #tmpTransIds t
			WHERE t.TicketType IN (1,4)
				AND t.statuswinlost IN (1,2)

			INSERT INTO #SingleTickets_ReSettle (TransId, RequestId, Matchid, IssueTypeId, TicketType, SiteDBGroupID)
			SELECT t.TransId, t.RequestId, t.Matchid, t.IssueTypeId, t.TicketType, t.SiteDBGroupID
			FROM #tmpTransIds t
			WHERE t.TicketType IN (1,4)
				AND t.statuswinlost IN (0,3,4)

			INSERT INTO #ParlayTickets (TransId, RequestId, MatchId, IssueTypeId, SiteDBGroupID)
			SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId, t.SiteDBGroupID
			FROM #tmpTransIds t
			WHERE t.TicketType = 2
				AND t.statuswinlost IN (1,2)

			INSERT INTO #ParlayTickets_ReSettle (TransId, RequestId, MatchId, IssueTypeId, SiteDBGroupID)
			SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId, t.SiteDBGroupID
			FROM #tmpTransIds t
			WHERE t.TicketType = 2
				AND t.statuswinlost IN (0,3,4)
		END

	END
	IF @IssueTypeId IN (11) AND @ActionId <> 1 --For: action auto void instant
	BEGIN
		INSERT INTO #SingleTickets (TransId, RequestId, Matchid, IssueTypeId, TicketType, transdate, winlostdate, statusId, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,t.TicketType
			,b.transdate
			,b.winlostdate
			,b.statusID
			,b.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType <> 2

		INSERT INTO #ParlayTickets (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,b.transdate
			,b.winlostdate
			,b.statusID
			,b.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType = 2

		IF EXISTS (SELECT TOP 1 1 FROM #tmpInputTransId t
					INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId)
		BEGIN
			INSERT INTO #SingleTickets_14 (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, SiteDBGroupID)
			SELECT t.TransId
				,t.RequestId
				,t.MatchId
				,t.IssueTypeId
				,b.transdate
				,b.winlostdate
				,b.statusID
				,b.SiteDBGroupID
			FROM #tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId AND b.bettype NOT IN (9,29,2799)

			INSERT INTO #ParlayTickets_14 (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, SiteDBGroupID)
			SELECT t.TransId
				,t.RequestId
				,t.MatchId
				,t.IssueTypeId
				,b.transdate
				,b.winlostdate
				,b.statusID
				,b.SiteDBGroupID
			FROM #tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId AND b.bettype IN (9,29,2799)
		END
	END
	IF @IssueTypeId IN (1,10,3,8,9,12,24,26) --Note For issuetype 1,10,3: case validate cancelCO & For issuetype 8,9,26: case auto void instant
	BEGIN
		INSERT INTO #tmpTransIds (TransId, RequestId, StatusID, betdaqid, MatchId, IssueTypeId, TicketType, transdate, winlostdate, CheckTimeCancelCashOut, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,b.statusID
			,b.betdaqid
			,CASE WHEN @IssueTypeId IN (8,9) THEN t.MatchId ELSE b.MatchId END
			,t.IssueTypeId
			,t.TicketType
			,b.transdate
			,b.winlostdate
			,CASE WHEN t.TicketType = 3 AND b.betdaqid = -2 THEN c.CheckTime ELSE NULL END
			,b.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
			LEFT JOIN dbo.CashOutSelling c WITH (NOLOCK) ON c.TransID = t.TransId 
		WHERE t.TicketType IN (1,3,4) AND b.statusID NOT IN (101,102,103)
		
		INSERT INTO #SingleTickets (TransId, RequestId, MatchId, IssueTypeId, TicketType, transdate, winlostdate, SiteDBGroupID)
		SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId, TicketType, t.transdate, t.winlostdate, t.SiteDBGroupID
		FROM #tmpTransIds t
		WHERE t.TicketType IN (1,4)

		INSERT INTO #ParlayTickets (TransId, RequestId, MatchId, IssueTypeId, transdate, winlostdate, SiteDBGroupID)
		SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId, bm.transdate, bm.winlostdate, bm.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.TransId = t.TransId
		WHERE t.TicketType = 2

		INSERT INTO #CancelCashOutTickets (TransId, RequestId, MatchId, IssueTypeId, transdate, winlostdate, CheckTimeCancelCashOut, SiteDBGroupID)
		SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId, transdate, winlostdate, CheckTimeCancelCashOut, t.SiteDBGroupID
		FROM #tmpTransIds t
		WHERE t.TicketType = 3 AND t.betdaqid = -2 --NO CARE cancel CO -> running
	END
	IF @IssueTypeId IN (13,20)
	BEGIN
		INSERT INTO #SingleTickets (TransId, RequestId, Matchid, IssueTypeId, TicketType, transdate, winlostdate, statusId, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,t.TicketType
			,b.transdate
			,b.winlostdate
			,b.statusID
			,b.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType <> 2

		INSERT INTO #ParlayTickets (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,b.transdate
			,b.winlostdate
			,b.statusID
			,b.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType = 2

		IF EXISTS (SELECT TOP 1 1 FROM #tmpInputTransId t
					INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId)
		BEGIN
			INSERT INTO #SingleTickets_14 (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, SiteDBGroupID)
			SELECT t.TransId
				,t.RequestId
				,t.MatchId
				,t.IssueTypeId
				,b.transdate
				,b.winlostdate
				,b.statusID
				,b.SiteDBGroupID
			FROM #tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId AND b.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))

			INSERT INTO #ParlayTickets_14 (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, SiteDBGroupID)
			SELECT t.TransId
				,t.RequestId
				,t.MatchId
				,t.IssueTypeId
				,b.transdate
				,b.winlostdate
				,b.statusID
				,b.SiteDBGroupID
			FROM #tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.TransId AND b.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
		END
	END
	IF @IssueTypeId IN (19,21,23) --ReducedOver Cricket, Not Participate, Abandoned
	BEGIN
		INSERT INTO #SingleTickets (TransId, RequestId, Matchid, IssueTypeId, TicketType, transdate, winlostdate, statusId, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,t.TicketType
			,b.transdate
			,b.winlostdate
			,b.statusID
			,b.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType <> 2
			AND b.statuswinlost IS NOT NULL

		INSERT INTO #ParlayTickets (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, SiteDBGroupID)
		SELECT t.TransId
			,t.RequestId
			,t.MatchId
			,t.IssueTypeId
			,b.transdate
			,b.winlostdate
			,b.statusID
			,b.SiteDBGroupID
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettransm b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType = 2
			AND b.statuswinlost IS NOT NULL
	END
	
	INSERT INTO #Tickets_Result (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, 1, SiteDBGroupID FROM #SingleTickets WHERE TicketType = 1 --SingleVoid

	INSERT INTO #Tickets_Result (TransId, RequestId, Matchid, IssueTypeId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, Matchid, IssueTypeId, 2, SiteDBGroupID FROM #SingleTickets_ReSettle WHERE TicketType = 1  --SingleReSettle

	INSERT INTO #Tickets_Result (TransId, RequestId, MatchId, IssueTypeId, transdate, winlostdate, statusId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, MatchId, IssueTypeId, transdate, winlostdate, statusId, 3, SiteDBGroupID FROM #ParlayTickets --Parlayvoid

	INSERT INTO #Tickets_Result (TransId, RequestId, MatchId, IssueTypeId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, MatchId, IssueTypeId, 4, SiteDBGroupID FROM #ParlayTickets_ReSettle --ParlayReSettle

	INSERT INTO #Tickets_Result (TransId, RequestId, Matchid, IssueTypeId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, Matchid, IssueTypeId, 5, SiteDBGroupID FROM #SingleTickets WHERE TicketType = 4 --CricketVoid

	INSERT INTO #Tickets_Result (TransId, RequestId, Matchid, IssueTypeId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, Matchid, IssueTypeId, 6, SiteDBGroupID FROM #SingleTickets_ReSettle WHERE TicketType = 4 --CricketReSettle

	INSERT INTO #Tickets_Result (TransId, RequestId, MatchId, IssueTypeId, ValidationType, transdate, winlostdate, CheckTimeCancelCashOut, SiteDBGroupID)
	SELECT TransId, RequestId, MatchId, IssueTypeId, 7, transdate, winlostdate, CheckTimeCancelCashOut, SiteDBGroupID FROM #CancelCashOutTickets --CancelCO

	INSERT INTO #Tickets_Result (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, 8, SiteDBGroupID FROM #SingleTickets_14 --Single_14Void

	INSERT INTO #Tickets_Result (TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, ValidationType, SiteDBGroupID)
	SELECT TransId, RequestId, Matchid, IssueTypeId, transdate, winlostdate, statusId, 9, SiteDBGroupID FROM #ParlayTickets_14 --Parlay_14Void

	SELECT TransId 
		, RequestId 
		, Matchid 
		, IssueTypeId 
		, TicketType 
		, transdate 
		, winlostdate 
		, statusId 
		, ValidationType
		, winlostdate
		, CheckTimeCancelCashOut
		, SiteDBGroupID
	FROM #Tickets_Result
	ORDER BY ValidationType

	DROP TABLE #tmpInputTransId
	DROP TABLE #tmpTransIds
	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
	DROP TABLE #SingleTickets_ReSettle
	DROP TABLE #ParlayTickets_ReSettle
	DROP TABLE #CancelCashOutTickets
	DROP TABLE #SingleTickets_14
	DROP TABLE #ParlayTickets_14
	DROP TABLE #Tickets_Result
END		
GO


