/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelHedge_Ticket]
	@HedgeMatchId		INT
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Get tickect Hedge match  [Redmine:#175251]

	Param's Explanation:
		
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsCentral BIT = 0
			,@IsDeterminedHedgeMatch BIT = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF EXISTS ( SELECT	TOP 1 CAST(1 AS BIT) AS IsDeterminedHedgeMatch
				FROM	dbo.bettrans b WITH(NOLOCK)
				WHERE	b.matchid = @HedgeMatchId
						AND b.bettype = 3
						AND b.ruben = 0
						AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
				)
	BEGIN
		SET @IsDeterminedHedgeMatch = 1
	END

	SELECT @IsDeterminedHedgeMatch AS IsDeterminedHedgeMatch

END
GO
