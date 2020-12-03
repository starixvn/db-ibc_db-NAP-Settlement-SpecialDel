/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201118@Max
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

ALTER TABLE [dbo].[Ticketvoiding_VoidBetAutomation_Service]
ADD
    [IsAutoVoid] [bit] NULL,
	[IsRunExternalService] [bit] NULL,
	[MessageId] [int] NULL,
	[ReasonId] [int] NULL,
	[IsSentBatchMessage] [bit] NULL,
	[IsSentMessageToAdminSite] [bit] NULL,
	[IsInsertedVoidedTransaction] [bit] NULL,
	[IsUpdatedVoidingHistory] [bit] NULL,
	[IsSentEmail] [bit] NULL,
	[IsSentLetsTalk] [bit] NULL
GO






