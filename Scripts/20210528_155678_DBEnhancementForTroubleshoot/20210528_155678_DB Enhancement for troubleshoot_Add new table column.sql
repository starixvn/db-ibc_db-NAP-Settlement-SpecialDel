/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210528@July
	Task: TVS - DB Enhancement for troubleshoot & Enhance SP for Lock Process - [Redmine: #155678]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

CREATE TABLE TVS_UserActionLog
(
	ID UNIQUEIDENTIFIER,
	SPName VARCHAR(500),
	SqlCommand NVARCHAR(MAX),
	UserID INT,
	Matchid INT,
	CreatedDate DATETIME,
	SubmittedDate DATETIME
)
CREATE NONCLUSTERED INDEX IDX_TVS_UserActionLog_Matchid ON TVS_UserActionLog (Matchid)
CREATE NONCLUSTERED INDEX IDX_TVS_UserActionLog_CreatedDate ON TVS_UserActionLog (CreatedDate)


ALTER TABLE TempVariableNumber
ADD SPName VARCHAR(500);

