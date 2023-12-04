/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[dbo.NAP_SettlementResultHistory_Ins]
	 @MatchId					INT		
	,@Sporttype				    SMALLINT
	,@SessionID				    VARCHAR(50)		= NULL
	,@Action					VARCHAR(20)		= NULL
	,@ActualResult				VARCHAR(MAX)	= NULL
	,@WrongResult				VARCHAR(MAX)	= NULL
	,@ResultType				TINYINT			= NULL
	,@ExtraInfo					VARCHAR(MAX)	= NULL
AS
/*	
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON

	INSERT INTO SettlementResultHistory(MatchID,Sporttype,SessionID,[Action],ActualResult,WrongResult,ResultType,CreatedDate,ModifiedDate,StatusID,ExtraInfo)
	VALUES(@MatchId,@Sporttype,@SessionID,@Action,@ActualResult,@WrongResult,@ResultType,GETDATE(),GETDATE(),0,@ExtraInfo)

END