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
	DECLARE		@tmpResourcesWeb	TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OtherInfo VARCHAR(2000))


	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue,OtherInfo)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,''),OtherInfo
	FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id			VARCHAR(20)
													 ,Home			VARCHAR(50)
													 ,Away			VARCHAR(50)
													 ,OtherInfo		VARCHAR(2000)
												) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT rs.ResourceID, tbl.HomeValue, tbl.AwayValue, tbl.[Action], tbl.OtherInfo, l.LogDate
	FROM @tmpResourcesWeb AS rs
		CROSS APPLY (
			SELECT  TOP 1 
					l.HomeValue
				   ,l.AwayValue				   
				   ,l.OtherInfo
				   ,l.LogDate
				   ,CASE WHEN l.ActionID IN (100,148,101,102,189)	THEN 'CAL'
						 WHEN l.ActionID IN (103,149,190,81040)		THEN 'UNDO' 
						 WHEN l.ActionID IN (109,150,191,110,111)	THEN 'REFUND' 
						 ELSE NULL
					END AS [Action]
			FROM dbo.SettlementLog AS l WITH (NOLOCK)
			WHERE l.MatchID = @MatchID
				AND rs.ResourceID = l.ResourceID
				AND (rs.HomeValue != l.HomeValue 
					OR ISNULL(rs.AwayValue,'') != ISNULL(l.AwayValue,'')
					OR ISNULL(rs.OtherInfo,'') != ISNULL(l.OtherInfo,''))
			ORDER BY tbl.LogDate DESC) AS tbl
END
GO