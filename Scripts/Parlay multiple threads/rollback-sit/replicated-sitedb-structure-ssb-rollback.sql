/*<info serverAlias="SBSETTLE-bodb02"></info>*/


drop SERVICE [sitedb1_parlaybet_settle_receive_service_01] 
GO
drop SERVICE [sitedb1_parlaybet_settle_receive_service_02]  
GO
drop SERVICE [sitedb1_parlaybet_settle_receive_service_03]  
GO
drop SERVICE [sitedb1_parlaybet_settle_receive_service_04]  
GO



drop SERVICE [sitedb2_parlaybet_settle_receive_service_01] 
GO
drop SERVICE [sitedb2_parlaybet_settle_receive_service_02] 
GO
drop SERVICE [sitedb2_parlaybet_settle_receive_service_03] 
GO
drop SERVICE [sitedb2_parlaybet_settle_receive_service_04]  
GO

drop SERVICE [sitedb3_parlaybet_settle_receive_service_01]  
GO
drop SERVICE [sitedb3_parlaybet_settle_receive_service_02]  
GO
drop SERVICE [sitedb3_parlaybet_settle_receive_service_03]  
GO
drop SERVICE [sitedb3_parlaybet_settle_receive_service_04]  
GO


drop SERVICE [sitedb1_parlaybet_settle_send_service_01]  
GO
drop SERVICE [sitedb1_parlaybet_settle_send_service_02]  
GO
drop SERVICE [sitedb1_parlaybet_settle_send_service_03]  
GO
drop SERVICE [sitedb1_parlaybet_settle_send_service_04]  
GO



drop SERVICE [sitedb2_parlaybet_settle_send_service_01]  
GO
drop SERVICE [sitedb2_parlaybet_settle_send_service_02]  
GO
drop SERVICE [sitedb2_parlaybet_settle_send_service_03]  
GO
drop SERVICE [sitedb2_parlaybet_settle_send_service_04]  
GO

drop SERVICE [sitedb3_parlaybet_settle_send_service_01]  
GO
drop SERVICE [sitedb3_parlaybet_settle_send_service_02]  
GO
drop SERVICE [sitedb3_parlaybet_settle_send_service_03]  
GO
drop SERVICE [sitedb3_parlaybet_settle_send_service_04]  
GO


drop QUEUE [dbo].[sitedb1_parlaybet_settle_queue_01] 
GO
drop QUEUE [dbo].[sitedb1_parlaybet_settle_queue_02]  
GO
drop QUEUE [dbo].[sitedb1_parlaybet_settle_queue_03] 
GO
drop QUEUE [dbo].[sitedb1_parlaybet_settle_queue_04] 
GO


drop QUEUE [dbo].[sitedb2_parlaybet_settle_queue_01] 
GO
drop QUEUE [dbo].[sitedb2_parlaybet_settle_queue_02] 
GO
drop QUEUE [dbo].[sitedb2_parlaybet_settle_queue_03] 
GO
drop QUEUE [dbo].[sitedb2_parlaybet_settle_queue_04]  
GO

drop QUEUE [dbo].[sitedb3_parlaybet_settle_queue_01]  
GO
drop QUEUE [dbo].[sitedb3_parlaybet_settle_queue_02] 
GO
drop QUEUE [dbo].[sitedb3_parlaybet_settle_queue_03] 
GO
drop QUEUE [dbo].[sitedb3_parlaybet_settle_queue_04] 
GO

drop CONTRACT [sitedb1_parlaybet_settle_contract_01] 
GO
drop CONTRACT [sitedb1_parlaybet_settle_contract_02] 
GO
drop CONTRACT [sitedb1_parlaybet_settle_contract_03] 
GO
drop CONTRACT [sitedb1_parlaybet_settle_contract_04] 
GO



drop CONTRACT [sitedb2_parlaybet_settle_contract_01] 
GO																 
drop CONTRACT [sitedb2_parlaybet_settle_contract_02] 
GO																 
drop CONTRACT [sitedb2_parlaybet_settle_contract_03]
GO																 
drop CONTRACT [sitedb2_parlaybet_settle_contract_04] 
GO


drop CONTRACT [sitedb3_parlaybet_settle_contract_01] 
GO
drop CONTRACT [sitedb3_parlaybet_settle_contract_02] 
GO
drop CONTRACT [sitedb3_parlaybet_settle_contract_03] 
GO
drop CONTRACT [sitedb3_parlaybet_settle_contract_04] 
GO


--for ssb
drop MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_01] 
GO
drop MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_02] 
GO
drop MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_03] 
GO
drop MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_04] 
GO


drop MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_01] 
GO
drop MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_02] 
GO
drop MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_03] 
GO
drop MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_04] 
GO


drop MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_01] 
GO
drop MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_02] 
GO
drop MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_03] 
GO
drop MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_04] 
GO



