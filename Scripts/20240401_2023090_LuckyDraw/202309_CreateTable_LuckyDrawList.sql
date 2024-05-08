/*<info serverAlias="DBCTG-bodb02,DBACC-bodb02,DBAGE-bodb02,DBBOF-bodb02,DBTP-bodb02" executers="" isFunction="0"></info>*/

/*	
	Created: 20240327@Louisa
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize)
    [Redmine:#202309,#200194]		
*/

USE bodb02
GO

--DROP TABLE IF EXISTS LuckyDrawList

CREATE TABLE dbo.LuckyDrawList
(
	 DrawID				INT	IDENTITY(1,1)	NOT NULL
	,matchid			INT				NOT NULL
	,custid				INT				NOT NULL
	,TypeID				TINYINT			NOT NULL
	,VerificationCode	VARCHAR(50)		NOT NULL
	,DisplayName		VARCHAR(30)		NOT NULL
	,StatusID			TINYINT			NOT NULL
	,Payout				MONEY			NULL
	,Currency			VARCHAR(12)		NOT NULL
	,Remark				NVARCHAR(1000)	NULL
	,LastModifiedUserID	INT				NULL
	,CreatedDate		DATETIME		NOT NULL
	,LastModifiedDate	DATETIME		NULL
	,ExpiredDate		DATE			NULL
	,IsNotify			BIT				NOT NULL
	,NotifiedDate		DATETIME		NULL
	,IsTest				BIT				NULL
	,IsLicensee			BIT				NULL
	,SettledDate		DATE			NULL
	,PoolPrize			MONEY			NULL
	,finalhomescore		INT				NULL
	,finalawayscore		INT				NULL
	,RepUpdateTime		DATETIME2(7)	NOT NULL ---use for InHouse Replication
	,IsDeleted			BIT				NOT NULL
)
GO
--------------------------------------------------------------------------------------------------
ALTER TABLE dbo.LuckyDrawList ADD CONSTRAINT PK_LuckyDrawList PRIMARY KEY CLUSTERED ( DrawID ASC )
GO
--------------------------------------------------------------------------------------------------
CREATE UNIQUE NONCLUSTERED INDEX IDX_LuckyDrawList_TypeID_VerificationCode ON dbo.LuckyDrawList(TypeID,VerificationCode)
GO
--------------------------------------------------------------------------------------------------
ALTER TABLE dbo.LuckyDrawList ADD CONSTRAINT DF_LuckyDrawList_IsNotify DEFAULT(0) FOR IsNotify
GO
--------------------------------------------------------------------------------------------------
ALTER TABLE dbo.LuckyDrawList ADD CONSTRAINT DF_LuckyDrawList_RepUpdateTime DEFAULT(SYSDATETIME()) FOR RepUpdateTime
GO
--------------------------------------------------------------------------------------------------
ALTER TABLE dbo.LuckyDrawList ADD CONSTRAINT DF_LuckyDrawList_IsDeleted DEFAULT(0) FOR IsDeleted
GO