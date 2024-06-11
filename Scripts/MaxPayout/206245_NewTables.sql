--DROP TABLE [MaxPayout_CheckData]
--DROP TABLE [MaxPayout_CheckData_History]
--DROP TABLE [MaxPayout_CheckData_Problem]

USE [bodb02]
go
CREATE TABLE [dbo].[MaxPayout_CheckData](
	[custid] [int] NOT NULL,
	[matchid] [int] NOT NULL,
	[eventtypeid] [tinyint] NOT NULL,
	[roundVerified] [int] NULL,
	[DiffAmount] [money] NULL,
	[CreatedDate] DATETIME,
	[ModifiedDate] DATETIME,
 CONSTRAINT [PK_MaxPayout_CheckData] PRIMARY KEY CLUSTERED 
(
	[matchid] ASC
	,[custid] ASC
	,[eventtypeid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [table_customer]
) ON [table_customer]
GO

ALTER TABLE [dbo].[MaxPayout_CheckData] ADD  CONSTRAINT [DF__MaxPayout_CheckData__ModifiedDate]  DEFAULT (getdate()) FOR [ModifiedDate]
GO

ALTER TABLE [dbo].[MaxPayout_CheckData] ADD  CONSTRAINT [DF__MaxPayout_CheckData__CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE TABLE [dbo].[MaxPayout_CheckData_History](
	[keyID] [int] IDENTITY(1,1) NOT NULL,
	[custid] [int] NOT NULL,
	[matchid] [int] NOT NULL,
	[eventtypeid] [tinyint] NOT NULL,
	[roundVerified] [int] NULL,
	[DiffAmount] [money] NULL,
	[createdDate] DATETIME NULL
 CONSTRAINT [PK_MaxPayout_CheckData_History] PRIMARY KEY CLUSTERED 
(
	[matchid] ASC
	,[custid] ASC
	,[eventtypeid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [table_customer]
) ON [table_customer]
GO

CREATE TABLE [dbo].[MaxPayout_CheckData_Problem](
	[keyID] [int] IDENTITY(1,1) NOT NULL,
	[UserName] [varchar](50) NULL,
	[custid] [int] NULL,
	[matchid] [int] NULL,
	[eventtypeid] [tinyint] NULL,
	[DiffAmount] [money] NULL,
	[LogDate] [datetime] NULL,
	[IsFixed] [bit] NULL,
	[IsNotified] [bit] NULL,
	[Remark] [varchar](100) NULL,
 CONSTRAINT [PK_MaxPayout_CheckData_Problem] PRIMARY KEY NONCLUSTERED 
(
	[keyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [table_customer]
) ON [table_customer]
GO

ALTER TABLE [dbo].[MaxPayout_CheckData_Problem] ADD  CONSTRAINT [DF__MaxPayout__LogDate]  DEFAULT (getdate()) FOR [LogDate]
GO

ALTER TABLE [dbo].[MaxPayout_CheckData_Problem] ADD  CONSTRAINT [DF__MaxPayout__IsFixed]  DEFAULT ((0)) FOR [IsFixed]
GO

ALTER TABLE [dbo].[MaxPayout_CheckData_Problem] ADD  CONSTRAINT [DF__MaxPayout__Remark]  DEFAULT ('') FOR [Remark]
GO
