/*<info serverAlias="DBACC-bodb02,DBAGE-bodb02,DB042-bodb02,DBTP-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBACC-bodb02,DBAGE-bodb02,DB042-bodb02,DBTP-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
*/

USE bodb02
GO

CREATE TYPE [dbo].[TVP_ReplLuckyDrawList] AS TABLE(
	 DrawID				INT				
	,matchid			INT				
	,custid				INT				
	,TypeID				TINYINT			
	,VerificationCode	VARCHAR(50)		
	,DisplayName		VARCHAR(30)		
	,StatusID			TINYINT			
	,Payout				MONEY			
	,Currency			VARCHAR(12)		
	,Remark				NVARCHAR(1000)	
	,LastModifiedUserID	INT				
	,CreatedDate		DATETIME		
	,LastModifiedDate	DATETIME		
	,ExpiredDate		DATE			
	,IsNotify			BIT				
	,NotifiedDate		DATETIME		
	,IsTest				BIT				
	,IsLicensee			BIT				
	,SettledDate		DATE			
	,RepUpdateTime		DATETIME2(7)	
	,IsDeleted			BIT	
	,_FetchedTime		DATETIME2(7)	
)
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplLuckyDrawList] TO [repl_ap] AS [dbo]

