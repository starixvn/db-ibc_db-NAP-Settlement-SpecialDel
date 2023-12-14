/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementResultHistory_Ins]
	 @MatchId					INT		
	,@Sporttype				    SMALLINT
	,@SessionID				    VARCHAR(50)		= NULL
	,@Action					VARCHAR(20)		= NULL
	,@ActualResult				VARCHAR(MAX)	= NULL
	,@WrongResult				VARCHAR(MAX)	= NULL
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	
	Revisions:
		- 20231214@Aries: Result Amendment [196401]

	Param's Explanation:  
		- @WrongResult: '<root><r Id="96801004" Home="20" Away="" RefBettypeID ="9680" G="1" OtherInfo="16776" Action="CAL" LogDate="2023-11-24 03:25:22.243" /></root>'	 
		- @ActualResult: '<root><r Id="96801004" Home="20" Away="" RefBettypeID ="9680" G="1" OtherInfo="16776"/></root>'
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE		@handle				INT
			   ,@SeqNo				INT = 0
			   ,@ActionType			TINYINT
			   ,@ResultType			TINYINT = 1 -- Result Amendment
			   ,@ExtraInfo			VARCHAR(MAX)
			   ,@Now				DATETIME = GETDATE()

	CREATE TABLE #ActualResult(ResourceID VARCHAR(20), [Action] VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50),G VARCHAR(10),X  VARCHAR(10),Y  VARCHAR(10),TeamIDs  VARCHAR(2000), OtherInfo VARCHAR(2000),LogDate DATETIME,PRIMARY KEY(ResourceID))
	CREATE TABLE #WrongResult(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),G VARCHAR(10),X  VARCHAR(10),Y  VARCHAR(10),TeamIDs  VARCHAR(2000), OtherInfo VARCHAR(2000),PRIMARY KEY(ResourceID))

	EXEC sp_xml_preparedocument @handle OUTPUT, @ActualResult
	INSERT INTO #ActualResult(ResourceID,[Action], HomeValue, AwayValue,G,X,Y,TeamIDs,OtherInfo)
	SELECT Id,[Action], ISNULL(Home,''), ISNULL(Away,''),G,X,Y,TeamIDs,OtherInfo
	FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id			VARCHAR(20)
													 ,[Action]		VARCHAR(50)
													 ,Home			VARCHAR(50)
													 ,Away			VARCHAR(50)
													 ,G				VARCHAR(10)
													 ,X				VARCHAR(10)
													 ,Y				VARCHAR(10)
													 ,TeamIDs		VARCHAR(2000)
													 ,OtherInfo		VARCHAR(2000)													 
												) AS tbl
	EXEC sp_xml_removedocument @handle


	EXEC sp_xml_preparedocument @handle OUTPUT, @WrongResult
	INSERT INTO #WrongResult(ResourceID, HomeValue, AwayValue,G,X,Y,TeamIDs,OtherInfo,LogDate)
	SELECT Id,[Action], ISNULL(Home,''), ISNULL(Away,''),G,X,Y,TeamIDs,OtherInfo,LogDate
	FROM OPENXML(@handle,'Resources/Resource',1) WITH(Id			VARCHAR(20)
													 ,[Action]		VARCHAR(50)
													 ,Home			VARCHAR(50)
													 ,Away			VARCHAR(50)
													 ,G				VARCHAR(10)
													 ,X				VARCHAR(10)
													 ,Y				VARCHAR(10)
													 ,TeamIDs		VARCHAR(2000)
													 ,OtherInfo		VARCHAR(2000)
													 ,LogDate		DATETIME
												) AS tbl
	EXEC sp_xml_removedocument @handle

	IF EXISTS (SELECT 1 FROM #WrongResult WHERE [Action] = 'CAL')
	BEGIN
		SET @SeqNo = @SeqNo + 1
		SET @ActionType = CASE WHEN @Action LIKE 'CAL%'		THEN 1
							   WHEN @Action LIKE 'REFUND%'	THEN 2
							   ELSE NULL
						  END
		
		SET @WrongResult = CAST(((SELECT  w.ResourceID		AS '@Id'
										 ,w.HomeValue		AS '@Home'
										 ,w.AwayValue		AS '@Away'
										 ,w.G				AS '@G'
										 ,w.X				AS '@X'
										 ,w.Y				AS '@Y'
										 ,w.TeamIDs			AS '@TeamIDs'
										 ,w.OtherInfo		AS '@OtherInfo'
								  FROM	#WrongResult AS w
								  WHERE w.[Action] = 'CAL'
								  FOR XML PATH ('root'), TYPE)) AS VARCHAR(MAX))


		SET @ActualResult = CAST(((SELECT a.ResourceID		AS '@Id'
		                                 ,a.HomeValue		AS '@Home'
										 ,a.AwayValue		AS '@Away'
										 ,a.G				AS '@G'
										 ,a.X				AS '@X'
										 ,a.Y				AS '@Y'
										 ,a.TeamIDs			AS '@TeamIDs'
										 ,a.OtherInfo		AS '@OtherInfo'
								  FROM	#ActualResult AS a
								  WHERE a.ResourceID IN (SELECT w.ResourceID FROM #WrongResult AS w WHERE w.[Action] = 'CAL')
								  FOR XML PATH ('root'), TYPE)) AS VARCHAR(MAX))

		SET @ExtraInfo =  CAST(((SELECT a.ResourceID	AS '@Id'
		                               ,a.LogDate		AS '@ReCalc'
									   ,@Now			AS '@Calc'
								  FROM	#WrongResult AS w
								  WHERE w.[Action] = 'CAL'								 
								  FOR XML PATH ('root'), TYPE)) AS VARCHAR(MAX))
		
		INSERT INTO SettlementResultHistory(MatchID,Sporttype,SessionID,SeqNo,ActualResult,WrongResult,ActionType,ResultType,CreatedDate,ModifiedDate,StatusID,ExtraInfo)
		VALUES(@MatchId,@Sporttype,@SessionID,@SeqNo,@ActualResult,@WrongResult,@ActionType,@ResultType,GETDATE(),GETDATE(),0,@ExtraInfo)
	END

	IF EXISTS (SELECT 1 FROM #WrongResult WHERE [Action] = 'REFUND')
	BEGIN
		SET @SeqNo = @SeqNo + 1
		SET @ActionType = CASE WHEN @Action LIKE 'CAL%'		THEN 3
							   ELSE NULL
						  END
		
		SET @WrongResult = CAST(((SELECT  w.ResourceID		AS '@Id'
										 ,w.HomeValue		AS '@Home'
										 ,w.AwayValue		AS '@Away'
										 ,w.G				AS '@G'
										 ,w.X				AS '@X'
										 ,w.Y				AS '@Y'
										 ,w.TeamIDs			AS '@TeamIDs'
										 ,w.OtherInfo		AS '@OtherInfo'
								  FROM	#WrongResult AS w
								  WHERE w.[Action] = 'REFUND'
								  FOR XML PATH ('root'), TYPE)) AS VARCHAR(MAX))


		SET @ActualResult = CAST(((SELECT a.ResourceID		AS '@Id'
		                                 ,a.HomeValue		AS '@Home'
										 ,a.AwayValue		AS '@Away'
										 ,a.G				AS '@G'
										 ,a.X				AS '@X'
										 ,a.Y				AS '@Y'
										 ,a.TeamIDs			AS '@TeamIDs'
										 ,a.OtherInfo		AS '@OtherInfo'
								  FROM	#ActualResult AS a
								  WHERE a.ResourceID IN (SELECT w.ResourceID FROM #WrongResult AS w WHERE w.[Action] = 'REFUND')
								  FOR XML PATH ('root'), TYPE)) AS VARCHAR(MAX))

		SET @ExtraInfo =  CAST(((SELECT a.ResourceID	AS '@Id'
		                               ,a.LogDate		AS '@ReCalc'
									   ,@Now			AS '@Calc'
								  FROM	#WrongResult AS w
								  WHERE w.[Action] = 'REFUND'								 
								  FOR XML PATH ('root'), TYPE)) AS VARCHAR(MAX))
		
		INSERT INTO SettlementResultHistory(MatchID,Sporttype,SessionID,SeqNo,ActualResult,WrongResult,ActionType,ResultType,CreatedDate,ModifiedDate,StatusID,ExtraInfo)
		VALUES(@MatchId,@Sporttype,@SessionID,@SeqNo,@ActualResult,@WrongResult,@ActionType,@ResultType,GETDATE(),GETDATE(),0,@ExtraInfo)

	END


	

	

END