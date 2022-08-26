/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_50_MoveTicketInfo
	@MatchId		INT
AS
/*	Creator: 20220719@Louisa
	Task: Scale out DBTRANS [Redmine:#175251]
	DB: DBPRO/BODB02

	Revisions:
		- 20220719@Louisa: Get child match, result [Redmine:#175251]

	Param's Explanation:
		@matchid: main matchid Cricket
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @eventdate DATETIME
			,@ChildMatchId	INT
			,@ResourceIds VARCHAR(MAX) = ''

	SELECT @eventdate = m.eventdate
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @matchid

	SELECT @ChildMatchId = m.matchid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.ParentID = @MatchId
			AND m.ChildMatchType = 200
			AND m.eventdate = @eventdate
			AND ISNULL(m.IsDeleted,0) = 0
	ORDER BY m.matchid

	SELECT @ResourceIds = @ResourceIds + ','  + r.ResourceID
	FROM (
			SELECT	ResourceID 
			FROM dbo.ResultDetailOS WITH(NOLOCK)
			WHERE	matchid = @MatchId
					AND ResultStatusID = 5
		) r

	SET @ResourceIds =  SUBSTRING(@ResourceIds, 2, LEN(@ResourceIds))

	SELECT @eventdate  AS eventdate, @ChildMatchId  AS ChildMatchId, @ResourceIds AS Resources
	
END
GO