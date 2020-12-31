/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201231@Max
	Task: TVS - New issue type Abnormal Accounts - [Redmine: #143666]
	DB: DBACC-bodb02 [Replicated Server for DBTrans_API_Data]
*/

USE bodb02
GO

CREATE TABLE [dbo].[Ticketvoiding_VoidBetAutomation_Service](
	[ID] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[RequestID] [int] NULL,
	[VoidingHistory] [int] NULL,
	[statusID] [tinyint] NULL,
	[matchID] [int] NULL,
	[SessionID] [int] NULL,
	[NegativeBalanceUsers] [varchar](max) NULL,
	[createdDate] [datetime] NULL,
	[ModifiedDate] [datetime] NULL,
	[VoidResults] [xml] NULL,
	[IsAutoVoid] [bit] NULL,
	[IsRunExternalService] [bit] NULL,
	[MessageId] [int] NULL,
	[ReasonId] [int] NULL,
	[IsSentBatchMessage] [bit] NULL,
	[IsSentMessageToAdminSite] [bit] NULL,
	[IsInsertedVoidedTransaction] [bit] NULL,
	[IsUpdatedVoidingHistory] [bit] NULL,
	[IsSentEmail] [bit] NULL,
	[IsSentLetsTalk] [bit] NULL,
 CONSTRAINT [PK_Ticketvoiding_VoidBetAutomation_Service_ID] PRIMARY KEY NONCLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[Ticketvoiding_VoidBetAutomation_Service] ADD  CONSTRAINT [DF_Ticketvoiding_VoidBetAutomation_Service_createdDate]  DEFAULT (getdate()) FOR [createdDate]
GO


