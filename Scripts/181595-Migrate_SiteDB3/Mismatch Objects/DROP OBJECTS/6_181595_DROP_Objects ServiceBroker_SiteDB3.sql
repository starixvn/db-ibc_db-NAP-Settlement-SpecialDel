/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230714@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230714@Louisa: Drop MESSAGE, CONTRACT, QUEUE, SERVICE not in-use [Redmineid:#181595]					
	
*/

---RUN ON SITEDB3 ONLY

USE bodb02
GO
  
	DROP SERVICE sitedb1_bet_settle_receive_service
	GO
	DROP SERVICE sitedb1_bet_settle_receive_service_01
	GO
	DROP SERVICE sitedb1_bet_settle_receive_service_02
	GO
	DROP SERVICE sitedb1_bet_settle_receive_service_03
	GO
	DROP SERVICE sitedb1_bet_settle_receive_service_04
	GO
	DROP SERVICE sitedb1_bet_settle_receive_service_3rd
	GO
	DROP SERVICE sitedb1_bet_settle_receive_service_parlay
	GO
	DROP SERVICE sitedb1_bet_settle_send_service
	GO
	DROP SERVICE sitedb1_bet_settle_send_service_01
	GO
	DROP SERVICE sitedb1_bet_settle_send_service_02
	GO
	DROP SERVICE sitedb1_bet_settle_send_service_03
	GO
	DROP SERVICE sitedb1_bet_settle_send_service_04
	GO
	DROP SERVICE sitedb1_bet_settle_send_service_3rd
	GO
	DROP SERVICE sitedb1_bet_settle_send_service_parlay
	-------------------------------------------------------
	DROP SERVICE sitedb2_bet_settle_receive_service
	GO
	DROP SERVICE sitedb2_bet_settle_receive_service_01
	GO
	DROP SERVICE sitedb2_bet_settle_receive_service_02
	GO
	DROP SERVICE sitedb2_bet_settle_receive_service_03
	GO
	DROP SERVICE sitedb2_bet_settle_receive_service_04
	GO
	DROP SERVICE sitedb2_bet_settle_receive_service_3rd
	GO
	DROP SERVICE sitedb2_bet_settle_receive_service_parlay
	GO
	DROP SERVICE sitedb2_bet_settle_send_service
	GO
	DROP SERVICE sitedb2_bet_settle_send_service_01
	GO
	DROP SERVICE sitedb2_bet_settle_send_service_02
	GO
	DROP SERVICE sitedb2_bet_settle_send_service_03
	GO
	DROP SERVICE sitedb2_bet_settle_send_service_04
	GO
	DROP SERVICE sitedb2_bet_settle_send_service_3rd
	GO
	DROP SERVICE sitedb2_bet_settle_send_service_parlay
	GO
	-------------------------------------------------
	DROP QUEUE sitedb1_bet_settle_queue
	GO
	DROP QUEUE sitedb1_bet_settle_queue_01
	GO
	DROP QUEUE sitedb1_bet_settle_queue_02
	GO
	DROP QUEUE sitedb1_bet_settle_queue_03
	GO
	DROP QUEUE sitedb1_bet_settle_queue_04
	GO
	DROP QUEUE sitedb1_bet_settle_queue_3rd
	GO
	DROP QUEUE sitedb1_bet_settle_queue_parlay
	GO
	DROP QUEUE sitedb2_bet_settle_queue
	GO
	DROP QUEUE sitedb2_bet_settle_queue_01
	GO
	DROP QUEUE sitedb2_bet_settle_queue_02
	GO
	DROP QUEUE sitedb2_bet_settle_queue_03
	GO
	DROP QUEUE sitedb2_bet_settle_queue_04
	GO
	DROP QUEUE sitedb2_bet_settle_queue_3rd
	GO
	DROP QUEUE sitedb2_bet_settle_queue_parlay
	GO
	-----------------------------------------------------------
	DROP CONTRACT sitedb1_bet_settle_contract
	GO
	DROP CONTRACT sitedb1_bet_settle_contract_01
	GO
	DROP CONTRACT sitedb1_bet_settle_contract_02
	GO
	DROP CONTRACT sitedb1_bet_settle_contract_03
	GO
	DROP CONTRACT sitedb1_bet_settle_contract_04
	GO
	DROP CONTRACT sitedb1_bet_settle_contract_3rd
	GO
	DROP CONTRACT sitedb1_bet_settle_contract_parlay
	GO
	DROP CONTRACT sitedb2_bet_settle_contract
	GO
	DROP CONTRACT sitedb2_bet_settle_contract_01
	GO
	DROP CONTRACT sitedb2_bet_settle_contract_02
	GO
	DROP CONTRACT sitedb2_bet_settle_contract_03
	GO
	DROP CONTRACT sitedb2_bet_settle_contract_04
	GO
	DROP CONTRACT sitedb2_bet_settle_contract_3rd
	GO
	DROP CONTRACT sitedb2_bet_settle_contract_parlay
	GO
	----------------------------------------------------
	DROP MESSAGE TYPE sitedb1_bet_settle_msg_type
	GO
	DROP MESSAGE TYPE sitedb1_bet_settle_msg_type_01
	GO
	DROP MESSAGE TYPE sitedb1_bet_settle_msg_type_02
	GO
	DROP MESSAGE TYPE sitedb1_bet_settle_msg_type_03
	GO
	DROP MESSAGE TYPE sitedb1_bet_settle_msg_type_04
	GO
	DROP MESSAGE TYPE sitedb1_bet_settle_msg_type_3rd
	GO
	DROP MESSAGE TYPE sitedb1_bet_settle_msg_type_parlay
	GO
	DROP MESSAGE TYPE sitedb2_bet_settle_msg_type
	GO
	DROP MESSAGE TYPE sitedb2_bet_settle_msg_type_01
	GO
	DROP MESSAGE TYPE sitedb2_bet_settle_msg_type_02
	GO
	DROP MESSAGE TYPE sitedb2_bet_settle_msg_type_03
	GO
	DROP MESSAGE TYPE sitedb2_bet_settle_msg_type_04
	GO
	DROP MESSAGE TYPE sitedb2_bet_settle_msg_type_3rd
	GO
	DROP MESSAGE TYPE sitedb2_bet_settle_msg_type_parlay
	GO

