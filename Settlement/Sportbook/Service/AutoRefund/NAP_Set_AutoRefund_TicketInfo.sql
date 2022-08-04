/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_TicketInfo
	@MatchId INT
	, @TypeId TINYINT
AS
/*
	Created by: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBTXN/BODB02
	
	Revisions:
		- 20220719@Louisa: Check ticket Auto Refund [Redmine:#175251]

	Param's Explanation:	
	
	Param's explaination: 
	- @TypeId:   1 - Auto refund single
				10 - Auto refund parlay
*/
BEGIN
	SET NOCOUNT ON

	DECLARE   @IsExistMarkedTicket	BIT
			, @IsExistSettledTicket	BIT
			, @IsRefundedSingle		BIT
			, @IsCentral			BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @TypeId = 1
	BEGIN
		SELECT @IsExistMarkedTicket		= MAX(CASE WHEN btr.statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END)
				,@IsExistSettledTicket  = MAX(CASE WHEN btr.statusID IN (103, 111, 112, 113) AND mt.TransId IS NULL THEN 1 ELSE 0 END)
		FROM dbo.bettrans btr  WITH(NOLOCK)
			OUTER APPLY ( SELECT TOP 1 TransId FROM dbo.MarkedTransaction mt  WITH(NOLOCK) WHERE btr.transID = mt.TransId ) mt
		WHERE btr.statusID IN ( 0 , 103, 111, 112, 113)
			AND btr.matchid = @MatchId
			AND ISNULL(btr.betdaqid,0) <> -2
			AND btr.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE btr.SiteDBGroupID END
	END
	
	SELECT	ISNULL(@IsExistMarkedTicket,0)  AS IsExistMarkedTicket	
			, ISNULL(@IsExistSettledTicket,0) AS IsExistSettledTicket

END
GO