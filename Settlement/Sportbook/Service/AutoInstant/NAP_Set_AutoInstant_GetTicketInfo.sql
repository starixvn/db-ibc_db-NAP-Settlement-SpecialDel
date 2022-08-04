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

		SELECT MAX(CASE WHEN Bettype = 14 THEN 1 ELSE 0 END) AS IsExistFGNG
			  , MAX(CASE WHEN Bettype = 127 THEN 1 ELSE 0 END) AS IsExistHTFGNG
		  FROM dbo.bettrans b WITH(NOLOCK)
		  WHERE b.MatchID = @MatchID
			 AND b.Bettype IN (14, 127)
			 AND b.StatusID NOT IN (101, 102)
			 AND b.Betteam IN ('1:1', '2:1', '0:0')
			 AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

END
GO