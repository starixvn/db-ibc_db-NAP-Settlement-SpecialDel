/*<info serverAlias="DBSIG-bodb02,DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Set_CheckRunningTicket_ByResourceID
	@MatchID INT
	,@ResourceIDs VARCHAR(MAX)
	,@IsExistsTicket BIT = 0 OUTPUT
AS
/*
    Created by: 20240605@Louisa
    Date: 20240605
    Task: Notify if not yet refund [Redmine:#204909] 
    
    Revisions:
        - 20240605@Louisa: Checking running ticket [Redmine:#204909]   
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Sporttype	TINYINT
			,@IsCentral	BIT = 0
	
	DECLARE @tmp_Bettype TABLE ( Bettype SMALLINT, BetID BIGINT )
	DECLARE @tmp_ResourceID TABLE ( ResourceID VARCHAR(20) )
	
	SELECT @Sporttype = m.sporttype FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchID
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	INSERT INTO @tmp_ResourceID ( ResourceID  )
	SELECT value FROM STRING_SPLIT(@ResourceIDs, ',')

	INSERT INTO @tmp_Bettype ( Bettype, BetID )
	SELECT sp.Bettype
			,sp.BetID
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
	INNER JOIN @tmp_ResourceID r ON sp.ResourceID = r.ResourceID
		AND sp.SportType = @Sporttype

	INSERT INTO @tmp_Bettype ( Bettype, BetID )
	SELECT sp.Bettype
			,sp.BetID
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
	INNER JOIN @tmp_ResourceID r ON sp.RefResourceId = r.ResourceID
		AND sp.SportType = @Sporttype
		AND ISNULL(RefResourceId,'') <> ''

	SELECT @IsExistsTicket = ISNULL(( SELECT TOP 1 1
											FROM dbo.bettrans b WITH(NOLOCK)
												INNER JOIN @tmp_Bettype tmp 
													ON b.bettype  = tmp.bettype
														AND ( tmp.BetID = 0 OR b.betid = tmp.BetID )
											WHERE b.matchid = @MatchID
											),0)
	IF @IsExistsTicket = 0
	BEGIN
		SELECT @IsExistsTicket = ISNULL(( SELECT TOP 1 1
											FROM dbo.bettransm b WITH(NOLOCK)
												INNER JOIN @tmp_Bettype tmp 
													ON b.bettype  = tmp.bettype
														AND ( tmp.BetID = 0 OR b.betcheck = tmp.BetID )
											WHERE b.matchid = @MatchID
											),0)
	END
END
GO