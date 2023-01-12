/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SSBErrSel
AS
/*
	Created by: 20221122@Louisa
	Task: Tool support after release Scaleout [RedmineId:#180746]
	DB: DBCTG-bodb02,SBSETTLE-bodb02
	
	Revisions:
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @checktime DATETIME2
			,@ServerName VARCHAR(100) 

	DECLARE @tmpErrorMessage TABLE (MessageId VARCHAR(128), MatchId INT, SessionId BIGINT, ErrorMessage VARCHAR(200), CreatedTime DATETIME2)
	DECLARE @tmpReturnTable TABLE 
	(	 SessionId BIGINT
		,MessageId VARCHAR(128)
		,ErrorMessage VARCHAR(200)
		,CreatedTime DATETIME2
		,HomeTeam NVARCHAR(200)
		,AwayTeam  NVARCHAR(200)
		,SportName  NVARCHAR(100)
		,SiteDBGroupId SMALLINT
	)

	SET @checktime = DATEADD(HOUR,-6,SYSDATETIME())
	SET @ServerName = @@SERVERNAME

	INSERT INTO @tmpReturnTable 
		(	 SessionId  
			,MessageId 
			,ErrorMessage  
			,CreatedTime
			,SiteDBGroupId 
		)
		SELECT	s.SessionId
				,s.MessageId
				,s.ErrorMessage
				,s.Starttime
				,SiteDBGroupId
		FROM	dbo.SSB_SettlementLogs s WITH(NOLOCK)
		WHERE	ISNULL(s.ErrorMessage,'') <> ''
				AND s.Resolved = 0
				AND MessageType LIKE 'Sitedb%'
		 		AND s.StartTime >= @checktime
 
	SELECT	@ServerName AS ServerName
			,c.SessionId
			,'' AS MessageId 
			,(SELECT ErrorMessage + '\n' FROM @tmpReturnTable s WHERE s.SessionId = c.SessionId FOR XML PATH('')) AS ErrorMessage
			,MIN(c.CreatedTime) AS CreatedTime
			,c.SiteDBGroupId
	FROM @tmpReturnTable c
	WHERE c.SessionId > 0
	GROUP BY c.SessionId,c.SiteDBGroupId 
	
	UNION ALL
	SELECT	@ServerName AS ServerName
			,c.SessionId
			,c.MessageId 
			,(SELECT ErrorMessage + '\n' FROM @tmpReturnTable s WHERE s.MessageId = c.MessageId FOR XML PATH('')) AS ErrorMessage
			,MIN(c.CreatedTime) AS CreatedTime
			,c.SiteDBGroupId
	FROM @tmpReturnTable c
	WHERE ISNULL(c.sessionid,0) = 0
	GROUP BY c.SessionId,c.MessageId,c.SiteDBGroupId 
END
GO