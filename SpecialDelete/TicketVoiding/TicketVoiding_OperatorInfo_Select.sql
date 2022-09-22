/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_OperatorInfo_Select] 
	@MatchIds VARCHAR(50)
AS
/*	Created by: Kathy
	Date 20181212
	Task: list operator of match [Redmine:#90155]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20211101@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine:#155792]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatchId TABLE (MatchId INT)

	INSERT INTO @tmpMatchId (MatchId)
	SELECT	value AS MatchId
	FROM STRING_SPLIT(@MatchIds, ',')

	SELECT	m.MatchId, o.TraderID, o.TraderName, o.SuspenderID, o.SuspenderName
	FROM	@tmpMatchId m
		CROSS APPLY(
			SELECT DISTINCT dt.TraderID
				, ct.username AS TraderName
				, dt.SuspenderID
				, cs.username AS SuspenderName
			FROM Dot_Admin_Assignment_Trader dt WITH (NOLOCK)
				LEFT JOIN dbo.CustInfo ct WITH (NOLOCK) ON ct.custid = dt.TraderID
				LEFT JOIN dbo.CustInfo cs WITH (NOLOCK) ON cs.custid = dt.SuspenderID
			WHERE dt.matchid = m.MatchId
		) o	
	ORDER BY o.TraderName ASC
END
GO

