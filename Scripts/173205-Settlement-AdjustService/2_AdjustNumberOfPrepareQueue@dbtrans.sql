/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: adjust number of prepare queue

USE bodb02
GO

ALTER SERVICE [bet_settle_receive_service_prepare_02]  ON QUEUE [dbo].[bet_settle_queue_prepare_02] 
GO
