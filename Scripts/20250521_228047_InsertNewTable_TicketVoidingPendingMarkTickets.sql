/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20250523@Lani
	Task: [TVS] Enhance TVS in case 1 or many siteDBs down - Add/Save request - [Redmine: #228047]
	DB: DBCTG/bodb02
*/
USE bodb02;
GO

CREATE TABLE [dbo].[TicketVoiding_PendingMarkTickets](
	[Id] [INT] IDENTITY(1,1) NOT NULL,
	[TransId] [BIGINT] NOT NULL,
	[MatchId] [INT] NULL,
	[StatusId] [TINYINT] NULL,
	[RequestId] [INT] NULL,
	[SiteDBGroupId] [SMALLINT] NOT NULL,
	[CreatedDate] [DATETIME] DEFAULT GETDATE() NOT NULL,
	[ModifiedDate] [DATETIME] DEFAULT GETDATE() NOT NULL
	CONSTRAINT [PK_TicketVoiding_PendingMarkTickets_Id] PRIMARY KEY CLUSTERED 
	(
		[Id] ASC
	) WITH (
		PAD_INDEX = OFF, 
		STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, 
		ALLOW_ROW_LOCKS = ON, 
		ALLOW_PAGE_LOCKS = ON, 
		OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
	) ON [DATA]
) ON [DATA];
GO
