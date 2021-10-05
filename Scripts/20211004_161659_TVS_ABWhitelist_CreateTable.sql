/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*
	Created by: July
	Task : [TVS] Implement AB Whitelist
	DB: DBTXN/bodb02

	Revisions:
		- 20211004@July: Create new table [Redmine:#161659]

	Note: DBTXN & sycn MNL/AWS	
*/

CREATE TABLE dbo.TicketVoiding_ABWhiteList
(
	Custid				INT,
	LevelId				TINYINT,
	SiteId				INT,
	CreateBy			INT,
	CreatedDate			DATETIME,
	LastModifiedBy		INT,
	LastModifiedDate	DATETIME,

 CONSTRAINT [PK_TicketVoiding_ABWhiteList_Custid] PRIMARY KEY CLUSTERED 
(
	Custid ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA]

ALTER TABLE dbo.TicketVoiding_ABWhiteList ADD  CONSTRAINT [DF_TicketVoiding_ABWhiteList_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

ALTER TABLE dbo.TicketVoiding_ABWhiteList ADD  CONSTRAINT [DF_TicketVoiding_ABWhiteList_LastModifiedDate]  DEFAULT (getdate()) FOR [LastModifiedDate]
GO
