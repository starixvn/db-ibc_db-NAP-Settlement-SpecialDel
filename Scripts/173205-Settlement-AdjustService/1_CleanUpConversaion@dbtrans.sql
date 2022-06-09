/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: adjust number of prepare queue

USE bodb02
GO


select 'end conversation ''' + cast(conversation_handle as varchar(200)) +''' with cleanup ', * from sys.conversation_endpoints where far_service like 'bet_set%'

