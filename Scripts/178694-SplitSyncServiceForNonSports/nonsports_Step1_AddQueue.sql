/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/
USE bodb02
go
--for ssb
CREATE MESSAGE TYPE [sitedb1_bet_settle_msg_type_3rd] VALIDATION = NONE
GO
CREATE MESSAGE TYPE [sitedb2_bet_settle_msg_type_3rd] VALIDATION = NONE
GO


CREATE CONTRACT [sitedb1_bet_settle_contract_3rd] ([sitedb1_bet_settle_msg_type_3rd] SENT BY ANY)
GO

CREATE CONTRACT [sitedb2_bet_settle_contract_3rd] ([sitedb2_bet_settle_msg_type_3rd] SENT BY ANY)
GO

CREATE QUEUE sitedb1_bet_settle_queue_3rd WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO
GO
CREATE QUEUE [dbo].[sitedb2_bet_settle_queue_3rd] WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO

CREATE SERVICE [sitedb1_bet_settle_receive_service_3rd]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_3rd] ([sitedb1_bet_settle_contract_3rd])
GO
CREATE SERVICE [sitedb2_bet_settle_receive_service_3rd]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_3rd] ([sitedb2_bet_settle_contract_3rd])
GO
CREATE SERVICE [sitedb1_bet_settle_send_service_3rd]  ON QUEUE [dbo].[sitedb1_bet_settle_queue_3rd] ([sitedb1_bet_settle_contract_3rd])
GO
CREATE SERVICE [sitedb2_bet_settle_send_service_3rd]  ON QUEUE [dbo].[sitedb2_bet_settle_queue_3rd] ([sitedb2_bet_settle_contract_3rd])
GO


