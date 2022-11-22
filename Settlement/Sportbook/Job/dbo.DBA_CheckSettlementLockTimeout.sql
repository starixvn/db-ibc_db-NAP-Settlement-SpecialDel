/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[DBA_CheckSettlementLockTimeout]
	@MonitorDurationWithInMin INT = 15 
AS
/*
	Created by:20211028@Kathy
	Task: check settlement lock
	DB: SBSETTLE-bodb02

	Revision
		- 20211028@Kathy: Check settlement lock [Redmine:#158477]
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]
		- 20221122@Louisa: Update format email [Redmine:#100002]
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE		@SubjectMessage VARCHAR(300)=''
				,@TableHTML VARCHAR(MAX)=''
				,@__serverName VARCHAR(200)

	SET @__serverName = @@SERVERNAME
	DECLARE @tmpSettlementLock TABLE (MatchId INT, SessionId BIGINT, CreatedTime DATETIME)
	DECLARE @tmpSiteDB_SettlementLock TABLE (SiteDBGroupId SMALLINT, MatchId INT, SessionId BIGINT, CreatedTime DATETIME)

	IF OBJECT_ID('SettlementLock','U') IS NOT NULL
	BEGIN
		IF EXISTS (SELECT 1 FROM bodb02.dbo.SettlementLock with (nolock))
		BEGIN
			INSERT INTO @tmpSettlementLock(MatchId, SessionId, CreatedTime)
			SELECT	MatchId, SessionId, CreatedTime
			FROM	dbo.SettlementLock s WITH(NOLOCK)
			WHERE	DATEDIFF(MINUTE,CreatedTime,GETDATE()) >= @MonitorDurationWithInMin

			IF @@ROWCOUNT > 0
			BEGIN
				SET @SubjectMessage	= N'Settlement - SSB - Notification at ' + @@servername

				SET @TableHTML = @TableHTML + 
						N'<br><table border="1">' +
						N'<tr>' +
						N'<th>MatchId</th>' +
						N'<th>SessionId</th>' +
						N'<th>CreatedTime</th>' +
						N'</tr>' +
							CAST ( ( SELECT td = MatchId, '',								
											td = SessionId, '',										
											td = CONVERT(CHAR(19),CreatedTime,120), ''									
									FROM	@tmpSettlementLock
									FOR XML PATH('tr'), TYPE 
							) AS NVARCHAR(MAX) ) +
						N'</table>' +
						N'<H4>Hey guys, Settlement is running at [' + @@servername + '] over [' + cast(@MonitorDurationWithInMin as varchar(20)) + '] mins still not complete. Please check data at bodb02.dbo.SettlementLock</H4>' ;

				EXEC dbo.SSB_Settlement_SendEmail @Recipients = ''--get email address by enviroment
						,@Subject = @SubjectMessage
						,@MessageBody = @TableHTML

				EXEC	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @__serverName
					, @JobId = NULL
					, @JobName = N'bodb02: Check Settlement status'
					, @Message = @SubjectMessage
					, @CaseId = 1;			
			END
		END
	END

	IF EXISTS (SELECT 1 FROM bodb02.dbo.SiteDB_SettlementLock with (nolock))
	BEGIN
		INSERT INTO @tmpSiteDB_SettlementLock(SiteDBGroupId, MatchId, SessionId, CreatedTime)
		SELECT	SiteDBGroupId, MatchId, SessionId, CreatedTime
		FROM	dbo.Sitedb_SettlementLock s WITH(NOLOCK)
		WHERE	DATEDIFF(MINUTE,CreatedTime,GETDATE()) >= @MonitorDurationWithInMin

		IF @@ROWCOUNT > 0
		BEGIN
			SET @SubjectMessage	= N'Settlement For SiteDB - SSB - Notification at ' + @@servername

			SET @TableHTML = @TableHTML + 
					N'<br><table border="1">' +
					N'<tr>' +
					N'<th>SiteDBGroupId</th>' +
					N'<th>MatchId</th>' +
					N'<th>SessionId</th>' +
					N'<th>CreatedTime</th>' +
					N'</tr>' +
						CAST ( ( SELECT td = SitedbGroupId, '',
										td = MatchId, '',								
										td = SessionId, '',										
										td = CONVERT(CHAR(19),CreatedTime,120), ''									
								FROM	@tmpSiteDB_SettlementLock
								FOR XML PATH('tr'), TYPE 
						) AS NVARCHAR(MAX) ) +
					N'</table>' +
					N'<H4>Hey guys, Settlement for sitedb is running at [' + @@servername + '] over [' + cast(@MonitorDurationWithInMin as varchar(20)) + '] mins still not complete. Please check data at bodb02.dbo.SiteDB_SettlementLock</H4>' ;

			EXEC dbo.SSB_Settlement_SendEmail @Recipients = ''--get email address by enviroment
					,@Subject = @SubjectMessage
					,@MessageBody = @TableHTML
			
			EXEC	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @__serverName
					, @JobId = NULL
					, @JobName = N'bodb02: Check Settlement status'
					, @Message = @SubjectMessage
					, @CaseId = 1;
		END
	END
END