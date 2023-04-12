/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_WriteLog_SettlementLogs]
    @ServerName		VARCHAR(100) 
	,@Sporttype		SMALLINT	
	,@MatchID		INT	
	,@ActionID		INT		
	,@LeagueGroupId	INT			= NULL			
	,@ResourceID	VARCHAR(50) = NULL
	,@HomeValue		VARCHAR(50)	= NULL
	,@AwayValue		VARCHAR(50)	= NULL
	,@UserID		INT			= NULL
	,@LogType		TINYINT		= NULL
AS
/*
	Created: 20230410@Louisa
	Task: write log detail to new table [Redmine:#185964]
	DB: DBLOG/bodb_CustomerLog

	Revisions: 
		- 20230410@Louisa: Create SP [Redmine:#185964]


*/

SET NOCOUNT ON;

DECLARE @handle INT
DECLARE @tmpResourceID TABLE (ResourceID VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )

IF @ResourceID IS NOT NULL
BEGIN
	EXEC sp_xml_preparedocument @handle OUTPUT, @ResourceID
	
	INSERT INTO @tmpResourceID (ResourceID , HomeValue, AwayValue)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,Home VARCHAR(50)
															,Away VARCHAR(50)
											) AS tbl
END

INSERT INTO dbo.SettlementLogs
(   
	ServerName	
	,Sporttype	
	,MatchID	
	,ActionID
	,LeagueGroupId
	,ResourceID	
	,HomeValue	
	,AwayValue	
	,UserID	
	,LogType	
) 
VALUES
(   
    @ServerName		
	,@Sporttype		
	,@MatchID		
	,@ActionID		
	,@LeagueGroupId		
	,@ResourceID	
	,@HomeValue		
	,@AwayValue		
	,@UserID	
	,@LogType
)
GO