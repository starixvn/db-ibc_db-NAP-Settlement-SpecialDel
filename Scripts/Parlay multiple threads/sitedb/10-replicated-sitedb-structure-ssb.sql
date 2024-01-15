/*<info serverAlias="SBSETTLE-bodb02"></info>*/

--for ssb
CREATE MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_01] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_02] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_03] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb1_parlaybet_settle_msg_type_04] VALIDATION = NONE
GO


CREATE MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_01] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_02] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_03] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_parlaybet_settle_msg_type_04] VALIDATION = NONE
GO


CREATE MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_01] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_02] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_03] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb3_parlaybet_settle_msg_type_04] VALIDATION = NONE
GO



CREATE CONTRACT [sitedb1_parlaybet_settle_contract_01] ([sitedb1_parlaybet_settle_msg_type_01] SENT BY ANY)
GO
CREATE CONTRACT [sitedb1_parlaybet_settle_contract_02] ([sitedb1_parlaybet_settle_msg_type_02] SENT BY ANY)
GO
CREATE CONTRACT [sitedb1_parlaybet_settle_contract_03] ([sitedb1_parlaybet_settle_msg_type_03] SENT BY ANY)
GO
CREATE CONTRACT [sitedb1_parlaybet_settle_contract_04] ([sitedb1_parlaybet_settle_msg_type_04] SENT BY ANY)
GO



CREATE CONTRACT [sitedb2_parlaybet_settle_contract_01] ([sitedb2_parlaybet_settle_msg_type_01] SENT BY ANY)
GO																 
CREATE CONTRACT [sitedb2_parlaybet_settle_contract_02] ([sitedb2_parlaybet_settle_msg_type_02] SENT BY ANY)
GO																 
CREATE CONTRACT [sitedb2_parlaybet_settle_contract_03] ([sitedb2_parlaybet_settle_msg_type_03] SENT BY ANY)
GO																 
CREATE CONTRACT [sitedb2_parlaybet_settle_contract_04] ([sitedb2_parlaybet_settle_msg_type_04] SENT BY ANY)
GO


CREATE CONTRACT [sitedb3_parlaybet_settle_contract_01] ([sitedb3_parlaybet_settle_msg_type_01] SENT BY ANY)
GO
CREATE CONTRACT [sitedb3_parlaybet_settle_contract_02] ([sitedb3_parlaybet_settle_msg_type_02] SENT BY ANY)
GO
CREATE CONTRACT [sitedb3_parlaybet_settle_contract_03] ([sitedb3_parlaybet_settle_msg_type_03] SENT BY ANY)
GO
CREATE CONTRACT [sitedb3_parlaybet_settle_contract_04] ([sitedb3_parlaybet_settle_msg_type_04] SENT BY ANY)
GO


CREATE QUEUE [dbo].[sitedb1_parlaybet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb1_parlaybet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb1_parlaybet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb1_parlaybet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO


CREATE QUEUE [dbo].[sitedb2_parlaybet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_parlaybet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_parlaybet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb2_parlaybet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO

CREATE QUEUE [dbo].[sitedb3_parlaybet_settle_queue_01] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb3_parlaybet_settle_queue_02] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb3_parlaybet_settle_queue_03] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
CREATE QUEUE [dbo].[sitedb3_parlaybet_settle_queue_04] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO

CREATE SERVICE [sitedb1_parlaybet_settle_receive_service_01]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_01] ([sitedb1_parlaybet_settle_contract_01])
GO
CREATE SERVICE [sitedb1_parlaybet_settle_receive_service_02]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_02] ([sitedb1_parlaybet_settle_contract_02])
GO
CREATE SERVICE [sitedb1_parlaybet_settle_receive_service_03]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_03] ([sitedb1_parlaybet_settle_contract_03])
GO
CREATE SERVICE [sitedb1_parlaybet_settle_receive_service_04]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_04] ([sitedb1_parlaybet_settle_contract_04])
GO



CREATE SERVICE [sitedb2_parlaybet_settle_receive_service_01]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_01] ([sitedb2_parlaybet_settle_contract_01])
GO
CREATE SERVICE [sitedb2_parlaybet_settle_receive_service_02]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_02] ([sitedb2_parlaybet_settle_contract_02])
GO
CREATE SERVICE [sitedb2_parlaybet_settle_receive_service_03]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_03] ([sitedb2_parlaybet_settle_contract_03])
GO
CREATE SERVICE [sitedb2_parlaybet_settle_receive_service_04]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_04] ([sitedb2_parlaybet_settle_contract_04])
GO

CREATE SERVICE [sitedb3_parlaybet_settle_receive_service_01]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_01] ([sitedb3_parlaybet_settle_contract_01])
GO
CREATE SERVICE [sitedb3_parlaybet_settle_receive_service_02]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_02] ([sitedb3_parlaybet_settle_contract_02])
GO
CREATE SERVICE [sitedb3_parlaybet_settle_receive_service_03]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_03] ([sitedb3_parlaybet_settle_contract_03])
GO
CREATE SERVICE [sitedb3_parlaybet_settle_receive_service_04]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_04] ([sitedb3_parlaybet_settle_contract_04])
GO


CREATE SERVICE [sitedb1_parlaybet_settle_send_service_01]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_01] ([sitedb1_parlaybet_settle_contract_01])
GO
CREATE SERVICE [sitedb1_parlaybet_settle_send_service_02]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_02] ([sitedb1_parlaybet_settle_contract_02])
GO
CREATE SERVICE [sitedb1_parlaybet_settle_send_service_03]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_03] ([sitedb1_parlaybet_settle_contract_03])
GO
CREATE SERVICE [sitedb1_parlaybet_settle_send_service_04]  ON QUEUE [dbo].[sitedb1_parlaybet_settle_queue_04] ([sitedb1_parlaybet_settle_contract_04])
GO



CREATE SERVICE [sitedb2_parlaybet_settle_send_service_01]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_01] ([sitedb2_parlaybet_settle_contract_01])
GO
CREATE SERVICE [sitedb2_parlaybet_settle_send_service_02]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_02] ([sitedb2_parlaybet_settle_contract_02])
GO
CREATE SERVICE [sitedb2_parlaybet_settle_send_service_03]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_03] ([sitedb2_parlaybet_settle_contract_03])
GO
CREATE SERVICE [sitedb2_parlaybet_settle_send_service_04]  ON QUEUE [dbo].[sitedb2_parlaybet_settle_queue_04] ([sitedb2_parlaybet_settle_contract_04])
GO

CREATE SERVICE [sitedb3_parlaybet_settle_send_service_01]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_01] ([sitedb3_parlaybet_settle_contract_01])
GO
CREATE SERVICE [sitedb3_parlaybet_settle_send_service_02]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_02] ([sitedb3_parlaybet_settle_contract_02])
GO
CREATE SERVICE [sitedb3_parlaybet_settle_send_service_03]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_03] ([sitedb3_parlaybet_settle_contract_03])
GO
CREATE SERVICE [sitedb3_parlaybet_settle_send_service_04]  ON QUEUE [dbo].[sitedb3_parlaybet_settle_queue_04] ([sitedb3_parlaybet_settle_contract_04])
GO
