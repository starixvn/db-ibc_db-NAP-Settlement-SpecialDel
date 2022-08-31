/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_Match_FirstTicketTime_Select]
	@MatchId INT = 0
AS
/*
    Created by: Alan
	Date: 20190327
	Task: Get First Ticket Time 
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20190327@Alan: - Get First Ticket Time [108826]
		- 20190510@Alan: - Get Kick Off Time [112480]
		- 20190521@Raymond.Le: - Return 2001/1/1 when KOTime is null [113518]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @MinTransDate	DATETIME
		   ,@KickOffTime	DATETIME
		   ,@SiteDBGroupID	INT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	;WITH cte_transdate
	AS (
		SELECT b.transdate
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.matchid = @MatchId AND b.SiteDBGroupID = @SiteDBGroupID
		
		UNION
		SELECT bm.transdate
		FROM dbo.bettransm AS bm WITH (NOLOCK)
		WHERE bm.matchid = @MatchId AND bm.SiteDBGroupID = @SiteDBGroupID
		)
	SELECT @MinTransDate = MIN(t.transdate)
	FROM cte_transdate AS t

	SELECT @KickOffTime = ISNULL(kickofftime, '2001-01-01 00:00:00')
	FROM dbo.[match] WITH (NOLOCK)
	WHERE matchid = @MatchId;

	SELECT @MinTransDate AS MinTransDate
		  ,@KickOffTime AS KickOffTime

	SET NOCOUNT OFF;
END
