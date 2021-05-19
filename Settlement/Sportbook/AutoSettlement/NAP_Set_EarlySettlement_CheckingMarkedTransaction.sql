/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_EarlySettlement_CheckingMarkedTransaction]
    @MatchID				INT
	,@ResourceIDs			VARCHAR(MAX)
	,@isExistMarkedTicket	BIT = 0 			OUTPUT
	,@ErrCode				INT = 0 			OUTPUT
	,@ErrMsg				VARCHAR(MAX) = '' 	OUTPUT
	,@IsMergedParlay		BIT = 0
AS
/*    
	Creator: Kathy
    Date: 20190320
    Task: Check marked ticket [Redmine:#106823]
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190702@Kathy: PH AIO phase 4 [Redmine:#115232]
		- 20200515@Kathy: Settlement Exclusion [Redmine:#134103]
		- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]

    Param's Explanation:
		@ResourceIDs: '135,168,16001,16002'
*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SportType		SMALLINT

	DECLARE @tmpBettype TABLE (bettype SMALLINT, ResourceId VARCHAR(20), BetId BIGINT)
	DECLARE @tmpResourceIds TABLE (ResourceId VARCHAR(20))

	SELECT	@SportType = sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchID

	INSERT INTO @tmpResourceIds(ResourceID)
	SELECT	CAST(val AS VARCHAR(20)) AS ResourceID
	FROM	dbo.f_SplitString(@ResourceIDs,',')
	OPTION (MAXRECURSION 0)

	IF EXISTS (SELECT TOP 1 1 FROM @tmpResourceIds WHERE ResourceID = '00') AND @SportType = 9
	BEGIN
		INSERT INTO @tmpResourceIds(ResourceID) VALUES('70400')
	END

	INSERT INTO @tmpBettype(ResourceID, BetType, BetID)
	SELECT DISTINCT c.ResourceID, sp.BetType, sp.BetID
	FROM @tmpResourceIds c
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
			ON	sp.ResourceID = c.ResourceID
	WHERE	sp.SportType = @SportType 

	INSERT INTO @tmpBettype(ResourceId, bettype, BetId)
	SELECT	c.ResourceId, sp.BetType, sp.BetID
	FROM	@tmpResourceIds c
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			ON c.ResourceId = sp.RefResourceId
	WHERE	sp.SportType = @SportType
			AND sp.RefResourceId IS NOT NULL

	IF EXISTS (
		SELECT	TOP 1 1
		FROM	dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	b.transid = mt.TransId
		WHERE	b.matchid = @MatchID
				AND b.statusID NOT IN (101, 102)
				AND EXISTS (SELECT TOP 1 1 FROM @tmpBettype t WHERE t.bettype = b.bettype AND (t.BetId = 0 OR t.BetId = b.betid))
	)
	BEGIN
		SET @isExistMarkedTicket = 1
				
	END
	ELSE IF @IsMergedParlay = 1
	BEGIN
		IF EXISTS (SELECT TOP 1 1
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						CROSS APPLY (
							SELECT TOP 1 b.refno
									,b.statusID
									,b.matchid
							FROM	dbo.bettrans b WITH(NOLOCK)
							WHERE	b.transid = mt.TransId
									AND b.matchid = 29
						) b							
						CROSS APPLY (
							SELECT TOP 1 bm.transid
							FROM	dbo.bettransm bm WITH(NOLOCK)
							WHERE	bm.matchid = mt.matchid
									AND bm.refno = b.refno
									AND bm.statusID = 0
									AND EXISTS (SELECT TOP 1 1 FROM @tmpBettype t WHERE t.bettype = bm.bettype AND (t.BetId = 0 OR t.BetId = bm.betcheck))
						)bm
					WHERE	mt.MatchId = @MatchID
		)
			SET @isExistMarkedTicket = 1
	END

	IF @isExistMarkedTicket = 1
		SELECT	@ErrCode = 1001032
				,@ErrMsg = 'ERROR! Cannot proceed due to marked tickets. Please unmark them and try again.'
END
GO