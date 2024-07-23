/*<info serverAlias="DBHIS-bodb_CustHistory" executers="" viewers="" isFunction="0"></info>*/
/*
	 Created by: 20240628@Louisa
	 Task: init structure [Redmine:#204370]
	 DB: DBTP-bodb02
*/

USE bodb_CustHistory
GO

---- DROP TABLE IF EXISTS Dest_ServiceTransform
CREATE TABLE Dest_ServiceTransform
(
	--GroupID			SMALLINT	 NOT NULL
	TableName		VARCHAR(200) NOT NULL
	,Interval		INT			 NOT NULL
	,rID			INT			 NOT NULL
	,BatchSize		INT			 NOT NULL
	,SPSelect		VARCHAR(200) NOT NULL
	,SPInsert		VARCHAR(200) NOT NULL
	,StatusID		TINYINT		 NOT NULL
	,UpdateTime		DATETIME2
)
GO

INSERT INTO  Dest_ServiceTransform 
(	
	TableName, Interval
	, rID, BatchSize
	, SPSelect, SPInsert, StatusID ,UpdateTime, SiteDBGroupID	
)	
VALUES('BetSetting_Member_History', 1000, 0, 1000, 'ServiceTransform_BetSetting_Member_Select', 'ServiceTransform_BetSetting_Member_Insert', 0, SYSDATETIME(), 0 )
	 ,( 'BetSetting_Agent_History' , 1000, 0, 1000, 'ServiceTransform_BetSetting_Agent_Select', 'ServiceTransform_BetSetting_Agent_Insert', 0, SYSDATETIME(), 0 )

GO

INSERT INTO  Dest_ServiceTransform 
(	
	TableName, Interval
	, rID, BatchSize
	, SPSelect, SPInsert, StatusID ,UpdateTime, SiteDBGroupID	
)	
VALUES('BetSetting3rd_Member_History', 1000, 0, 1000, 'ServiceTransform_BetSetting3rd_Member_Select', 'ServiceTransform_BetSetting3rd_Member_Insert', 0, SYSDATETIME(), 0 )
	 ,( 'BetSetting3rd_Agent_History' , 1000, 0, 1000, 'ServiceTransform_BetSetting3rd_Agent_Select', 'ServiceTransform_BetSetting3rd_Agent_Insert', 0, SYSDATETIME(), 0 )

GO