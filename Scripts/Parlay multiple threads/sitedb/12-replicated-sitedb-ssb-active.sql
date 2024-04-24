/*<info serverAlias="SBSETTLE-bodb02"></info>*/

----replicated
ALTER QUEUE [dbo].[sitedb1_parlaybet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB1_Replicated_Process_Message_parlay_01] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb1_parlaybet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB1_Replicated_Process_Message_parlay_02] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb1_parlaybet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB1_Replicated_Process_Message_parlay_03] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb1_parlaybet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB1_Replicated_Process_Message_parlay_04] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 

ALTER QUEUE [dbo].[sitedb2_parlaybet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB2_Replicated_Process_Message_parlay_01] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb2_parlaybet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB2_Replicated_Process_Message_parlay_02] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb2_parlaybet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB2_Replicated_Process_Message_parlay_03] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb2_parlaybet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB2_Replicated_Process_Message_parlay_04] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 


ALTER QUEUE [dbo].[sitedb3_parlaybet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB3_Replicated_Process_Message_parlay_01] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb3_parlaybet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB3_Replicated_Process_Message_parlay_02] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb3_parlaybet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB3_Replicated_Process_Message_parlay_03] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 
ALTER QUEUE [dbo].[sitedb3_parlaybet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF , ACTIVATION (  STATUS = ON , PROCEDURE_NAME = [dbo].[SSB_Settlement_SiteDB3_Replicated_Process_Message_parlay_04] , MAX_QUEUE_READERS = 1 , EXECUTE AS N'dbo'  ), POISON_MESSAGE_HANDLING (STATUS = ON) 


