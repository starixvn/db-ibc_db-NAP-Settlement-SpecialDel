/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
alter function dbo.f_Set_GetDuration
(
	@KeyId varchar(50)
) 
/*  Created: 20221026@Kathy
	Task: Get duration
	DB: DBTXN-bodb02
	Revisions:  
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

*/
returns int -- second
as
begin
	return (select case 
						when @KeyId = 'CompareTicketCentralSiteDB' then 900  
						else 60
					end)
end
go
