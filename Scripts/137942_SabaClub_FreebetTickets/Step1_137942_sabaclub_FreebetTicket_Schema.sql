/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: Helen
	Date: 20200826
	Task: Saba.club - Offer Freebet tickets for 789y market - https://nexdev.net/issues/137942
	DB: DBTRANS/bodb02
	
	Notes:
		StatusID
		0: Initial data
		1: Sent to vendor and upload message already

*/
USE [bodb02]
GO
CREATE TABLE [dbo].[LuckyDraw3rd](
	[ID] INT IDENTITY(1,1) NOT NULL,
	[Sporttype] TINYINT,
	[RoundID] INT,	
	[CustID] INT ,
	[FreeSpinCount] INT NULL,
	[CreatedDate] DATETIME NULL,
	[SentDate] DATETIME NULL,
	[ShowBannerEndDate] DATETIME NULL,
	[StatusId] TINYINT NULL,
	[srecommend] INT NULL,
	[mrecommend] INT NULL,
	[recommend] INT NULL,
	[NetWinLoss] MONEY NUll,
	
 CONSTRAINT [LuckyDraw3rd_ID] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [DATA]
) ON [DATA]

CREATE CLUSTERED INDEX [CIX_SportType_CustID_RoundID] ON [dbo].[LuckyDraw3rd] 
(
	[Sporttype] ASC,
	[custid] ASC,
	[RoundID] ASC
)
GO

CREATE NONCLUSTERED INDEX inx_LuckyDraw3rd ON [LuckyDraw3rd] (custID)
INCLUDE(ShowBannerEndDate)
