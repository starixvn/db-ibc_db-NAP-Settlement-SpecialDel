/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoInstant_GetTicketInfo]
	 @MatchId		INT	
AS
/*
	Created by: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBTXN/BODB02
	
	Revisions:
		- 20220719@Louisa: Check ticket FGLG for Auto Instant [Redmine:#175251]

	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsCentral BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	;WITH cteBetTickets
	AS (
		SELECT	bettype, MAX(CASE WHEN RIGHT(betteam,1) = '1' THEN 1 ELSE 0 END) AS IsExistsFG 
		FROM	dbo.bettrans WITH(NOLOCK)
		WHERE	matchid = @MatchId
				AND bettype IN (14, 127)
				AND statusID NOT IN (101, 102)
				AND betteam IN ('1:1', '2:1', '0:0')
				AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		GROUP BY bettype
	)
	SELECT	MAX(CASE WHEN bettype = 14 THEN 1 ELSE 0 END) AS IsExistFGNG
			,MAX(CASE WHEN bettype = 127 THEN 1 ELSE 0 END) AS IsExistHTFGNG

			,MAX(CASE WHEN bettype = 14 AND IsExistsFG = 1 THEN 1 ELSE 0 END) AS IsExistFG
			,MAX(CASE WHEN bettype = 127 AND IsExistsFG = 1 THEN 1 ELSE 0 END) AS IsExistHTFG
	FROM	cteBetTickets

END
GO