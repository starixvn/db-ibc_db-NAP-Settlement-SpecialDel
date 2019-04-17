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
	
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatchId TABLE (MatchId INT)

	INSERT INTO @tmpMatchId (MatchId)
	SELECT	val AS MatchId
	FROM	dbo.f_SplitString(@MatchIds, ',')
	OPTION (maxrecursion 0)

	SELECT	m.MatchId, o.OperatorID, ci.username, o.OperatorType
	FROM	@tmpMatchId m
		CROSS APPLY(
			SELECT	DISTINCT o.OperatorID, o.OperatorType
			FROM	dbo.Dot_admin_Assignment_Operator o WITH(NOLOCK)
			WHERE	m.MatchId = o.matchid
		) o		
		INNER JOIN dbo.CustInfo ci WITH(NOLOCK)
			ON o.OperatorID = ci.custid	
END
GO

