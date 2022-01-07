/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[DBA_CheckSSBCalculationLog]
	@MonitorDurationWithInMin INT = 15 
AS
/*
	Created by:20211028@Kathy
	Task: check sbo.CalculationLogs
	DB: SBSETTLE-bodb02

	Revision
		- 20220107@Kathy: Check SSB sbo.CalculationLogs [Redmine:#167193]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE		@SubjectMessage VARCHAR(300)=''
				,@TableHTML VARCHAR(MAX)=''

				,@Id [uniqueidentifier]
				,@TotalCommmand INT = 0
				,@CreationTime DATETIME
				,@MessageBody VARCHAR(1000) = ''
				,@checktime DATETIME

	IF OBJECT_ID('SystemSettings', 'U') IS NOT NULL
	BEGIN
		SELECT	@MonitorDurationWithInMin = VValue
		FROM	dbo.SystemSettings WITH(NOLOCK)
		WHERE	VName = 'CheckCalculationLogs'

		IF @@ROWCOUNT = 0
			SET @MonitorDurationWithInMin = 15
	END

	SET @checktime = DATEADD(MINUTE,- @MonitorDurationWithInMin, GETDATE())

	SELECT TOP 1 @Id = Id
	FROM	sb.calculationlogs WITH(NOLOCK)
	ORDER BY creationTime DESC

	SELECT	@TotalCommmand = COUNT(1) 
			,@CreationTime = MIN(creationTime)
			,@MessageBody = MIN(LEFT(message_body,1000))
	FROM sb.CalculationLogs WITH(NOLOCK) 
	WHERE Id = @Id

	IF @TotalCommmand = 1 AND DATEDIFF(MINUTE,@CreationTime,GETDATE()) >= @MonitorDurationWithInMin
	BEGIN
		SET @SubjectMessage	= N'Settlement - SSB - Notification at ' + @@servername

		SET @TableHTML = @TableHTML + 
				N'<br><table border="1">' +
				N'<tr>' +
				N'<th>Id</th>' +
				N'<th>MessageBody</th>' +
				N'<th>CreationTime</th>' +
				N'</tr>' +
					CAST ( ( SELECT td = @Id, '',								
									td = @MessageBody, '',										
									td = CONVERT(CHAR(19),@CreationTime,120), ''									
							FOR XML PATH('tr'), TYPE 
					) AS NVARCHAR(MAX) ) +
				N'</table>' +
				N'<H4>Hey guys, Settlement is running at [' + @@servername + '] over [' + cast(@MonitorDurationWithInMin as varchar(20)) + '] mins still not complete. Please check data at bodb02.sb.CalculationLogs </H4>' ;

		EXEC dbo.SSB_Settlement_SendEmail @Recipients = ''--get email address by enviroment
				,@Subject = @SubjectMessage
				,@MessageBody = @TableHTML

		EXEC DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
			, @JobId = NULL
			, @JobName = N'bodb02: Check Settlement status'
			, @Message = @SubjectMessage
			, @CaseId = 1;			
	END
END