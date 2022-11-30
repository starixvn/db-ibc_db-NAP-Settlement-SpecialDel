/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Create new table for chatbot dbo.TicketVoiding_Chatbot  [Redmine:#180625]  
	DB: DBCTG-bodb02
		
*/
USE bodb02
GO

CREATE TABLE [dbo].[TicketVoiding_Chatbot](
	Id INT IDENTITY(1,1),
	RequestId INT,
	VoidingHistoryId INT,
	StatusId TINYINT,
	MessageId INT,
	MessageKey VARCHAR(100),
 CONSTRAINT [TicketVoiding_Chatbot_Id] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA]
GO
