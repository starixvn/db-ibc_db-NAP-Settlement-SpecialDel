/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231016@Aries  
	Task: Auto Send Announcement When Refund VS [Redmine:#195333]
	DB: DBTXN/bodb02
*/
USE bodb02

UPDATE   Single_Calculate_Queue_VS
SET IsCalculating = 2
WHERE matchid    in (76541308,76541306,76542139,76542141,76541980,76541983,76541984,76542215,76542229,76541311)