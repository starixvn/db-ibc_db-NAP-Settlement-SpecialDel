/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementResultHistory_Ins]
	 @MatchId					INT		
	,@Sporttype				    SMALLINT
	,@SessionID				    VARCHAR(50)		= NULL
	,@ResultType				TINYINT
	,@ResourceInfo				VARCHAR(MAX)	= NULL
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]

	Param's Explanation:  
		- @ResultType: 1 - Result Amendment, 2 - Others
		- @WrongResult: '
					[{
						"SeqNo":1,
						"WrongResult": "<root><r Id=\"96801004\" Home=\"20\" Away=\"\" RefBettypeID =\"9680\" G=\"1\" OtherInfo=\"16776\" Action=\"CAL\" LogDate=\"2023-11-24 03:25:22.243\" /></root>",
						"ActualResult": "<root><r Id=\"96801004\" Home=\"20\" Away=\"\" RefBettypeID =\"9680\" G=\"1\" OtherInfo=\"16776\"/></root>",
						"ActionType": 1,
						"ExtraInfo": "<root><r Id=\"96801004\" ReCalc=\"2023-11-24 03:25:22.243\" Calc=\"2023-11-24 03:10:22.243\"/></root>"
					}]
					'	 

*/
BEGIN	
	SET NOCOUNT ON

	INSERT INTO SettlementResultHistory(MatchID,Sporttype,SessionID,SeqNo,ActualResult,WrongResult,ActionType,ResultType,CreatedDate,ModifiedDate,StatusID,ExtraInfo)
	SELECT @MatchId,@Sporttype,@SessionID,rs.SeqNo,rs.ActualResult,rs.WrongResult,rs.ActionType,@ResultType,GETDATE(),GETDATE(),NULL,rs.ExtraInfo
	FROM OPENJSON(@ResourceInfo) WITH   (SeqNo INT 								
										,ActualResult NVARCHAR(MAX)
										,WrongResult NVARCHAR(MAX) 
										,ActionType INT
										,ExtraInfo NVARCHAR(MAX) 
								) AS rs;

END