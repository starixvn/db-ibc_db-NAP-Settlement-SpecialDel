/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/

--for ssb
CREATE MESSAGE TYPE [sitedb1_bet_settle_msg_type] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb1_bet_settle_msg_type_01] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb1_bet_settle_msg_type_02] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb1_bet_settle_msg_type_03] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb1_bet_settle_msg_type_04] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_bet_settle_msg_type] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_bet_settle_msg_type_01] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_bet_settle_msg_type_02] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_bet_settle_msg_type_03] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_bet_settle_msg_type_04] VALIDATION = NONE
GO
CREATE CONTRACT [sitedb1_bet_settle_contract] ([sitedb1_bet_settle_msg_type] SENT BY ANY)
GO
CREATE CONTRACT [sitedb1_bet_settle_contract_01] ([sitedb1_bet_settle_msg_type_01] SENT BY ANY)
GO
CREATE CONTRACT [sitedb1_bet_settle_contract_02] ([sitedb1_bet_settle_msg_type_02] SENT BY ANY)
GO
CREATE CONTRACT [sitedb1_bet_settle_contract_03] ([sitedb1_bet_settle_msg_type_03] SENT BY ANY)
GO
CREATE CONTRACT [sitedb1_bet_settle_contract_04] ([sitedb1_bet_settle_msg_type_04] SENT BY ANY)
GO
CREATE CONTRACT [sitedb2_bet_settle_contract] ([sitedb2_bet_settle_msg_type] SENT BY ANY)
GO
CREATE CONTRACT [sitedb2_bet_settle_contract_01] ([sitedb2_bet_settle_msg_type_01] SENT BY ANY)
GO
CREATE CONTRACT [sitedb2_bet_settle_contract_02] ([sitedb2_bet_settle_msg_type_02] SENT BY ANY)
GO
CREATE CONTRACT [sitedb2_bet_settle_contract_03] ([sitedb2_bet_settle_msg_type_03] SENT BY ANY)
GO
CREATE CONTRACT [sitedb2_bet_settle_contract_04] ([sitedb2_bet_settle_msg_type_04] SENT BY ANY)
GO

CREATE QUEUE sitedb1_bet_settle_queue WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb1_bet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb1_bet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb1_bet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb1_bet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_bet_settle_queue] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_bet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_bet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_bet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_bet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO

CREATE SERVICE [sitedb1_bet_settle_receive_service]  ON QUEUE [dbo].[sitedb1_bet_settle_queue] ([sitedb1_bet_settle_contract])
GO
CREATE SERVICE [sitedb1_bet_settle_receive_service_01]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_01] ([sitedb1_bet_settle_contract_01])
GO
CREATE SERVICE [sitedb1_bet_settle_receive_service_02]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_02] ([sitedb1_bet_settle_contract_02])
GO
CREATE SERVICE [sitedb1_bet_settle_receive_service_03]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_03] ([sitedb1_bet_settle_contract_03])
GO
CREATE SERVICE [sitedb1_bet_settle_receive_service_04]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_04] ([sitedb1_bet_settle_contract_04])
GO
CREATE SERVICE [sitedb2_bet_settle_receive_service]  ON QUEUE [dbo].[sitedb2_bet_settle_queue] ([sitedb2_bet_settle_contract])
GO
CREATE SERVICE [sitedb2_bet_settle_receive_service_01]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_01] ([sitedb2_bet_settle_contract_01])
GO
CREATE SERVICE [sitedb2_bet_settle_receive_service_02]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_02] ([sitedb2_bet_settle_contract_02])
GO
CREATE SERVICE [sitedb2_bet_settle_receive_service_03]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_03] ([sitedb2_bet_settle_contract_03])
GO
CREATE SERVICE [sitedb2_bet_settle_receive_service_04]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_04] ([sitedb2_bet_settle_contract_04])
GO
CREATE SERVICE [sitedb1_bet_settle_send_service]  ON QUEUE [dbo].[sitedb1_bet_settle_queue] ([sitedb1_bet_settle_contract])
GO
CREATE SERVICE [sitedb1_bet_settle_send_service_01]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_01] ([sitedb1_bet_settle_contract_01])
GO
CREATE SERVICE [sitedb1_bet_settle_send_service_02]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_02] ([sitedb1_bet_settle_contract_02])
GO
CREATE SERVICE [sitedb1_bet_settle_send_service_03]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_03] ([sitedb1_bet_settle_contract_03])
GO
CREATE SERVICE [sitedb1_bet_settle_send_service_04]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_04] ([sitedb1_bet_settle_contract_04])
GO
CREATE SERVICE [sitedb2_bet_settle_send_service]  ON QUEUE [dbo].[sitedb2_bet_settle_queue] ([sitedb2_bet_settle_contract])
GO
CREATE SERVICE [sitedb2_bet_settle_send_service_01]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_01] ([sitedb2_bet_settle_contract_01])
GO
CREATE SERVICE [sitedb2_bet_settle_send_service_02]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_02] ([sitedb2_bet_settle_contract_02])
GO
CREATE SERVICE [sitedb2_bet_settle_send_service_03]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_03] ([sitedb2_bet_settle_contract_03])
GO
CREATE SERVICE [sitedb2_bet_settle_send_service_04]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_04] ([sitedb2_bet_settle_contract_04])
GO