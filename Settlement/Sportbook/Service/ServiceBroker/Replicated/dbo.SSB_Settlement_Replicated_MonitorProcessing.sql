/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
create procedure dbo.SSB_Settlement_Replicated_MonitorProcessing @DurationInMins int = 60
as
/*  Created: Patrick@20210801
	Task: Sending email
	DB: SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
*/
begin
	set nocount on
	declare @__starttime datetime
	select @__starttime = dateadd(minute, -@DurationInMins, getdate())
	declare @__tempdata table(matchId int, sessionId bigint, creationTime datetime)

	insert into @__tempdata(matchid, sessionId, creationTime)
	select top(10) MatchId, SessionId, CreatedTime
	from dbo.SettlementLock l with(nolock) where CreatedTime <= @__starttime

	if @@rowcount = 0 --no data
		return

	begin --++send email to notify for dba check
		declare @email_body nvarchar(max), @subject nvarchar(200)
		set @email_body = '
		   <html>
			 <body>
			  <style>
					table {border-collapse: collapse;}
					table, td, th {border: 1px solid black;text-align: center;}
					th {text-align: left; padding: 8px;}
				</style>
			  <h2> Hey guys, Settlement is running at [' + @@servername + '] over [' + cast(@DurationInMins as varchar(20)) + '] mins still not complete. Please check data at dbo.SettlementLock table!!!</h2>
			  <p><b>Send time:</b> ' + convert(varchar(50), getdate(), 121) + ' </p> 
			  {<table1>}
			</body>
			</html>'

		declare @table1 varchar(max), @rowData varchar(max)
		set @table1 = '
			<table>
				<tr>
				<th style="text-align:center">matchId</th>
				<th style="text-align:center">sessionId</th>
				<th style="text-align:center">creationTime</th>
				</tr>
				{<row>}
			</table>'

		set @rowData = convert(varchar(max), (
			select cast(matchid as varchar(20)) as 'td1'
				, cast(sessionId as varchar(50)) as 'td2'
				, convert(varchar(50), creationTime, 121) as 'td1'
			from @__tempdata t order by creationTime
			for xml path('tr'), type
		))

		set @rowData = replace(replace(@rowData, 'td1>', 'td>'), 'td2>', 'td>')
		set @table1 = replace(@table1, '{<row>}', @rowData)
		set @email_body = replace(@email_body, '{<table1>}', @table1)

		select @subject	= N'Settlement - SSB - Notification at ' + @@servername

		---++send email
		exec dbo.SSB_Settlement_SendEmail @Recipients = ''--get email address by enviroment
			, @Subject = @subject
			, @MessageBody = @email_body
	end
	
	begin -- --++letstalk to notify for dba check
	
		declare @__errorMessageTemp varchar(512)
		set @__errorMessageTemp = 'Hey guys, Settlement is running at [' + @@servername + '] over [' + cast(@DurationInMins as varchar(20)) + '] mins still not complete. Please check data at dbo.SettlementLock table!!!'
		execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = N'PONTUS'
			, @JobId = NULL
			, @JobName = N'Custom Message'
			, @Message = @__errorMessageTemp
			, @CaseId = 1;
	
	end
end
go
