/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].NAP_Set_CheckingMarkedTransaction_OtherSports
    @MatchID        INT
	,@ResourceIDs	VARCHAR(MAX)
AS
/*    
	Creator: Sol
    Date: 20200203
    Task: Check marked ticket [Redmine:#126963]
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
		- 20200203@Sol: Settlement with Tickets Exclusion [Redmine:#126963]
		
    Param's Explanation:
		@ResourceIDs: '135,168,16001,16002'
*/ 
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistMarkedTicket	BIT
			,@SportType				SMALLINT

	DECLARE @tmpBettype TABLE (bettype SMALLINT, ResourceId VARCHAR(20), BetId BIGINT)

	SELECT	@SportType = sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchID

	;WITH cteResource
	AS(
		SELECT	CAST(val AS VARCHAR(20)) AS ResourceID
		FROM	dbo.f_SplitString(@ResourceIDs,',')
	)
	INSERT INTO @tmpBettype(ResourceID, BetType, BetID)
	SELECT DISTINCT c.ResourceID, sp.BetType, sp.BetID
	FROM	cteResource c
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
			ON sp.ResourceID = c.ResourceID
	WHERE	sp.SportType = @SportType 
	OPTION (MAXRECURSION 0)

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

	SELECT @isExistMarkedTicket AS isExistMarkedTicket
END
GO