/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Task_Settlement_LongRunning_Check
	@Step int
as
/*
	Created by: 20210824@Patrick
	Task: check process long running 
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210824@Kathy: Check cricket long running [Redmine:#154737]
		- 20211101@Kathy: Check balance error [Redmine:#159486]
		- 20220921@Louisa: at @step5, set interval = 5 minutes and do not send alert for UUS bettween 7AM to 7PM [Redmine:#175251]
*/
begin
	set nocount on
	declare @__errorMessage varchar(400)
			,@fromdate datetime
			,@IsLimitedTime	BIT = 0

	if  DATEPART (HOUR,GETDATE() ) not between 7 and 19 
	set @IsLimitedTime = 1 --do not send alert for UUS bettween 7AM to 7PM
			
	if @Step = 1 --check Parlay Queue
	begin
		set @fromdate = DATEADD(SECOND, -600, GETDATE())

		if exists (
			select top 1 1
			from dbo.Parlay_Calculate_Queue with(nolock)
			where IsCalculating in (1,0)
				and Starttime < @fromdate
		)
		begin
			set @__errorMessage = 'Hey guys, Parlay Settlement is slowly calculating. Please check!!!'
			execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = N'PONTUS'
				, @JobId = NULL, @JobName = N'Custom Message'
				, @Message = @__errorMessage
				, @CaseId = 1;

			raiserror(@__errorMessage, 16, 1)
		end

		return
	end

	if @Step = 2 --check Single Queue
	begin
		set @fromdate = DATEADD(second, -120, GETDATE())

		if exists (
			select top 1 1
			from dbo.Single_Calculate_Queue with(nolock)
			where IsCalculating in (1,0)
				and Starttime < @fromdate
				and (SportType <> 50
						or (SportType = 50 and sqlcommand <> '')
					) 
		)
		begin
			set @__errorMessage = 'Hey guys, Single Settlement is slowly calculating. Please check!!!'
			execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = N'PONTUS'
				, @JobId = NULL, @JobName = N'Custom Message'
				, @Message = @__errorMessage
				, @CaseId = 1;

			raiserror(@__errorMessage, 16, 1)
		end

		return
	end

	if @Step = 3 --check Single / Parlay Queue for VS
	begin
		set @fromdate = DATEADD(SECOND, -180, GETDATE())

		if exists (
			select top 1 1
			from dbo.Single_Calculate_Queue_VS with(nolock)
			where IsCalculating in (1,0)
				and Starttime < @fromdate
		)
		or exists (
			select top 1 1
			from dbo.Parlay_Calculate_Queue_VS with(nolock)
			where IsCalculating in (1,0)
				and Starttime < @fromdate
		)
		begin
			set @__errorMessage = 'Hey guys, BVS Single / Parlay Settlement is slowly calculating. Please check!!!'
			execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = N'PONTUS'
				, @JobId = NULL, @JobName = N'Custom Message'
				, @Message = @__errorMessage
				, @CaseId = 1;

			raiserror(@__errorMessage, 16, 1)
		end

		return
	end

	if @Step = 4 --check cricket in Single Queue
	begin
		SET @fromdate = DATEADD(second, - 900, GETDATE())

		if exists (
			select top 1 1
			from dbo.Single_Calculate_Queue with(nolock)
			where IsCalculating in (1,0)
				and Starttime < @fromdate
				and SportType = 50 and sqlcommand = ''
		)
		begin
			set @__errorMessage = 'Hey guys, Single Settlement is slowly calculating for CRICKET. Please check!!!'
			execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = N'PONTUS'
				, @JobId = NULL, @JobName = N'Custom Message'
				, @Message = @__errorMessage
				, @CaseId = 1;

			raiserror(@__errorMessage, 16, 1)
		end

		return
	end

	if @Step = 5 --check balance error
	begin
		set @fromdate = DATEADD(second, -300, GETDATE())

		IF exists (select top 1 1
					from dbo.BalanceErr b with(nolock)
						inner join CustDB.dbo.custInfo c with(nolock)
							on b.Custid = c.custid
					where LogDate > @fromdate
						and IsResolved = 0
						and 1 =CASE WHEN @IsLimitedTime = 1 AND c.currency = 20 THEN 0
									ELSE 1
									END
		)
		begin
			set @__errorMessage = 'Hey guys, process insert balance pending got error (table BalanceErr). Please check!!!'
			execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
				, @JobId = NULL, @JobName = N'vndba:Check slowly running or failed processes'
				, @Message = @__errorMessage
				, @CaseId = 1;

			raiserror(@__errorMessage, 16, 1)
		end

		return
	end
end

go
