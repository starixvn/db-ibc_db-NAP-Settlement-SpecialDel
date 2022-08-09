/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Match_s164_Upd
	@MatchID	INT
	,@IsAuto	BIT = 0
	--,@Sporttype	SMALLINT
	,@Resources	VARCHAR(MAX)
	--,@Command	VARCHAR(100) = 'profile_bingoball'
	,@Action	VARCHAR(10)
	,@AdminId	INT = 0
AS
/*
	Creator: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBTXN/bodb02
	Revisions:		
		- 20201216@Louisa: Update match/reult info Happy5 [Redmine:#175251]
	Param's explaination: 
		@Resources:   <Resources>
							<Resource Id="1" Result="1"/>
							<Resource Id="2" Result="2"/>
							<Resource Id="3" Result="3"/>
							<Resource Id="4" Result="4"/>
							<Resource Id="5" Result="5"/>
						</Resources>
		@IsAuto:
			0: settle by service
			1: manual re-calculate
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tblSelectedRID TABLE (ResourceID TINYINT, Result TINYINT)
	DECLARE @handle INT, @IsTest INT, @Sporttype TINYINT
	 
	----------------------------------------------------------------------------
	SELECT @IsTest = lg.IsTest
			,@sportType	   = m.sportType
	FROM dbo.Match m WITH (NOLOCK)
		INNER JOIN dbo.League lg WITH (NOLOCK) ON m.leagueID = lg.LeagueID
	WHERE m.matchID = @matchID
		
	IF @IsAuto = 0
	BEGIN
		EXEC dbo.[NAP_Admin_Result_Update_BingoBall] 
			@matchid	= @matchid
			,@Sporttype	= @Sporttype
			,@Resources = @Resources
	END

	EXEC dbo.NAP_Admin_Match_Update
		@Command			= 'profile_bingoball'
		,@Action			= @Action
		,@MatchID			= @matchid
		,@creator			= @AdminId


END
GO