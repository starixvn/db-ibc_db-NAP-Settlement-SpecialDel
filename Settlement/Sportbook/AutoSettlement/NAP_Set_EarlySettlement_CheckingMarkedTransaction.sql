/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_EarlySettlement_CheckingMarkedTransaction]
    @MatchID				INT
	,@ResourceIDs			VARCHAR(MAX)
	,@isExistMarkedTicket	BIT = 0 			OUTPUT
	,@ErrCode				INT = 0 			OUTPUT
	,@ErrMsg				VARCHAR(MAX) = '' 	OUTPUT
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
		SELECT @isExistMarkedTicket = 1
				,@ErrCode = 1001032
				,@ErrMsg = 'ERROR! Cannot proceed due to marked tickets. Please unmark them and try again.'
	END
END
GO