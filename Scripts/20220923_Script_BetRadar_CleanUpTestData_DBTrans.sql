-----------STEP 1: ALTER SP ExecRep on DBTRANS ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_09]
(
	
)
/*
	Created by: 20220923@Victoria
    Task: Delete unused test data of BetRadar
    DB: DBCTG-bodb02

	 Revisions:
		- 20220923@Victoria: Delete unused test data of BetRadar [Redmineid:#178134] 

*/	
AS
BEGIN

	USE bodb02

	DELETE b
	FROM bettransm b WITH (ROWLOCK)
	WHERE b.TransId IN (1344535919, 1344535992, 1344536044, 1344536089, 1344536112, 1344548627, 1344548731 ,1344548763, 1344548832, 1344548982, 1344549079)
		AND betcheck LIKE 'Test Player%'
			
END

GO
-----------STEP 2: NEED TO RUN ON DBTRANS ONLY - Delete unused test data of BetRadar at DBTRANS & ALL SubDB ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

EXEC ExecRep_NAP_Admin_09