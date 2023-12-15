/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementLog_CheckReSettle]
	 @MatchID				INT
	,@Action				VARCHAR(20)
	,@SelectedResources		VARCHAR(MAX)	=	NULL
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
	DECLARE		@tmpAction			TABLE([Action] VARCHAR(20), ActionID INT, PRIMARY KEY(ActionID))

	INSERT INTO @tmpAction([Action],ActionID)
	VALUES('CAL',100),('CAL',148),('CAL',101),('CAL',102),('CAL',189),
	      ('REFUND',103),('REFUND',149),('REFUND',190),('REFUND',81040),
		  ('UNDO',109),('UNDO',150),('UNDO',191),('UNDO',110),('UNDO',111)



	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue,OtherInfo)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,''),OtherInfo
	FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id			VARCHAR(20)
													 ,Home			VARCHAR(50)
													 ,Away			VARCHAR(50)
													 ,OtherInfo		VARCHAR(2000)
												) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT rs.ResourceID, tbl.HomeValue, tbl.AwayValue, tbl.[Action], tbl.OtherInfo, tbl.LogDate
	FROM @tmpResourcesWeb AS rs
		CROSS APPLY (
			SELECT  TOP 1 
					l.HomeValue
				   ,l.AwayValue				   
				   ,l.OtherInfo
				   ,l.LogDate
				   ,a.[Action]
			FROM dbo.SettlementLog AS l WITH (NOLOCK)
				LEFT JOIN @tmpAction AS a on l.ActionID = a.ActionID
			WHERE l.MatchID = @MatchID 
				AND rs.ResourceID = l.ResourceID	
				AND 1 = CASE WHEN @Action LIKE 'CAL%' AND  a.[Action] IN ('REFUND','UNDO') THEN 1	 
							 WHEN @Action LIKE 'CAL%' AND  a.[Action] IN ('CAL') AND (rs.HomeValue != l.HomeValue OR ISNULL(rs.AwayValue,'') != ISNULL(l.AwayValue,'') OR ISNULL(rs.OtherInfo,'') != ISNULL(l.OtherInfo,'')) THEN 1	 
							 WHEN @Action LIKE 'REFUND%' AND  a.[Action] IN ('CAL','UNDO') THEN 1	 
							 ELSE 0
						END 
			ORDER BY l.LogDate DESC) AS tbl	
	WHERE tbl.[Action] != 'UNDO'
		
END
GO