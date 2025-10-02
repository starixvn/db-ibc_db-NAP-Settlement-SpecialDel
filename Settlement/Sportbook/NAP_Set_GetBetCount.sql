/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GetBetCount
	@MatchId	INT
	,@SportType INT = 0
	,@SettleType VARCHAR(10) = 'EAR'
AS
/*
    Created by: 20250822@Louisa
    Task: Basketball Player Prop [Redmine:#233012]
    DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
    
    Revisions:            
		- 20250822@Louisa: Get bet count [Redmine:#233012]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpTicketStatus TABLE	(ResourceID VARCHAR(20), BetCount INT)
    DECLARE @tmpTicketStatusParlay TABLE(ResourceID VARCHAR(20), BetCount INT)
    DECLARE @tblReturnTable TABLE (	ResourceID VARCHAR(20),BetCount INT)

	DECLARE  @IsCentral			BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @sporttype = 2
	BEGIN
		INSERT INTO @tmpTicketStatus (ResourceID, BetCount)
		SELECT  CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
			END AS ResourceID
			,COUNT(1) AS BetCount
		FROM bettrans bt WITH (NOLOCK)
			INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bt.Bettype
		WHERE bt.matchid = @matchid
    		AND (sp.Betid = 0 OR sp.BetID = bt.BetID)
    		AND 1 =  CASE WHEN sp.Betid = 0 THEN 1
							  WHEN sp.BetID = bt.Betid AND bt.bettype NOT IN (675,676,678 ) THEN 1
							  WHEN bt.bettype IN (675,676,678 ) AND sp.BetID = bt.Betid  AND bt.betteam = RIGHT(sp.ResourceID, 2) THEN 1
							 ELSE 0 
						END
			AND bt.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupId END
			AND bt.statusID IN (0,1,111,112,113,103) 
			AND sp.sporttype = @SportType
			AND (sp.Settletype = @SettleType)	
		GROUP BY CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END

		
		INSERT INTO @tmpTicketStatusParlay(ResourceID, BetCount)
		SELECT CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END     
				,COUNT(1) AS BetCount
		FROM    dbo.Bettransm bm WITH (NOLOCK)
			INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bm.Bettype
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON	b.matchid = 29
					AND b.bettype = 29
					AND b.refno = bm.refno
		WHERE   bm.matchID = @MatchID
				AND b.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupId END
				AND bm.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupId END
	    		AND bm.statusID IN (0,1,111,112,113,103) 
	    		AND (sp.Betid = 0 OR sp.BetID = bm.Betcheck)
	    		AND 1 =  CASE WHEN sp.Betid = 0 THEN 1
							  WHEN sp.BetID = bm.Betcheck AND bm.bettype NOT IN (675,676,678 ) THEN 1
							  WHEN bm.bettype IN (675,676,678 ) AND sp.BetID = bm.Betcheck  AND bm.betteam = RIGHT(sp.ResourceID, 2) THEN 1
							 ELSE 0 
						END
				AND sp.sporttype = @sporttype
				AND sp.Settletype = @Settletype
		GROUP BY CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END 

	END

	INSERT INTO @tblReturnTable(ResourceID,BetCount)
	SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
			,ISNULL(bt.BetCount, 0) + ISNULL(p.BetCount, 0) AS BetCount
	FROM @tmpTicketStatus bt
	  		FULL JOIN @tmpTicketStatusParlay p ON bt.resourceId = p.ResourceID

	SELECT ResourceID
		,BetCount
	FROM @tblReturnTable

END
GO