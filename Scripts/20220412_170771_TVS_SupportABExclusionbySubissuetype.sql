/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*
	Created by: July
	Task : [TVS] Support AB Exclusion by sub issue type
	DB: DBTXN/bodb02 [Replicated Server for DBTrans_API_Data]

	Revisions:
		- 20220412@July: Add new 2 column SubType & VoidVIP [Redmine:#170771]

	Note: DBTXN & sycn MNL/AWS	
*/

ALTER TABLE dbo.TicketVoiding_ABWhiteList
ADD AllowVoidSubType 	VARCHAR(100),
	IsAllowVoidVip		BIT DEFAULT(0)