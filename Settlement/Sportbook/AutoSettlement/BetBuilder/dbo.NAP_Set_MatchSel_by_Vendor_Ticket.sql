/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel_by_Vendor_Ticket]
	@MatchIds VARCHAR(MAX) = ''
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @IsCentral BIT

	DECLARE @tmpMatchInQueue TABLE (MatchId INT, IsCalculating INT)
	
	CREATE TABLE #tmpMatchIds (matchid INT)
	
	INSERT INTO #tmpMatchIds(matchid)
	SELECT [Value] 
	FROM STRING_SPLIT(@MatchIds, ',')

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	--Get match info in queue
	;WITH cteQueueSingleMatch 
	AS (
		SELECT	m.matchid
				,MIN(IsCalculating)  IsCalculating
		FROM	dbo.Single_Calculate_Queue_3rd s WITH(NOLOCK)
			INNER JOIN #tmpMatchIds m 
				ON	m.matchid = s.matchid
		WHERE	s.Starttime > DATEADD(MINUTE,-10,GETDATE())
				AND s.IsCalculating IN (0,1)
		GROUP BY m.matchid
	)	
	INSERT INTO @tmpMatchInQueue(MatchId, IsCalculating)
	SELECT	q.matchid, q.IsCalculating
	FROM	cteQueueSingleMatch q
	
	;WITH cteBettrans 
	AS
	(		
		SELECT m.matchID
				,COUNT (*) AS totalTickets
		FROM	#tmpMatchIds m
			INNER JOIN dbo.Bettrans bt WITH (NOLOCK) 
				ON m.MatchID = bt.MatchID
		WHERE bt.Bettype  = 38
			AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
			AND bt.statusID NOT IN (101, 102)
		GROUP BY m.matchID
	)
	SELECT	m.matchID
			,ISNULL(b.totalTickets,0) AS totalTickets
			,ISNULL(q.IsCalculating, 2) AS QueueStatus
	FROM #tmpMatchIds m
		LEFT JOIN @tmpMatchInQueue q ON m.matchid= q.MatchId
		LEFT JOIN cteBettrans b ON m.MatchID = b.MatchID
END

