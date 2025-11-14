/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_nap" viewers="" isFunction="0"></info>*/    
/*	
	Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBLOG-bodb_CustomerLog
	
	Revisions: 
		- 20251027@Max: Create table [Redmine: #241652]
*/

USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81067, 81068))
BEGIN
    INSERT INTO LogAction(ActionID,SPName,ActionNameEN,ActionNameCH,ActionNameCS,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN)
    VALUES (81067,'NAP_Admin_HybridParlay_LegOddsUpd','Update new leg odds','Update new leg odds',NULL,NULL,NULL,NULL,NULL,NULL,NULL)
		, (81068,'NAP_Admin_Calculate_HybridParlay','Calculate hybrid parlay','Calculate hybrid parlay',NULL,NULL,NULL,NULL,NULL,NULL,NULL)
END
