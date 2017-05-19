ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_4]
  @MatchID							INT
 ,@SelectedSet						VARCHAR(50)	= NULL
 ,@SetResult						VARCHAR(50)	= NULL 
 ,@SelectedSettleFinishedGame		VARCHAR(50)	= NULL
 ,@IsSettleDeterminedTicketTennis	BIT			= 0
 ,@TotalGameMatch					INT	= 0 OUTPUT
 ,@TotalGameHomeMatch				INT = 0 OUTPUT
 ,@TotalGameAwayMatch				INT = 0 OUTPUT
 ,@TotalGameHomeSet1				INT	= 0 OUTPUT
 ,@TotalGameHomeSet2				INT = 0 OUTPUT
 ,@TotalGameHomeSet3				INT = 0 OUTPUT
 ,@TotalGameHomeSet4				INT = 0 OUTPUT
 ,@TotalGameHomeSet5				INT = 0 OUTPUT
 ,@TotalGameAwaySet1				INT = 0 OUTPUT
 ,@TotalGameAwaySet2				INT = 0 OUTPUT
 ,@TotalGameAwaySet3				INT = 0 OUTPUT
 ,@TotalGameAwaySet4				INT = 0 OUTPUT
 ,@TotalGameAwaySet5				INT = 0 OUTPUT 
 ,@SetxGameyHomeWON					VARCHAR(MAX) = ''  OUTPUT
 ,@SetxGameyAwayWON					VARCHAR(MAX) = ''  OUTPUT
 ,@SetxGameyDRAW					VARCHAR(MAX) = ''  OUTPUT
 ,@SetxGameyFinishedGame			VARCHAR(MAX) = ''  OUTPUT	
 ,@SetxGameyREFUND					VARCHAR(MAX) = ''  OUTPUT	
 ,@SelectedSetCAL					VARCHAR(50)  = ''  OUTPUT
 ,@SelectedSetREFUND				VARCHAR(50)  = ''  OUTPUT 		

AS
/*
	Created by: Jamie
	Date: 20141027
	Task: Settlement for Tennis ( including Sporting Solution) 
	DB: DBTXN/bodb02

	Revisions:

	Param's Explanation: 

*/
BEGIN
	SET NOCOUNT ON 
	SELECT   @TotalGameMatch		 = 0 
			,@TotalGameHomeMatch	 = 0 
			,@TotalGameAwayMatch	 = 0 
			,@TotalGameHomeSet1		 = 0 
			,@TotalGameHomeSet2		 = 0 
			,@TotalGameHomeSet3		 = 0 
			,@TotalGameHomeSet4		 = 0 
			,@TotalGameHomeSet5		 = 0 
			,@TotalGameAwaySet1		 = 0 
			,@TotalGameAwaySet2		 = 0 
			,@TotalGameAwaySet3		 = 0 
			,@TotalGameAwaySet4		 = 0 
			,@TotalGameAwaySet5		 = 0  
			,@SetxGameyHomeWON		 = ''  
			,@SetxGameyAwayWON		 = ''  
			,@SetxGameyDRAW			 = ''  
			,@SetxGameyFinishedGame	 = ''  	
			,@SetxGameyREFUND		 = ''  	
			,@SelectedSetCAL		 = ''  
			,@SelectedSetREFUND		 = '' 

	DECLARE	@tmpSelectedSet	TABLE(
		 ID			TINYINT IDENTITY(1,1)
		,SetIndex	TINYINT
	)
	INSERT INTO @tmpSelectedSet(SetIndex)
	SELECT	Val FROM dbo.StrSplit(@SelectedSet, ',') WHERE ISNULL(@SelectedSet,'') <> ''

	DECLARE	@tmpEachSet TABLE (
	 	 ID			TINYINT IDENTITY(1,1)
		,SetScore	NVARCHAR(10)
		,HomeValue	INT
		,AwayValue	INT
	)

	INSERT INTO @tmpEachSet(SetScore,HomeValue,AwayValue) 
	SELECT val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@SetResult, ',') WHERE ISNULL(@SetResult,'') <>''


	DECLARE	@tmpResultDetail TABLE(
		 ResourceID			VARCHAR(20)
		,HomeValue			VARCHAR(20)
		,AwayValue			VARCHAR(20)
		,SettlementStatusID	TINYINT 
	)

	INSERT INTO @tmpResultDetail(
		 ResourceID
		,HomeValue
		,AwayValue
		,SettlementStatusID
	)
	SELECT	 ResourceID
			,HomeValue
			,AwayValue
			,SettlementStatusID
	FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
	WHERE	MatchID = @MatchID
			AND SettlementStatusID > 0 
			AND ResultStatusID = 5 -- Score from Settlement Site 



	SELECT	 @TotalGameHomeMatch	= ISNULL(SUM(CASE WHEN ResourceID LIKE '0[1-5]' THEN HomeValue ELSE 0 END),0)
			,@TotalGameAwayMatch	= ISNULL(SUM(CASE WHEN ResourceID LIKE '0[1-5]' THEN AwayValue ELSE 0 END),0)
			,@TotalGameHomeSet1		= ISNULL(SUM(CASE WHEN ResourceID ='01' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet2		= ISNULL(SUM(CASE WHEN ResourceID ='02' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet3		= ISNULL(SUM(CASE WHEN ResourceID ='03' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet4		= ISNULL(SUM(CASE WHEN ResourceID ='04' THEN HomeValue ELSE 0 END),0)
			,@TotalGameHomeSet5		= ISNULL(SUM(CASE WHEN ResourceID ='05' THEN HomeValue ELSE 0 END),0)
			,@TotalGameAwaySet1		= ISNULL(SUM(CASE WHEN ResourceID ='01' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet2		= ISNULL(SUM(CASE WHEN ResourceID ='02' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet3		= ISNULL(SUM(CASE WHEN ResourceID ='03' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet4		= ISNULL(SUM(CASE WHEN ResourceID ='04' THEN AwayValue ELSE 0 END),0)
			,@TotalGameAwaySet5		= ISNULL(SUM(CASE WHEN ResourceID ='05' THEN AwayValue ELSE 0 END),0)
	FROM	@tmpResultDetail
	WHERE	ResourceID LIKE '0[1-5]' 
			AND SettlementStatusID = 4 

	SELECT   @SetxGameyHomeWON		= @SetxGameyHomeWON + CASE WHEN CAST((CASE WHEN HomeValue='A' THEN '65' ELSE HomeValue END) AS INT) - CAST((CASE WHEN AwayValue ='A' THEN '65' ELSE AwayValue END) AS INT) > 0 
																		AND SettlementStatusID = 4 THEN ResourceID +',' ELSE '' END
			,@SetxGameyAwayWON		= @SetxGameyAwayWON + CASE WHEN CAST((CASE WHEN HomeValue='A' THEN '65' ELSE HomeValue END) AS INT) - CAST((CASE WHEN AwayValue ='A' THEN '65' ELSE AwayValue END) AS INT) < 0 
																		AND SettlementStatusID = 4 THEN ResourceID +',' ELSE '' END
			,@SetxGameyDRAW			= @SetxGameyDRAW + CASE WHEN CAST((CASE WHEN HomeValue='A' THEN '65' ELSE HomeValue END) AS INT) - CAST((CASE WHEN AwayValue ='A' THEN '65' ELSE AwayValue END) AS INT) = 0 
																		AND SettlementStatusID = 4 THEN ResourceID +',' ELSE '' END
			,@SetxGameyREFUND		= @SetxGameyREFUND + CASE WHEN SettlementStatusID = 1 THEN ResourceID +',' ELSE '' END 
			,@SetxGameyFinishedGame	= @SetxGameyFinishedGame + CASE WHEN SettlementStatusID = 4 THEN ResourceID +',' ELSE '' END 
	FROM	@tmpResultDetail 
	WHERE	SettlementStatusID > 0 
			AND ResourceID LIKE '0[1-5][0-9][0-9]'

	IF @IsSettleDeterminedTicketTennis = 1 
	BEGIN
		SELECT	 @TotalGameHomeMatch	= ISNULL(SUM(HomeValue),0)
				,@TotalGameAwayMatch	= ISNULL(SUM(AwayValue),0)
		FROM	@tmpEachSet
	END

	SELECT	@TotalGameMatch = @TotalGameHomeMatch + @TotalGameAwayMatch

	---- Get Set/Match
	SELECT	 @SelectedSetCAL	= @SelectedSetCAL + CASE WHEN SettlementStatusID = 4 THEN CASE WHEN ResourceID='00' THEN '6,' ELSE RIGHT(ResourceID,1) +',' END
													 ELSE '' END		
			,@SelectedSetREFUND = @SelectedSetREFUND + CASE WHEN SettlementStatusID = 1 THEN CASE WHEN ResourceID='00' THEN '6,' ELSE RIGHT(ResourceID,1) +',' END
													 ELSE '' END											
	FROM	@tmpResultDetail
	WHERE	ResourceID LIKE '0[0-5]' 

END