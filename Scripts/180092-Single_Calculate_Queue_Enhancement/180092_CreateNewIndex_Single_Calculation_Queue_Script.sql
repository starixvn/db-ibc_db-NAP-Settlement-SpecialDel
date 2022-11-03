/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221103@Helen
    Task: Create new index for Single_Calculate_Queue
    DB: DBTXN-bodb02

	 Revisions:
		- 20221103@Helen: SP Enhancement [Redmine:#180092]

*/
USE bodb02
GO
CREATE NONCLUSTERED INDEX IX_IsCalculating ON Single_Calculate_Queue (IsCalculating) INCLUDE (execTime, sporttype)
WITH (ONLINE = ON) ON [Event_table]
GO

