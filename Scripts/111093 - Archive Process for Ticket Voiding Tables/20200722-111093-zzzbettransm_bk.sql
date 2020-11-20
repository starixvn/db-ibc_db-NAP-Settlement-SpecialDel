/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[zzzbettransm_bk](
	[transid] [bigint] NOT NULL,
	[custid] [int] NOT NULL,
	[transdate] [datetime] NOT NULL,
	[oddsid] [int] NOT NULL,
	[hdp1] [smallmoney] NULL,
	[hdp2] [smallmoney] NULL,
	[odds] [smallmoney] NULL,
	[stake] [money] NOT NULL,
	[status] [nvarchar](10) NULL,
	[winlost] [money] NULL,
	[livehomescore] [smallint] NULL,
	[liveawayscore] [smallint] NULL,
	[liveindicator] [bit] NULL,
	[betteam] [nvarchar](10) NULL,
	[creator] [int] NOT NULL,
	[refno] [bigint] NULL,
	[comstatus] [nvarchar](20) NULL,
	[winlostdate] [smalldatetime] NULL,
	[betfrom] [nvarchar](1) NULL,
	[betcheck] [nvarchar](50) NULL,
	[checktime] [datetime] NULL,
	[matchid] [int] NULL,
	[bettype] [smallint] NULL,
	[keyid] [int] NOT NULL,
	[VoidingHistoryId] [int] NULL,
 ) ON [DATA]

GO


