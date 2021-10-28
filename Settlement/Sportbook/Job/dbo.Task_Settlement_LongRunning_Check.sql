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
*/
begin
	set nocount on
	declare @__datecheck datetime, @__errorMessage varchar(400)
			
	select @__datecheck = getdate()
		
	if @Step = 1 --check Parlay Queue
	begin
		if exists (
			select top 1 1
			from dbo.Parlay_Calculate_Queue with(nolock)
			where IsCalculating in (1,0)
				and datediff(second, Starttime, @__datecheck) > 600
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
		if exists (
			select top 1 1
			from dbo.Single_Calculate_Queue with(nolock)
			where IsCalculating in (1,0)
				and datediff(second, Starttime, @__datecheck) > 120 --seconds
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
		if exists (
			select top 1 1
			from dbo.Single_Calculate_Queue_VS with(nolock)
			where IsCalculating in (1,0)
				and datediff(second, Starttime, @__datecheck) > 180 --seconds
		)
		or exists (
			select top 1 1
			from dbo.Parlay_Calculate_Queue_VS with(nolock)
			where IsCalculating in (1,0)
				and datediff(second, Starttime, @__datecheck) > 180 --seconds
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
		if exists (
			select top 1 1
			from dbo.Single_Calculate_Queue with(nolock)
			where IsCalculating in (1,0)
				and datediff(second, Starttime, @__datecheck) > 900 --seconds
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
end

go
