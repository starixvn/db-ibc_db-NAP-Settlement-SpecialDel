/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Job_SetWaitforDelay] ()
RETURNS VARCHAR(100)
/* 
	Created:20200527@Helen
    Task: 
    DB: dbtrans/bodb02 - https://nexdev.net/issues/134854
    
    
	Revisions:
		- 20200527@Helen: support deploy without UM - [Redmine:134854]
		- 20200604@Max: [TVS] Apply new policy into Void Abnormal Bet rules - rollback - [Redmine: #133705]
		- 20200702@Max: [TVS] Hotfix - Cash out ticket of Cash-Out member is not unmarked in Unmark action [Redmine: #136524]
		- 20200707@Max: [TVS] Auto Void for remaining sports - [Redmine: #131865]
		- 20200817@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20201001@Max: TVS - Exclude Virtual Futsal from auto void bet [Redmine: #142512]
		- 20201016@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201222@July: TVS - Enhance TVS Queue data storage [Redmine: #146805]
		- 20210128@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210128@Max: Hotfix - TVS [Redmine: #149573]
		- 20210130@Max: TVS Issue [Redmine: #149743]
		- 20210201@Max: Hotfix - TVS - Abnormal Accounts [Redmine: #149697]
		- 20210301@July: HotFix - Update balance CO wrong wallet [Redmine: #150621]
		- 20220406@Kathy: Change default value to 100ms [Redmine:#166457]
		- 20220509@July: Wait for delay [Redmine:#0000]
   
	Notes:
		DECLARE @Delay VARCHAR(100) = ''
		SET @Delay = dbo.f_Job_SetWaitforDelay () 
		WAITFOR DELAY @Delay

*/
AS
BEGIN
    RETURN '00:00:00:100'
END
GO
