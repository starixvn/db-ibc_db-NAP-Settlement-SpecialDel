/*<info serverAlias="DBACC-bodb_CustHistory,DBTP-bodb_CustHistory"></info>*/
/*
	 Created by: 20240628@Louisa
	 Task: init structure [Redmine:#204370]
	 DB: DBACC-bodb02,DBTP-bodb02
*/

USE bodb_CustHistory
GO

---- DROP TABLE IF EXISTS Dest_ServiceTransform
CREATE TABLE Dest_ServiceTransform
(
	GroupID			SMALLINT	 NOT NULL
	,TableName		VARCHAR(200) NOT NULL
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
	GroupID, TableName, Interval
	, rID, BatchSize
	, SPSelect, SPInsert, StatusID ,UpdateTime	
)	
VALUES(1, 'BetSetting_Member_History', 1000, 0, 1000, 'ServiceTransform_BetSetting_Member_Select', 'ServiceTransform_BetSetting_Member_Ins', 0, SYSDATETIME() )
	 ,(1, 'BetSetting_Agent_History' , 1000, 0, 1000, 'ServiceTransform_BetSetting_Agent_Select', 'ServiceTransform_BetSetting_Agent_Ins', 0, SYSDATETIME() )

GO