/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_CheckFeedResultService_Job
AS
/* 
	Created:20200907@Louisa
    Task:  Check SBO & Soccerway Services [Redmine:#111576]
    DB: DBTP/bodb02
	
	Revisions:
		- 20200907@Louisa: Check SBO & Soccerway Services [Redmine:#111576]
						   Job name: bodb02 : Task_CheckSBOSoccerwayServices
		- 20200930@Louisa: Enhance: Output top 100 MatchId
		- 20201002@Louisa: Exclude dbaadmin@starixsoft.com
		- 20201009@Louisa: Change email domain to @starixvn.com [Redmine:#143284]
		- 20201224@Louisa: Add Singz, Kid to recipients [Redmine:#111576]
		- 20210701@Louisa: Add sean.lee@onelab.tw [Redmine:#100002]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
		- 20220512@Louisa: Add recipient [Redmine:#172713]
		- 20221004@Victoria: Remove Test League out of provider result monitor job [Redmine: #178705]
		- 20230328@Louisa: Remove singz.hsieh@onelab.tw [Redmine:#185922]
		- 20231011@Louisa: Update email domain from starixvn.com to starixsoft.com [Redmine:#195197]
*/
BEGIN

	DECLARE	  @BodyTemplate VARCHAR(MAX),	@Email_body VARCHAR(MAX)
			, @SubjectTemplate VARCHAR(MAX), @Email_subject NVARCHAR(200)
			, @Email_recipients VARCHAR(250) = 'IT@starixsoft.com;kid.shih@onelab.tw;sean.lee@onelab.tw;leo.teng@onelab.tw'
			--LOCAL: N'dba_local@starixvn.com'
			, @LastTime VARCHAR(200)
			, @Check DATETIME
			, @ProviderName VARCHAR(10)			
			, @MatchIDs VARCHAR(MAX)

	DECLARE @tblCheckResult TABLE	(SourceID TINYINT)

	SET @Check =  DATEADD( HOUR, -2, GETDATE() )
			
	SET @SubjectTemplate = 'Third-party result checking - {<ProviderName>} - ' + CONVERT(VARCHAR(20), GETDATE(), 100) 

	SET @BodyTemplate  =  
					'<html>
						<body>
							<br>Dear All,<br>
							<br>There is no result gotten from the {<ProviderName>} for the last 2 hours, please check.<br>
							<p style="font-weight: bold;text-decoration: underline">List of matchID that does not have result:</p>
								<table with="100%"> 
									{<rowMatch>}
								</table>
							<p>{<LastTime>}</p>				
							<br>Thanks and best regards,<br>
							<br>This is an auto-mail from Auto Checking Third Party Result service. Please do not reply.
							</body>
					</html>'

	;WITH cte_SourceID (SourceID) AS ( SELECT 1 UNION ALL SELECT 5)
	
	INSERT INTO @tblCheckResult (SourceID)
	SELECT DISTINCT r1.SourceID
	FROM cte_SourceID r1
		OUTER APPLY 
			( 
			  SELECT r2.SourceID FROM dbo.ProviderResultDetail r2 WITH(NOLOCK)
			  WHERE r1.SourceId = r2.SourceId		  
				AND CreatedDate >= @Check		
			) r2
	WHERE  r2.SourceId IS NULL
	
	IF EXISTS(SELECT TOP 1 1 FROM @tblCheckResult WHERE SourceID = 1 )
	BEGIN
		SET @MatchIDs =  CONVERT(VARCHAR(MAX),(SELECT TOP 100 m.matchid AS 'td'	
												FROM dbo.Match m WITH(NOLOCK) 
													INNER JOIN league l WITH (NOLOCK) ON l.leagueid = m.leagueid AND l.isTest = 0
												WHERE m.sporttype =1
													 AND ISNULL(m.IsDeleted,0) = 0
									 				 AND DATEDIFF(MINUTE, m.Kickofftime, GETDATE() ) BETWEEN 60 AND 180
													 AND m.AutoSetting & 1 = 1 FOR XML PATH('tr'), TYPE )) 
		IF ISNULL(@MatchIDs,'') <> ''
		BEGIN
			SET @ProviderName = 'SBO'
			SET @LastTime = COALESCE ( 'The latest time that system receives the result from ' + @ProviderName + ': ' 
									  + (SELECT CONVERT(VARCHAR(25), MAX(r.CreatedDate),120) FROM dbo.ProviderResultDetail r WITH(NOLOCK) WHERE r.SourceID = 1)
									 ,'')
			 	
			SET @Email_body = REPLACE(REPLACE(REPLACE(@BodyTemplate, '{<rowMatch>}', @MatchIDs), '{<ProviderName>}',@ProviderName),'{<LastTime>}', @LastTime)

			SET @Email_subject = REPLACE (@SubjectTemplate,  '{<ProviderName>}',@ProviderName)

			EXECUTE msdb.dbo.sp_send_dbmail
				@profile_name		= DEFAULT
				, @recipients		= @Email_recipients 
				, @subject			= @Email_subject
				, @body				= @Email_body
				, @body_format		= 'HTML';
		END	
	END

	IF EXISTS(SELECT TOP 1 1 FROM @tblCheckResult WHERE SourceID = 5 )
	BEGIN
		SET @MatchIDs =  CONVERT(VARCHAR(MAX),(SELECT TOP 100 m.matchid AS 'td'	
												FROM dbo.Match m WITH(NOLOCK)
													INNER JOIN league l WITH (NOLOCK) ON l.leagueid = m.leagueid AND l.isTest = 0
												WHERE m.sporttype =1
													 AND ISNULL(m.IsDeleted,0) = 0
									 				 AND DATEDIFF(MINUTE, m.Kickofftime, GETDATE() ) BETWEEN 60 AND 180
													 AND m.AutoSetting & 2 = 2 FOR XML PATH('tr'), TYPE )) 
		IF ISNULL(@MatchIDs,'') <> ''
		BEGIN
			SET @ProviderName = 'Soccerway'
			SET @LastTime = COALESCE ( 'The latest time that system receives the result from ' + @ProviderName + ': ' 
									  + (SELECT CONVERT(VARCHAR(25), MAX(r.CreatedDate),120) FROM dbo.ProviderResultDetail r WITH(NOLOCK) WHERE r.SourceID = 5)
									 ,'')
									 	
			SET @Email_body = REPLACE(REPLACE(REPLACE(@BodyTemplate, '{<rowMatch>}', @MatchIDs), '{<ProviderName>}',@ProviderName),'{<LastTime>}', @LastTime)

			SET @Email_subject = REPLACE (@SubjectTemplate,  '{<ProviderName>}',@ProviderName)

			EXECUTE msdb.dbo.sp_send_dbmail
				@profile_name		= DEFAULT
				, @recipients		= @Email_recipients 
				, @subject			= @Email_subject
				, @body				= @Email_body
				, @body_format		= 'HTML';
		END 
	END
END
GO