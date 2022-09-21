/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
   Created:20220921@Louisa
   Task: Scale Out BetTrans [Redmine:#175251]

   DB: DBCTG/bodb02
	
	Revisions:
		- 20220921@Louisa: Change Job name [Redmine:#175251]
	
	Param's Explanation: 

*/

EXEC msdb.dbo.sp_update_job 
	@job_name = 'vndba:Check slowly parlay settlement'  
	,@new_name = 'Check slowly settlement' 
	