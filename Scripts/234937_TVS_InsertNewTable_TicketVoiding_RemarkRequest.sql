/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20251117@Lani
	Task: [TVS] Manage Remark - New function to remark issue of matches - Add new table TicketVoiding_RemarkRequest [Redmine: #234937]
	DB: DBCTG/bodb02
*/
USE bodb02;
GO

CREATE TABLE [dbo].[TicketVoiding_RemarkRequest](
	[RemarkNo] [INT] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[MatchId] [INT] NULL,
	[IsTest] [BIT] NULL,
	[IsCheckedVar] [BIT] NULL,
	[MistakenBy] [NVARCHAR](200) NULL,
	[DecidedBy] [NVARCHAR](200) NULL,
	[PerformedBy] [NVARCHAR](200) NULL,
	[TV_IPTV] [NVARCHAR](200) NULL,
	[Provider] [NVARCHAR](200) NULL,
	[Source] [NVARCHAR] (200) NULL,
	[Remark] [NVARCHAR] (MAX) NULL,
	[Message] [NVARCHAR] (MAX) NULL,
	[Description] [NVARCHAR] (MAX) NULL,
	[Action] [VARCHAR](20) NULL,
	[CreatedDate] [DATETIME] DEFAULT GETDATE() NOT NULL,
	[ModifiedDate] [DATETIME] DEFAULT GETDATE() NOT NULL,

	CONSTRAINT [PK_TicketVoiding_RemarkRequest_RemarkNo] PRIMARY KEY CLUSTERED 
	(
		[RemarkNo] ASC
	) WITH (
		PAD_INDEX = OFF, 
		STATISTICS_NORECOMPUTE = OFF, 
		IGNORE_DUP_KEY = OFF, 
		ALLOW_ROW_LOCKS = ON, 
		ALLOW_PAGE_LOCKS = ON, 
		OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
	) ON [DATA]
) ON [DATA] TEXTIMAGE_ON [DATA];
GO

