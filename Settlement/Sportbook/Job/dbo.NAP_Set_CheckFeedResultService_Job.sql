/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE NAP_Set_CheckFeedResultService_Job
AS
/* 
	Created:20200907@Louisa
    Task:  Check SBO & Soccerway Services [Redmine:#111576]
    DB: DBTP/bodb02
	
	Revisions:
		- 20200907@Louisa:  Check SBO & Soccerway Services [Redmine:#111576]
*/
BEGIN

	DECLARE   @Check DATETIME
			, @ProviderName VARCHAR(10)
			, @Email_body VARCHAR(MAX)

	DECLARE  @Email_subject NVARCHAR(200)
			, @Email_recipients VARCHAR(250) ='michael.nguyen@starixsoft.com;IT@starixsoft.com;dbaadmin@starixsoft.com'


	SET @Check =  DATEADD( HOUR, -2, GETDATE() )

	DECLARE @tblCheckResult TABLE	(SourceID TINYINT)
	DECLARE @tblCheckMatch TABLE	(SourceID TINYINT)
	DECLARE @tblSendMail   TABLE	(SourceID TINYINT)

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
	
	IF @@ROWCOUNT > 0
	BEGIN
		---Check match
		INSERT INTO @tblCheckMatch (SourceID)
		SELECT DISTINCT CASE WHEN m.AutoSetting & 1 = 1 AND m.AutoSetting & 2 = 2 THEN 0
							 ELSE CASE WHEN m.AutoSetting & 1 = 1 THEN 1
									ELSE 5 END
				END AS SourceID
		FROM dbo.Match m WITH(NOLOCK)
		WHERE m.sporttype =1
			AND ISNULL(m.eventstatus,'') <> 'completed'
			AND DATEDIFF(MINUTE, m.Kickofftime, GETDATE() ) BETWEEN 60 AND 180
			AND (
					m.AutoSetting & 1 = 1
					OR m.AutoSetting & 2 = 2
				)

		INSERT INTO @tblSendMail (SourceID)
		SELECT r.SourceID FROM @tblCheckResult r INNER JOIN @tblCheckMatch m ON r.SourceID = m.SourceID OR m.SourceID = 0
		
		IF @@ROWCOUNT > 0
		BEGIN	
			
			DECLARE  @SourceID TINYINT	= 1

			WHILE (1=1)
			BEGIN

				SET @SourceID  = (SELECT TOP 1 SourceID from @tblSendMail)

				IF @SourceID IS NULL BREAK;

				SELECT @ProviderName = CASE  @SourceID WHEN 1 THEN 'SBO' ELSE 'Soccerway'END
		
				SET @Email_subject = 'Third-party result checking - ' + @ProviderName + ' - ' + CONVERT(VARCHAR(20), GETDATE(), 100) 
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

				DELETE FROM @tblSendMail WHERE SourceID = @SourceID

			END
		END
	END
END
GO