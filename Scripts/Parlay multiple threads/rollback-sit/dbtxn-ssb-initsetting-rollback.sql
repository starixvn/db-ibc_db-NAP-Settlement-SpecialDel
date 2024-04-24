/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240215@Kathy
	Task	  : drop setting
	DB		  : 
*/
USE [bodb02]
GO

delete from sb.[ConfigurationReference] where functionname = 'parlaysettlement'
delete from sb.[ConversationCount] where functionname = 'parlaysettlement'
delete from sb.[ConfigurationReferenceDetail]  where functionname = 'parlaysettlement'
