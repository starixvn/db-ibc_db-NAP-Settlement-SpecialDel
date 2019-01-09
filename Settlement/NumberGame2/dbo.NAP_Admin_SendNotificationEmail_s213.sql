/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_SendNotificationEmail_s213
	@Action VARCHAR(50)='',
	@seqID 	INT = 0
AS
	/*
	Created by:[Johnson]
	Date:[20160823]
	Task: Send email for relevant departments for NG2
	DB: DBTXN/BODB02
	
	Revisions:
		- 20190109@Johnson: Add UNDO action [redmine:#107658]
	Parameter's Explanation:
		@Action= "settlement" : send email to IT if skip updating tickets
				= "Refund": send mail to CSD,IT,3rd Party
				= "VOID" 
		@seqID: batch tickets need to send email
*/
BEGIN
	DECLARE @body VARCHAR(MAX), 
		@profile_name 	SYSNAME, 
		@recipients 	VARCHAR(MAX),
		@copy_recipients VARCHAR(MAX),
		@subject 		VARCHAR(MAX),
		@query  		VARCHAR(MAX),
		@sporttype 		INT,
		@event			VARCHAR(100),
		@eventDate		DATE
	
	IF @Action = 'Settlement'	
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM Bettrans_staging WITH(NOLOCK) WHERE seqID = @seqID AND isSkipped = 1)
		RETURN		
		
		SELECT @body = 
'Dear All,

 Please be informed that the ticket below had been skipped to update to bettrans: 
		
',
			--config for local
			@recipients = 'gary.vu@starixsoft.com; harris.tran@starixsoft.com',
			--config for pro
			/*@recipients = N'IT@starixsoft.com; kiwi.tran@starixsoft.com; ada.truong@starixsoft.com; jackal.chien@onelab.com; charlie.ma@onelab.tw; timothy.chen@onelab.tw;
			jacky.wu@onelab.tw; allen.wu@onelab.tw; sobi.chen@onelab.tw; sylvia.chen@onelab.tw',
			*/
			--@copy_recipients ='dbaadmin@onelab.tw',
			@subject ='[Lotto] IsSkipped tickets Notification',
			@query = 'SET NOCOUNT ON 
					SELECT ObTransId as Transid, ObCustId as CustID, ObBetType as Bettype, Odds, Stake, ActualStake, GambleId
					FROM bodb02.dbo.Bettrans_staging WITH (NOLOCK)
					WHERE seqID= '+ CONVERT(VARCHAR(20),@seqID) +' AND isSkipped = 1'
			
		BEGIN TRANSACTION
			SELECT TOP (1) @profile_name = name FROM MSDB.dbo.sysmail_profile
			
			EXEC msdb.dbo.sp_send_dbmail
				@recipients=@recipients,
				@body=@body,
				@sensitivity ='Personal',
				@importance ='High',				
				--@copy_recipients =@copy_recipients,
				@subject =@subject,
				@profile_name =@profile_name
				,@query = @query
			
		COMMIT
	END
	ELSE IF @Action = 'Refund'
	BEGIN
		SELECT @sporttype = convert(int,left(convert(varchar(20),matchid),3)),
				@event = CONVERT(varchar(20),GambleId) + '/' + CONVERT(varchar(20),MatchID),
				@EventDate = eventDate
		FROM settlementNG2_message WITH(NOLOCK)
		WHERE seqID = @seqID
				
		SELECT @body ='Dear All,
		
Please be informed that the Event below had been Refunded

' + 'SportType: ' + sportName + ', EventID: ' + @event + ', EventDate: ' + CONVERT(VARCHAR(20),@EventDate)+'

Thanks, 
IT Team 
This is an auto-mail. Please do not reply.
' 
		FROM sports WITH(NOLOCK)
		WHERE sportType = @sportType


		SELECT 
			--config for local
			@recipients = N'gary.vu@starixsoft.com; harris.tran@starixsoft.com'
			--config PRO
			/*
			@recipients = N'csd.one1@enpine.com; IT@starixsoft.com; kiwi.tran@starixsoft.com; ada.truong@starixsoft.com; lim.ykl@gwibsi.com; joker35@enpine.com;
			kimmy@enpine.com; pinus@uuss.net; eddie@uuss.net; james@uuss.net; steve@uuss.net; jackal.chien@onelab.com; charlie.ma@onelab.tw; timothy.chen@onelab.tw;
			jacky.wu@onelab.tw; allen.wu@onelab.tw; sobi.chen@onelab.tw; sylvia.chen@onelab.tw'
			*/
			--,@copy_recipients ='dbaadmin@onelab.tw'
			,@subject ='[Lotto] Ticket Refund Notification – Completed'
		
		BEGIN TRANSACTION
			SELECT TOP (1) @profile_name = name FROM MSDB.dbo.sysmail_profile
					
			EXEC msdb.dbo.sp_send_dbmail
				@recipients=@recipients,
				@body=@body,
				@sensitivity ='Personal',
				@importance ='High',				
				--@copy_recipients =@copy_recipients,
				@subject =@subject,
				@profile_name =@profile_name
		COMMIT
	END
	ELSE IF @Action = 'Undo'
	BEGIN
		SELECT @sporttype = convert(int,left(convert(varchar(20),matchid),3)),
				@event = CONVERT(varchar(20),GambleId) + '/' + CONVERT(varchar(20),MatchID),
				@EventDate = eventDate
		FROM settlementNG2_message WITH(NOLOCK)
		WHERE seqID = @seqID
				
		SELECT @body ='Dear All,
		
Please be informed that the Event below had been undo settlement

' + 'SportType: ' + sportName + ', EventID: ' + @event + ', EventDate: ' + CONVERT(VARCHAR(20),@EventDate)+'

Thanks, 
IT Team 
This is an auto-mail. Please do not reply.
' 
		FROM sports WITH(NOLOCK)
		WHERE sportType = @sportType


		SELECT 
			--config local
			@recipients = N'gary.vu@starixsoft.com; harris.tran@starixsoft.com'
			--config PRO
			/*
			@recipients = N'csd.one1@enpine.com; IT@starixsoft.com; kiwi.tran@starixsoft.com; ada.truong@starixsoft.com; lim.ykl@gwibsi.com; joker35@enpine.com;
			kimmy@enpine.com; pinus@uuss.net; eddie@uuss.net; james@uuss.net; steve@uuss.net; jackal.chien@onelab.com; charlie.ma@onelab.tw; timothy.chen@onelab.tw;
			jacky.wu@onelab.tw; allen.wu@onelab.tw; sobi.chen@onelab.tw; sylvia.chen@onelab.tw'
			*/
			--,@copy_recipients ='dbaadmin@onelab.tw'
			,@subject ='[Lotto] Ticket Undo Notification – Completed'
		
		BEGIN TRANSACTION
			SELECT TOP (1) @profile_name = name FROM MSDB.dbo.sysmail_profile
					
			EXEC msdb.dbo.sp_send_dbmail
				@recipients=@recipients,
				@body=@body,
				@sensitivity ='Personal',
				@importance ='High',				
				--@copy_recipients =@copy_recipients,
				@subject =@subject,
				@profile_name =@profile_name
		COMMIT
	END
	
END
GO