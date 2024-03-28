/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member,svc_tig" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Member_CustLimitBet_Insert]
(
	@MatchId		INT
	,@sporttype		SMALLINT
	,@custid		INT
	,@sitetype		TINYINT
	,@bettype		SMALLINT
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
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	IF @EventTypeID IS NULL
	BEGIN
		SET @EventTypeID = CASE WHEN @bettype = 10 THEN 2 ELSE 1 END
	END
	

	IF (@sporttype > 99 AND @sporttype NOT IN (164,178,179,180,186,188) AND (@sporttype NOT BETWEEN 190 AND 197))
		OR (@bettype IN(2799,10449)) OR (@bettype BETWEEN 801 AND 806)
	BEGIN
		RETURN
	END
	ELSE IF (EXISTS (SELECT 1 FROM dbo.f_CustLimitBet_AccumPayout_Exclude() WHERE Bettype = @bettype)) 
		OR (@sporttype IN (43,44) AND @sitetype <> 3)
		OR (@sporttype IN (164,178,179,180,186,188)) 
		OR (@sporttype BETWEEN 190 AND 197)
	BEGIN
		SET @payout = 0
	END

	IF @sitetype = 1 --MBC
	BEGIN
		--CustLimitBet
		IF NOT EXISTS (SELECT 1 FROM dbo.CustLimitBet_MBC cm WITH (NOLOCK) WHERE cm.CustID = @custid AND cm.Matchid = @MatchId AND cm.EventTypeID = @EventTypeID)
		BEGIN
			INSERT INTO dbo.CustLimitBet_MBC (CustID, Matchid, AccumTurnover, AccumPayout, EventTypeID, ModifiedDate)
			SELECT @custid, @MatchId, @turnover, @payout, @EventTypeID, GETDATE()
		END
		ELSE
		BEGIN
			UPDATE cm WITH (ROWLOCK, UPDLOCK) 
				SET cm.AccumTurnover = cm.AccumTurnover + @turnover
					, cm.AccumPayout = cm.AccumPayout + @payout
					, cm.ModifiedDate = GETDATE()
			FROM dbo.CustLimitBet_MBC cm
			WHERE cm.CustID = @custid AND cm.Matchid = @MatchId AND cm.EventTypeID = @EventTypeID 
		END		
	END
	ELSE IF @sitetype = 2 --789y
	BEGIN
		--CustLimitBet
		IF NOT EXISTS (SELECT 1 FROM dbo.CustLimitBet_789 cm WITH (NOLOCK) WHERE cm.CustID = @custid AND cm.Matchid = @MatchId AND cm.EventTypeID = @EventTypeID)
		BEGIN
			INSERT INTO dbo.CustLimitBet_789 (CustID, Matchid, AccumTurnover, AccumPayout, EventTypeID, ModifiedDate)
			SELECT @custid, @MatchId, @turnover, @payout, @EventTypeID, GETDATE()
		END
		ELSE
		BEGIN
			UPDATE cm WITH (ROWLOCK, UPDLOCK) 
				SET cm.AccumTurnover = cm.AccumTurnover + @turnover
					, cm.AccumPayout = cm.AccumPayout + @payout
					, cm.ModifiedDate = GETDATE()
			FROM dbo.CustLimitBet_789 cm
			WHERE cm.CustID = @custid AND cm.Matchid = @MatchId AND cm.EventTypeID = @EventTypeID 
		END
	END
	ELSE IF @sitetype = 3 --licensee
	BEGIN
		--CustLimitBet
		IF NOT EXISTS (SELECT 1 FROM dbo.CustLimitBet_LIC cm WITH (NOLOCK) WHERE cm.CustID = @custid AND cm.Matchid = @MatchId AND cm.EventTypeID = @EventTypeID)
		BEGIN
			INSERT INTO dbo.CustLimitBet_LIC (CustID, Matchid, AccumTurnover, AccumPayout, EventTypeID, ModifiedDate)
			SELECT @custid, @MatchId, @turnover, @payout, @EventTypeID, GETDATE()
		END
		ELSE
		BEGIN
			UPDATE cm WITH (ROWLOCK, UPDLOCK) 
				SET cm.AccumTurnover = cm.AccumTurnover + @turnover
					, cm.AccumPayout = cm.AccumPayout + @payout
					, cm.ModifiedDate = GETDATE()
			FROM dbo.CustLimitBet_LIC cm
			WHERE cm.CustID = @custid AND cm.Matchid = @MatchId AND cm.EventTypeID = @EventTypeID 
		END		
	END
END
GO
	