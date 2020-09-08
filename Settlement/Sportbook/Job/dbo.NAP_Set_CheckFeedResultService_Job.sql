/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200907@Louisa
    Task: Check SBO & Soccerway Results every 2 hours [Redmine:#111576]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200907@Louisa: Check SBO & Soccerway Results evry 2 hours [Redmine:#111576]
*/
CREATE PROCEDURE NAP_Set_CheckFeedResultService_Job
AS
BEGIN

	DECLARE   @Check DATETIME
			, @ProviderName VARCHAR(10) = ''
			, @Email_body VARCHAR(MAX) =''

	DECLARE  @Email_subject NVARCHAR(200)
			, @Email_recipients VARCHAR(250) =	N'louisa.vo@starixsoft.com'
			--- 'michael.nguyen@starixsoft.com; IT@starixsoft.com; dbaadmin@starixsoft.com' 
			, @CheckDate VARCHAR(20) = 	CONVERT(VARCHAR(20), GETDATE(), 100) 


	SET @Check =  DATEADD( HOUR, -2, GETDATE() )

	DECLARE @tblCheckProvider TABLE
	(
		SourceID TINYINT
	)

	INSERT INTO @tblCheckProvider (SourceID)
	SELECT r.SourceID
	FROM dbo.ProviderResultDetail r WITH(NOLOCK)
		INNER JOIN dbo.Match m WITH(NOLOCK)
			ON r.MatchID = m.MatchID
	WHERE r.SourceId IN (1,5)
		AND CreatedDate >= @Check
		AND DATEDIFF(MINUTE, m.Kickofftime, GETDATE() ) BETWEEN 1 AND 180
		AND 1 = CASE WHEN r.SourceId = 1 AND m.AutoSetting & 2  = 2 THEN 1 
					 WHEN r.SourceId = 5 AND m.AutoSetting & 1  = 1 THEN 1 
				END


	---SBO: SourceId = 1	
	IF NOT EXISTS (SELECT TOP 1 1 FROM @tblCheckProvider WHERE SourceID = 1 )
	BEGIN
		SET @ProviderName = 'SBO'
		SET @Email_subject = 'Third-party result checking - ' + @ProviderName + ' - ' + @CheckDate

		SET @Email_body  =  
				'<html>
					<body>
						<br>Dear All,<br>

						<br>There is no result gotten from the '+ @ProviderName +' for the last 2 hours, please check.<br><br>
						
						<br>Thanks and best regards,<br>
						<br>This is an auto-mail from Auto Checking Third Party Result service. Please do not reply.
						</body>
				</html>'

		EXECUTE msdb.dbo.sp_send_dbmail 
				  @profile_name		= DEFAULT
				, @recipients		= @Email_recipients
				, @importance		='Normal'
				, @subject			= @Email_subject
				, @body				= @Email_body
				, @body_format		= 'HTML';
	END

	----Soccerway: SourceId = 5
	IF NOT EXISTS (SELECT TOP 1 1 FROM @tblCheckProvider WHERE SourceID = 5 )
	BEGIN
		SET @ProviderName = 'Soccerway'
		SET @Email_subject = 'Third-party result checking - ' + @ProviderName + ' - ' + @CheckDate

		
		SET @Email_body  =  
				'<html>
					<body>
						<br>Dear All,<br>

						<br>There is no result gotten from the '+ @ProviderName +' for the last 2 hours, please check.<br><br>
						
						<br>Thanks and best regards,<br>
						<br>This is an auto-mail from Auto Checking Third Party Result service. Please do not reply.
						</body>
				</html>'

		EXECUTE msdb.dbo.sp_send_dbmail 
				  @profile_name		= DEFAULT
				, @recipients		= @Email_recipients
				, @importance		='Normal'
				, @subject			= @Email_subject
				, @body				= @Email_body
				, @body_format		= 'HTML';
	END

END



