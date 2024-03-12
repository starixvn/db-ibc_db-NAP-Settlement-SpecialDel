/*<info serverAlias="DBTP-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240312@Aries
	Task:  Result Amendment [Redmine:#196401]
	DB: DBTP-bodb02

*/

USE bodb02
GO
/**************************RepInfoGroup: add  DBGRP01L*****************************************/
IF NOT EXISTS (SELECT 1 FROM RepInfoGroup WITH(NOLOCK) WHERE GroupID = 3)
BEGIN
	INSERT INTO RepInfoGroup(GroupID,SourceServerName,SourceDBName)
	VALUES (3,'DBGRP01L','bodb02')
END


IF NOT EXISTS (SELECT 1 FROM RepInfo WITH(NOLOCK)  WHERE [group] = 3 AND [name] = 'SettlementResultHistory' )
BEGIN
	INSERT INTO RepInfo([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size )
	SELECT 3										AS [group]
		  ,'SettlementResultHistory'				AS [name]
		  ,1										AS active
		  ,'RepUpdateTime'							AS version_key
		  ,0										AS version_type
		  ,'MatchID|SessionID|SeqNo'				AS unique_key 
		  ,'Repl_GetSettlementResultHistory'		AS get_sp
		  ,'Repl_PutSettlementResultHistory'		AS put_sp
		  ,1000										AS interval
		  ,10										AS back_fix
		  ,60000									AS delayed_fix
		  ,0										AS batch_size
END	

IF NOT EXISTS (SELECT 1 FROM RepInfo WITH(NOLOCK)  WHERE [group] = 3 AND [name] = 'SettlementResultHistory_TicketDetails' )
BEGIN
	INSERT INTO RepInfo([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size )
	SELECT 3												AS [group]
		  ,'SettlementResultHistory_TicketDetails'			AS [name]
		  ,1												AS active
		  ,'RepUpdateTime'									AS version_key
		  ,0												AS version_type
		  ,'SessionID|Transid'								AS unique_key 
		  ,'Repl_GetSettlementResultHistory_TicketDetails'	AS get_sp
		  ,'Repl_PutSettlementResultHistory_TicketDetails'	AS put_sp
		  ,1000												AS interval
		  ,10												AS back_fix
		  ,60000											AS delayed_fix
		  ,0												AS batch_size
END	


GO


/**************************RepInfoGroup: add  DBGRP02L*****************************************/
IF NOT EXISTS (SELECT 1 FROM RepInfoGroup WITH(NOLOCK)  WHERE GroupID = 4)
BEGIN
	INSERT INTO RepInfoGroup(GroupID,SourceServerName,SourceDBName)
	VALUES (4,'DBGRP02L','bodb02')
END
GO


IF NOT EXISTS (SELECT 1 FROM RepInfo WITH(NOLOCK)  WHERE [group] = 4 AND [name] = 'SettlementResultHistory' )
BEGIN
	INSERT INTO RepInfo([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size )
	SELECT 4										AS [group]
		  ,'SettlementResultHistory'				AS [name]
		  ,1										AS active
		  ,'RepUpdateTime'							AS version_key
		  ,0										AS version_type
		  ,'MatchID|SessionID|SeqNo'				AS unique_key 
		  ,'Repl_GetSettlementResultHistory'		AS get_sp
		  ,'Repl_PutSettlementResultHistory'		AS put_sp
		  ,1000										AS interval
		  ,10										AS back_fix
		  ,60000									AS delayed_fix
		  ,0										AS batch_size
END	

IF NOT EXISTS (SELECT 1 FROM RepInfo WITH(NOLOCK)  WHERE [group] = 4 AND [name] = 'SettlementResultHistory_TicketDetails' )
BEGIN
	INSERT INTO RepInfo([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size )
	SELECT 4												AS [group]
		  ,'SettlementResultHistory_TicketDetails'			AS [name]
		  ,1												AS active
		  ,'RepUpdateTime'									AS version_key
		  ,0												AS version_type
		  ,'SessionID|Transid'								AS unique_key 
		  ,'Repl_GetSettlementResultHistory_TicketDetails'	AS get_sp
		  ,'Repl_PutSettlementResultHistory_TicketDetails'	AS put_sp
		  ,1000												AS interval
		  ,10												AS back_fix
		  ,60000											AS delayed_fix
		  ,0												AS batch_size
END	

/**************************RepInfoGroup: add  DBGRP03L*****************************************/
IF NOT EXISTS (SELECT 1 FROM RepInfoGroup WITH(NOLOCK)  WHERE GroupID = 5)
BEGIN
	INSERT INTO RepInfoGroup(GroupID,SourceServerName,SourceDBName)
	VALUES (5,'DBGRP03L','bodb02')
END
GO 

IF NOT EXISTS (SELECT 1 FROM RepInfo WITH(NOLOCK)  WHERE [group] = 5 AND [name] = 'SettlementResultHistory' )
BEGIN
	INSERT INTO RepInfo([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size )
	SELECT 5										AS [group]
		  ,'SettlementResultHistory'				AS [name]
		  ,1										AS active
		  ,'RepUpdateTime'							AS version_key
		  ,0										AS version_type
		  ,'MatchID|SessionID|SeqNo'				AS unique_key 
		  ,'Repl_GetSettlementResultHistory'		AS get_sp
		  ,'Repl_PutSettlementResultHistory'		AS put_sp
		  ,1000										AS interval
		  ,10										AS back_fix
		  ,60000									AS delayed_fix
		  ,0										AS batch_size
END	

IF NOT EXISTS (SELECT 1 FROM RepInfo WITH(NOLOCK)  WHERE [group] = 5 AND [name] = 'SettlementResultHistory_TicketDetails' )
BEGIN
	INSERT INTO RepInfo([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size )
	SELECT 5												AS [group]
		  ,'SettlementResultHistory_TicketDetails'			AS [name]
		  ,1												AS active
		  ,'RepUpdateTime'									AS version_key
		  ,0												AS version_type
		  ,'SessionID|Transid'								AS unique_key 
		  ,'Repl_GetSettlementResultHistory_TicketDetails'	AS get_sp
		  ,'Repl_PutSettlementResultHistory_TicketDetails'	AS put_sp
		  ,1000												AS interval
		  ,10												AS back_fix
		  ,60000											AS delayed_fix
		  ,0												AS batch_size
END	


