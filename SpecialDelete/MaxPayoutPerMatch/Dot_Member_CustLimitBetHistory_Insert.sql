/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Member_CustLimitBetHistory_Insert]
(
	@MatchId		INT
	,@sporttype		SMALLINT
	,@custid		INT
	,@sitetype		TINYINT
	,@bettype		SMALLINT
	,@Transid		BIGINT = 0
	,@payout		MONEY
	,@turnover		MONEY
	,@EventTypeID	TINYINT = NULL
	,@BRID			BIGINT = 0
)
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20220317@Max: Support Max Payout & Max Turnover for Deposit - [Redmine: #167898]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	IF @EventTypeID IS NULL
	BEGIN
		SET @EventTypeID = CASE WHEN @bettype = 10 THEN 2 ELSE 1 END
	END

	IF (@sporttype > 99 AND @sporttype NOT IN (164,180,186) AND (@sporttype NOT BETWEEN 190 AND 197))
		OR (@bettype IN(2799)) OR (@bettype BETWEEN 801 AND 806)
	BEGIN
		RETURN
	END
	ELSE IF (EXISTS (SELECT 1 FROM dbo.f_CustLimitBet_AccumPayout_Exclude() WHERE Bettype = @bettype)) 
		OR (@sporttype IN (43,44) AND @sitetype <> 3) 
		OR (@sporttype IN (164,180,186)) 
		OR (@sporttype BETWEEN 190 AND 197)
	BEGIN
		SET @payout = 0
	END

	IF @sitetype = 1 --MBC
	BEGIN
		--CustLimitBetHisoty
		INSERT INTO dbo.CustLimitBetHistory_MBC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, BRID)
		SELECT @custid AS CustId
			, @MatchId AS MatchId
			, ISNULL(@Transid, 0) AS TransId
			, @turnover  AS TurnoverAdjust
			, @payout AS PayoutAdjust
			, @EventTypeID AS EventTypeID
			, ISNULL(@BRID, 0) AS TransId 
		
	END
	ELSE IF @sitetype = 2 --789y
	BEGIN
		--CustLimitBetHisoty
		INSERT INTO dbo.CustLimitBetHistory_789 (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, BRID)
		SELECT @custid AS CustId
			, @MatchId AS MatchId
			, ISNULL(@Transid, 0) AS TransId
			, @turnover  AS TurnoverAdjust
			, @payout AS PayoutAdjust
			, @EventTypeID AS EventTypeID
			, ISNULL(@BRID, 0) AS TransId
	END
	ELSE IF @sitetype = 3  --licensee
	BEGIN
		--CustLimitBetHisoty
		INSERT INTO dbo.CustLimitBetHistory_LIC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, BRID)
		SELECT @custid AS CustId
			, @MatchId AS MatchId
			, ISNULL(@Transid, 0) AS TransId
			, @turnover  AS TurnoverAdjust
			, @payout AS PayoutAdjust
			, @EventTypeID AS EventTypeID
			, ISNULL(@BRID, 0) AS TransId
	END
END
GO
	