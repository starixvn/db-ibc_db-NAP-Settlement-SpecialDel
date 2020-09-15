/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200907@Louisa
    Task: Check SBO & Soccerway Results every 2 hours [Redmine:#111576]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200907@Louisa: Check SBO & Soccerway Results evry 2 hours [Redmine:#111576]
*/
CREATE PROCEDURE NAP_Set_CheckFeedResultService_Job_ver2
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

	DECLARE @tblCheckProvider TABLE	(SourceID TINYINT, isExist BIT)
	
	INSERT INTO @tblCheckProvider (SourceID, isExist)
	SELECT DISTINCT r.SourceID, 0
	FROM dbo.ProviderResultDetail r WITH(NOLOCK)
	WHERE r.SourceId IN (1,5)
		AND CreatedDate >= @Check
	
	IF @@ROWCOUNT < 2 --- not exist any Resultdetail or only SBO/Soccerway
	BEGIN
		INSERT INTO @tblCheckProvider (SourceID, isExist)
		SELECT CASE WHEN m.AutoSetting & 1 = 1 THEN 1
					WHEN m.AutoSetting & 2 = 2 THEN 5
				END
				, 1
		FROM dbo.Match m WITH(NOLOCK)
		WHERE m.sporttype =1
			AND DATEDIFF(MINUTE, m.Kickofftime, GETDATE() ) BETWEEN 60 AND 180
			AND (
					m.AutoSetting & 1 = 1
					OR m.AutoSetting & 2 = 2
				)
	END

	IF @@ROWCOUNT >= 1 --exist match need to feed result
	BEGIN
		IF NOT EXISTS (SELECT SourceID FROM @tblCheckProvider WHERE SourceID = 1 AND isExist = 0)
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


		IF NOT EXISTS (SELECT TOP 1 1 FROM @tblCheckProvider WHERE SourceID = 5 AND isExist = 0)
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
END
GO


