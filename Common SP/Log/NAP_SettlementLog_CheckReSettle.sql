/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		-	20250415@Aries: Settle - Integrate - Result Amendment - Fast Markets, Time Machine, ＆ Bet Builder [Redmine:#223456]
		
		
	Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON;
	DECLARE		@handle				INT,
				@ActionID			INT
	DECLARE		@tmpResourcesWeb	TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), OtherInfo VARCHAR(2000))
	DECLARE		@tmpAction			TABLE([Action] VARCHAR(20), ActionID INT, PRIMARY KEY(ActionID))

	INSERT INTO @tmpAction([Action],ActionID)
	VALUES('CAL',100),('CAL',148),('CAL',101),('CAL',102),('CAL',189),('CAL',165),
	      ('UNDO',103),('UNDO',149),('UNDO',190),('UNDO',81040),('UNDO',166),
		  ('REFUND',109),('REFUND',150),('REFUND',191),('REFUND',110),('REFUND',111),('REFUND',167)



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
							 WHEN @Action LIKE 'REFUND%' AND  a.[Action] IN ('REFUND') AND l.ActionID IN (165,166,167) AND (rs.HomeValue != l.HomeValue OR ISNULL(rs.AwayValue,'') != ISNULL(l.AwayValue,'')) THEN 1
							 WHEN @Action LIKE 'REFUND%' AND  a.[Action] IN ('CAL','UNDO') THEN 1	 
							 ELSE 0
						END 
				AND 1 = CASE WHEN l.ActionID IN (165,166,167) AND rs.OtherInfo != l.OtherInfo THEN 0
							 WHEN l.ActionID IN (165,166,167) AND rs.OtherInfo = l.OtherInfo AND @Action LIKE 'REFUND%' AND  a.[Action] IN ('REFUND') AND (rs.HomeValue != l.HomeValue OR ISNULL(rs.AwayValue,'') != ISNULL(l.AwayValue,'')) THEN 1
							 ELSE 1
						END
			ORDER BY l.LogDate DESC) AS tbl	
		
END
GO