/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Result_Update_BingoBall]
	@MatchID			INT
	,@Sporttype			SMALLINT
	,@Resources			VARCHAR(MAX)
AS 
/*
	Created: 20181018@Vicky
	Task: Update BingoBall
	DB: DBPRO/bodb02 

	Revision
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		- 20190109@Vicky: Set Default Value of IsTest on table BingoBall from League  [Redmine:#107748]
		- 20211108@Louisa: In-house Replicator: Updated Action [Redmine:#164393] 

	Param's Explanation: 

		+ @Resources:   <Resources>
							<Resource Id="1" Result="1"/>
							<Resource Id="2" Result="2"/>
							<Resource Id="3" Result="3"/>
							<Resource Id="4" Result="4"/>
							<Resource Id="5" Result="5"/>
						</Resources>

*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @tblSelectedRID TABLE (ResourceID TINYINT, Result TINYINT)
	DECLARE @handle INT, @IsTest INT
	 
	----------------------------------------------------------------------------
	SELECT @IsTest = lg.IsTest
	FROM dbo.Match m WITH (NOLOCK)
		INNER JOIN dbo.League lg WITH (NOLOCK) ON m.leagueID = lg.LeagueID
	WHERE m.matchID = @matchID
		
	--parse XML   
	EXEC sp_xml_preparedocument @handle OUTPUT, @Resources
	INSERT INTO @tblSelectedRID(ResourceID, Result)
	SELECT DISTINCT  Id, Result
	FROM OPENXML(@handle,'Resources/Resource',1)
	WITH(
			Id TINYINT
			,Result TINYINT
		) tbl
	EXEC sp_xml_removedocument @handle
	
	
	----------------------------------------------------------------------------
	--Insert and update BingoBall
	MERGE dbo.BingoBall WITH (UPDLOCK,ROWLOCK) TARGET
	USING (
		SELECT  sr.ResourceId, sr.Result
		FROM	@tblSelectedRID sr
		) AS SOURCE ON  TARGET.Seq = SOURCE.ResourceId AND TARGET.MatchId = @matchid
	WHEN MATCHED THEN
		UPDATE SET Number	 			 = SOURCE.Result
				   ,UpdateTime		   = GETDATE()

	WHEN NOT MATCHED BY TARGET THEN
		INSERT (MatchId,  Seq,				 Number,		UpdateTime, 	   SportType,  isTest	, IsDeleted)
		VALUES (@matchid, SOURCE.ResourceId, SOURCE.Result, CURRENT_TIMESTAMP, @Sporttype, @IsTest	, 0 );
	
END 
GO
