/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_SettlementLog_CheckReSettle]
	 @MatchID				INT,
	 @SelectedResources		VARCHAR(MAX)	=	NULL
AS
/*	
	Creator: 20230414@Aries
	Task: Support OST Team Query Resettlement Log [Redmine: #185964]
	DB: DBLOG/bodb_CustomerLog
	 
	Revisions:
		-	20230414@Aries: Created [Redmine:#185964]
		
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
	DECLARE		@handle				INT,
				@ActionID			INT
	DECLARE		@tmpResourcesWeb	TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))


	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,''),OtherInfo
	FROM OPENXML(@handle,'Resources/Resource',1) WITH(	 Id				VARCHAR(20)
														,Home			VARCHAR(50)
														,Away			VARCHAR(50)
												) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT rsl.ResourceID, l.HomeValue, l.AwayValue
	FROM @tmpResourcesWeb AS rs
		CROSS APPLY (
			SELECT TOP 1 l.HomeValue, l.AwayValue
			FROM dbo.SettlementLog AS l WITH (NOLOCK)
			WHERE l.MatchID = @MatchID
				AND rs.ResourceID = l.ResourceID
				AND (rs.HomeValue != l.HomeValue OR rs.AwayValue != l.AwayValue)
			ORDER BY tbl.LogDate DESC) AS tbl
END
GO