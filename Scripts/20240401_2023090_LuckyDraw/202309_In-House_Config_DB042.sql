/*<info serverAlias="DB042-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20240401@Aries
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DB042-bodb02

*/

USE bodb02
GO

IF NOT EXISTS (SELECT 1 FROM RepInfoGroup WITH(NOLOCK) WHERE GroupID = 2)
BEGIN
	INSERT INTO RepInfoGroup(GroupID,SourceServerName,SourceDBName)
	VALUES (2,'DBTRANS','bodb02')
END


IF NOT EXISTS (SELECT 1 FROM RepInfo WITH(NOLOCK)  WHERE [group] = 2 AND [name] = 'LuckyDrawList' )
BEGIN
	INSERT INTO RepInfo([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size )
	SELECT 2										AS [group]
		  ,'LuckyDrawList'							AS [name]
		  ,1										AS active
		  ,'RepUpdateTime'							AS version_key
		  ,0										AS version_type
		  ,'DrawID'									AS unique_key 
		  ,'Repl_GetLuckyDrawList'					AS get_sp
		  ,'Repl_PutLuckyDrawList'					AS put_sp
		  ,1000										AS interval
		  ,10										AS back_fix
		  ,60000									AS delayed_fix
		  ,0										AS batch_size
END	
