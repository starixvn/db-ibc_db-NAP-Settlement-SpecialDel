/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member,svc_tig" isFunction="0"></info>*/
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
	,@EventTypeID	TINYINT = NULL
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
		- 20230905@Louisa: Support Max Payout for VS3 [Redmine:#193562]
		- 20240118@Louisa: VS4 - Cock Fighting [Redmine:#199700]
		- 20240808@Max: Max Payout - Integrate Virtually Sports (VS5) [Redmine: #209070]
		- 20240923@Max: Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing [Redmine: #211145]
		- 20241031@Max: VS6 (Betby) - Company Max Payout & Max Payout Per Match [Redmine: #212547]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	IF @EventTypeID IS NULL
	BEGIN
		SET @EventTypeID = CASE WHEN @bettype = 10 THEN 2 ELSE 1 END
	END

	IF (@sporttype > 99 AND @sporttype NOT IN (164,178,179,180,186,188,147,177,134) AND (@sporttype NOT BETWEEN 190 AND 198))
		OR (@bettype IN(2799,10449,11099)) OR (@bettype BETWEEN 801 AND 806)
	BEGIN
		RETURN
	END
	ELSE IF (EXISTS (SELECT 1 FROM dbo.f_CustLimitBet_AccumPayout_Exclude() WHERE Bettype = @bettype)) 
		OR (@sporttype IN (43,44) AND @sitetype <> 3) 
		OR (@sporttype IN (164,178,179,180,186,188,147,177,134)) 
		OR (@sporttype BETWEEN 190 AND 198)
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
	ELSE IF @sitetype = 3  --licensee
	BEGIN
		--CustLimitBetHisoty
		INSERT INTO dbo.CustLimitBetHistory_LIC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
		SELECT @custid AS CustId
			, @MatchId AS MatchId
			, @Transid AS TransId
			, @turnover  AS TurnoverAdjust
			, @payout AS PayoutAdjust
			, @EventTypeID AS EventTypeID
	END
END
GO
	