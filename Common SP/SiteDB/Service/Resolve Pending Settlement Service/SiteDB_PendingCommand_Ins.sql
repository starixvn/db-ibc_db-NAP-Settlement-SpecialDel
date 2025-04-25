/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.SiteDB_PendingCommand_Ins
    @matchid		INT  
    ,@sporttype		INT  
	,@Action		VARCHAR(10)		= NULL
    ,@SPName		VARCHAR(100)
	,@Parameter		VARCHAR(MAX) 
    ,@SiteDBGroupID TINYINT
    ,@AdminID		INT				= 0
    ,@IP			NVARCHAR(15)	= ''
    ,@SystemName	VARCHAR(50)		= ''
    ,@StatusID		TINYINT
AS
/*	
	Created: 20250416@Louisa
	Task:Enhance settlement flow when sitedb have down time [Redmine:#217722]
	DB: DBCTG/bodb02
	
	Revisions:
		- 20250416@Louisa: Enhance settlement flow when sitedb have down time [Redmine:#217722]

	Param's Explanation:
		@Parameter = '[{"AdminId":8,"MatchId":12345,"Action":"CAL","SelectedResources":"<Resources><Resource Id=\"00\" Home=\"1\" Away=\"3\" /><Resource Id=\"01\" Home=\"1\" Away=\"2\" /></Resources>","IsReSettledTickets":1,"IP":""}]'
		@Action = CAL
				  REFUND
				  UNDO

*/
BEGIN
 
	INSERT INTO SiteDB_PendingCommand (
		matchid,
		sporttype,
		SPName,
		Parameter, 
		Action,
		IP,
		AdminID,
		SystemName,
		SiteDBGroupID,
		StatusID
	)
	VALUES (
		@matchid,           
		@sporttype, 
		@SPName,
		@Parameter,         
		@Action,            
		@IP,                
		@AdminID,           
		@SystemName,             
		@SiteDBGroupID,     
		@StatusID         
	);

END