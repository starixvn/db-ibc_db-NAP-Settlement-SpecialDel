/*<info serverAlias="DBPRO-bodb02" executers="vnSAS"></info>*/
CREATE PROCEDURE [dbo].[SAS_NAP_Set_UpdMatchScore]
	@MatchId INT
	,@fth INT
	,@fta INT
AS
/*
	Creator:	20230119@Kathy
	Task:		support SAS update match score
	Database:	DBPRO.bodb02

	Revisions:
		- 20230119@Kathy:	support SAS update match score
		
*/
BEGIN;

	SET NOCOUNT ON;

	UPDATE dbo.match WITH(ROWLOCK, UPDLOCK)
		SET finalhomescore = @fth
			,finalawayscore = @fta
	WHERE	matchid = @MatchId

END
GO
