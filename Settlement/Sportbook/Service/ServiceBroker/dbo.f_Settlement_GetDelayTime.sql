/*<info serverAlias="DBTXN-bodb02, SBSETTLE-bodb02" executers="" viewers="" isFunction="1"></info>*/
alter function dbo.f_Settlement_GetDelayTime
(
	@KeyId varchar(50)
) 
/*  Created: Patrick@20210801
	Task: Get waifor delay time
	DB: DBTXN-bodb02, SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

*/
returns varchar(50)
as
begin
	return (select case when @KeyId = 'Wait_Exec_Each_Batch' then '00:00:00:005' -- waitfor on each batch update bettrans, ...
						when @KeyId = 'SiteDB_Wait_Exec_Each_Batch' then '00:00:00:005' -- SiteDB: waitfor on each batch update bettrans, ...
						when @KeyId = 'Rep_Wait_Send_Exec' then '00:00:00:100' -- waitfor DBTrans sending exec command to processing
						when @KeyId = 'Wait_CompareTicket' then '00:00:00:100' -- wait for comparing ticket between central and sitedb
						else '00:00:00:100' end)
end
go
