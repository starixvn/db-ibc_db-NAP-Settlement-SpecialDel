/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Member_CustLimitBetHistory_Insert]
(
	@MatchId		INT
	,@sporttype		SMALLINT
	,@custid		INT
	,@sitetype		TINYINT
	,@bettype		SMALLINT
	,@Transid		BIGINT
	,@payout		MONEY
	,@turnover		MONEY
)
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @EventTypeID TINYINT
	SET @EventTypeID = CASE WHEN @bettype = 10 THEN 2 ELSE 1 END

	IF (@sporttype > 99 AND @sporttype NOT IN (164,168,180,186) AND (@sporttype NOT BETWEEN 190 AND 197))
		OR (@bettype IN(29, 2799, 38)) OR (@bettype BETWEEN 801 AND 806)
	BEGIN
		RETURN
	END
	ELSE IF (EXISTS (SELECT 1 FROM dbo.f_CustLimitBet_AccumPayout_Exclude() WHERE Bettype = @bettype)) OR (@sporttype IN (43,44,164,168,180,186)) OR (@sporttype BETWEEN 190 AND 197)
	BEGIN
		SET @payout = 0
	END

	IF @sitetype = 1 --MBC
	BEGIN
		--CustLimitBetHisoty
		INSERT INTO dbo.CustLimitBetHistory_MBC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
		SELECT @custid AS CustId
			, @MatchId AS MatchId
			, @Transid AS TransId
			, @turnover  AS TurnoverAdjust
			, @payout AS PayoutAdjust
			, @EventTypeID AS EventTypeID
		
	END
	ELSE IF @sitetype = 2 --789y
	BEGIN
		--CustLimitBetHisoty
		INSERT INTO dbo.CustLimitBetHistory_789 (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
		SELECT @custid AS CustId
			, @MatchId AS MatchId
			, @Transid AS TransId
			, @turnover  AS TurnoverAdjust
			, @payout AS PayoutAdjust
			, @EventTypeID AS EventTypeID
	END
END
GO
	