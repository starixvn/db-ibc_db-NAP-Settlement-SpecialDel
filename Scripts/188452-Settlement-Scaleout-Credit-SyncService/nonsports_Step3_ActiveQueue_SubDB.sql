/*<info serverAlias="SBSETTLE-bodb02,DBBAL-bodb02"></info>*/
--dbtrans
ALTER QUEUE [dbo].[sitedb3_bet_settle_queue_3rd] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB3_Replicated_Process_Message_3rd] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
