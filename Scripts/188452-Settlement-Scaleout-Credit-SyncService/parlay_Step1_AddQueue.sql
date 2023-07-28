/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/
USE bodb02
go
---- parlay
--for ssb
CREATE MESSAGE TYPE [sitedb3_bet_settle_msg_type_parlay] VALIDATION = NONE
GO

CREATE CONTRACT [sitedb3_bet_settle_contract_parlay] ([sitedb3_bet_settle_msg_type_parlay] SENT BY ANY)
GO

CREATE QUEUE sitedb3_bet_settle_queue_parlay WITH STATUS = ON , RETENTION = OFF ON [DATA] 
GO

CREATE SERVICE [sitedb3_bet_settle_receive_service_parlay]  ON QUEUE [dbo].[sitedb3_bet_settle_queue_parlay] ([sitedb3_bet_settle_contract_parlay])
GO
CREATE SERVICE [sitedb3_bet_settle_send_service_parlay]  ON QUEUE [dbo].[sitedb3_bet_settle_queue_parlay] ([sitedb3_bet_settle_contract_parlay])
GO

