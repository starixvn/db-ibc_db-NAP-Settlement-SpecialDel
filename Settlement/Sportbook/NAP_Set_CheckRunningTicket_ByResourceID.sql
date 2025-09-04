/*<info serverAlias="DBSIG-bodb02,DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Set_CheckRunningTicket_ByResourceID
	 @MatchID INT
	,@Sporttype	SMALLINT
	,@ResourceIDs VARCHAR(MAX)
	,@IsExistsTicket BIT = 0 OUTPUT
AS
/*
    Created by: 20240605@Louisa
    Date: 20240605
    Task: Notify if not yet refund [Redmine:#204909] 
    
    Revisions:
        - 20240605@Louisa: Checking running ticket [Redmine:#204909]   
		- 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsCentral	BIT = 0
	
	DECLARE @tmp_Bettype TABLE ( Bettype SMALLINT, BetID BIGINT, ResourceID VARCHAR(50) )
	DECLARE @tmp_ResourceID TABLE ( ResourceID VARCHAR(20) )
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	INSERT INTO @tmp_ResourceID ( ResourceID  )
	SELECT value FROM STRING_SPLIT(@ResourceIDs, ',')

	INSERT INTO @tmp_Bettype ( Bettype, BetID, ResourceID )
	SELECT sp.Bettype
			,sp.BetID
			,sp.ResourceID
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
	INNER JOIN @tmp_ResourceID r ON sp.ResourceID = r.ResourceID
		AND sp.SportType = @Sporttype

	INSERT INTO @tmp_Bettype ( Bettype, BetID, ResourceID )
	SELECT sp.Bettype
			,sp.BetID
			,sp.ResourceID
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
	INNER JOIN @tmp_ResourceID r ON sp.RefResourceId = r.ResourceID
		AND sp.SportType = @Sporttype
		AND ISNULL(RefResourceId,'') <> ''

	SELECT @IsExistsTicket = ISNULL(( SELECT TOP 1 1
											FROM dbo.bettrans b WITH(NOLOCK)
												INNER JOIN @tmp_Bettype tmp 
													ON b.bettype  = tmp.bettype
														AND ( tmp.BetID = 0 
																OR (tmp.BetID = b.BetID AND b.bettype NOT IN (675,676,678 )) 
																OR ( b.bettype IN (675,676,678 ) AND tmp.BetID = b.Betid  AND b.betteam = RIGHT(tmp.ResourceID, 2)) 
															)

											WHERE b.matchid = @MatchID
											),0)
	IF @IsExistsTicket = 0
	BEGIN
		SELECT @IsExistsTicket = ISNULL(( SELECT TOP 1 1
											FROM dbo.bettransm b WITH(NOLOCK)
												INNER JOIN @tmp_Bettype tmp 
													ON b.bettype  = tmp.bettype
														AND ( tmp.BetID = 0
																OR (tmp.BetID = b.betcheck AND b.bettype NOT IN (675,676,678 )) 
																OR ( b.bettype IN (675,676,678 ) AND tmp.BetID = b.betcheck  AND b.betteam = RIGHT(tmp.ResourceID, 2) ) 
															)
											WHERE b.matchid = @MatchID
											),0)
	END
END
GO