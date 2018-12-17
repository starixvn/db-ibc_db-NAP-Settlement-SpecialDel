/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Result_Update]
  @Command						VARCHAR(100) 
 ,@MatchID						INT
 ,@HomeValue					VARCHAR(20)	= NULL		
 ,@AwayValue					VARCHAR(20)	= NULL 
 ,@SetResult					VARCHAR(50)	= NULL 
 ,@GameResult1					VARCHAR(MAX)= NULL
 ,@GameResult2					VARCHAR(MAX)= NULL
 ,@GameResult3					VARCHAR(MAX)= NULL
 ,@GameResult4					VARCHAR(MAX)= NULL
 ,@GameResult5					VARCHAR(MAX)= NULL
 ,@SelectedSet					VARCHAR(50)	= NULL 
 ,@SelectedSet1Game				VARCHAR(MAX)= NULL 
 ,@SelectedSet2Game				VARCHAR(MAX)= NULL 
 ,@SelectedSet3Game				VARCHAR(MAX)= NULL 
 ,@SelectedSet4Game				VARCHAR(MAX)= NULL 
 ,@SelectedSet5Game				VARCHAR(MAX)= NULL 
 ,@SelectedSettleFinishedGame	VARCHAR(50)	= NULL 
 ,@MaxGameSet1					INT			= NULL
 ,@MaxGameSet2					INT			= NULL
 ,@MaxGameSet3					INT			= NULL
 ,@MaxGameSet4					INT			= NULL
 ,@MaxGameSet5					INT			= NULL 
 ,@action						VARCHAR(10)	= 'CAL'
 ,@creator						INT			= 0 
AS 
/*
	Created by: Jamie
	Date: 20141010
	Task: Update the result of Tennis 
	DB: DBPRO/bodb02 

	Revision
		- 20180801@Vicky: get code from PROD [Redmine #95874]

	Param's Explanation: 
		+ @HomeValue & @AwayValue : Match Result - ResourceID ='00'
		+ @betstatus: Set score '6-1,6-4,4-6,0-0,0-0'
		+ @SetResult: Set score '6-1,6-4'
		+ @GameResult1: The score of Games in set 1 : '40-A,30-40,15-30,N-N' 
			N-N: Operator clear the score to Blank 
		+ @SelectedSet: The list of set(s) choosen 
		+ @SelectedSet1Game: The list of game(s) have score(s) or the score(s) changed to Blank 



*/
BEGIN
	SET NOCOUNT ON 

	DECLARE	@tmpSelectedSet	TABLE(
		 ID			TINYINT IDENTITY(1,1)
		,SetIndex	TINYINT
	)
	INSERT INTO @tmpSelectedSet(SetIndex)
	SELECT	Val FROM dbo.StrSplit(@SelectedSet, ',')

	DECLARE	@tmpSelectedSettleFinishedGame TABLE(
		 ID			TINYINT IDENTITY(1,1)
		,SetIndex	TINYINT	
	)

	DECLARE	 @seti	INT
			--,@setn	INT
			,@gamei	INT
			,@gamen	INT

	SELECT	 @GameResult1 = UPPER(ISNULL(@GameResult1,''))		-- a -->A or n --> N
			,@GameResult2 = UPPER(ISNULL(@GameResult2,''))
			,@GameResult3 = UPPER(ISNULL(@GameResult3,''))
			,@GameResult4 = UPPER(ISNULL(@GameResult4,''))
			,@GameResult5 = UPPER(ISNULL(@GameResult5,''))
			,@SetResult   = ISNULL(@SetResult,'') 
			,@SelectedSet1Game = ISNULL(@SelectedSet1Game,'')
			,@SelectedSet2Game = ISNULL(@SelectedSet2Game,'')
			,@SelectedSet3Game = ISNULL(@SelectedSet3Game,'')
			,@SelectedSet4Game = ISNULL(@SelectedSet4Game,'')
			,@SelectedSet5Game = ISNULL(@SelectedSet5Game,'')
			,@SelectedSettleFinishedGame = ISNULL(@SelectedSettleFinishedGame,'') 
			


	DECLARE	@tmpEachSet TABLE (
	 		ID			TINYINT IDENTITY(1,1)
		,SetScore	NVARCHAR(10)
		,HomeValue	INT
		,AwayValue	INT
	)

	DECLARE @tmpSelectedGame TABLE(
			ID			INT IDENTITY(1,1)
		,SetIndex	TINYINT
		,GameIndex	INT
	)

	DECLARE @tmpEachGamePerSet TABLE(
			ID			INT IDENTITY(1,1) 
		,SetIndex	TINYINT
		,GameScore	VARCHAR(20) 
		,HomeValue	VARCHAR(20)
		,AwayValue	VARCHAR(20)
	)

	DECLARE	@tmpResultDetail TABLE(
			MatchID			INT
		,ResourceID			VARCHAR(20)
		,HomeValue			VARCHAR(20) NULL
		,AwayValue			VARCHAR(20) NULL 
		,SettlementStatusID	TINYINT
	)
	/* START - @Command = 'NAP_Admin_Settlement_1-CAL' */
	IF @Command = 'NAP_Admin_Settlement_1-CAL'
	BEGIN

		INSERT INTO @tmpEachSet(SetScore,HomeValue,AwayValue) 
		SELECT val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@SetResult, ',') WHERE @SetResult <> ''

		INSERT INTO @tmpSelectedGame(SetIndex, GameIndex)
				  SELECT	1, Val FROM dbo.StrSplit(@SelectedSet1Game, ',') WHERE @SelectedSet1Game <> ''
		UNION ALL SELECT	2, Val FROM dbo.StrSplit(@SelectedSet2Game, ',') WHERE @SelectedSet2Game <> ''
		UNION ALL SELECT	3, Val FROM dbo.StrSplit(@SelectedSet3Game, ',') WHERE @SelectedSet3Game <> ''
		UNION ALL SELECT	4, Val FROM dbo.StrSplit(@SelectedSet4Game, ',') WHERE @SelectedSet4Game <> ''
		UNION ALL SELECT	5, Val FROM dbo.StrSplit(@SelectedSet5Game, ',') WHERE @SelectedSet5Game <> ''

		INSERT INTO @tmpEachGamePerSet (SetIndex, GameScore,HomeValue,AwayValue)
				   SELECT 1, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult1, ',') WHERE @GameResult1 <> ''
		UNION ALL  SELECT 2, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult2, ',') WHERE @GameResult2 <> ''
		UNION ALL  SELECT 3, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult3, ',') WHERE @GameResult3 <> ''
		UNION ALL  SELECT 4, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult4, ',') WHERE @GameResult4 <> ''
		UNION ALL  SELECT 5, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult5, ',') WHERE @GameResult5 <> ''
	
		/*START:Auto Refund Game not selected */
		SELECT	 @MaxGameSet1 = CASE WHEN SetIndex = 1 AND @MaxGameSet1 < GameIndex THEN GameIndex ELSE @MaxGameSet1 END
				,@MaxGameSet2 = CASE WHEN SetIndex = 2 AND @MaxGameSet2 < GameIndex THEN GameIndex ELSE @MaxGameSet2 END
				,@MaxGameSet3 = CASE WHEN SetIndex = 3 AND @MaxGameSet3 < GameIndex THEN GameIndex ELSE @MaxGameSet3 END
				,@MaxGameSet4 = CASE WHEN SetIndex = 4 AND @MaxGameSet4 < GameIndex THEN GameIndex ELSE @MaxGameSet4 END
				,@MaxGameSet5 = CASE WHEN SetIndex = 5 AND @MaxGameSet5 < GameIndex THEN GameIndex ELSE @MaxGameSet5 END
		FROM	@tmpSelectedGame

		SELECT	 @seti = 0

		DECLARE SelectedSet_Cursor CURSOR
		FOR
		SELECT	SetIndex
		FROM	@tmpSelectedSet
		WHERE	SetIndex < 6 
		OPEN	SelectedSet_Cursor
		FETCH NEXT FROM SelectedSet_Cursor INTO @seti
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			SELECT	@gamei = 1
			SELECT	@gamen = CASE @seti WHEN 1 THEN @MaxGameSet1
										WHEN 2 THEN @MaxGameSet2
										WHEN 3 THEN @MaxGameSet3
										WHEN 4 THEN @MaxGameSet4
										WHEN 5 THEN @MaxGameSet5 
										ELSE 0 END 
			WHILE(@gamei < @gamen + 1)
			BEGIN
				IF NOT EXISTS(SELECT TOP 1 1 FROM @tmpSelectedGame WHERE SetIndex = @seti AND GameIndex = @gamei)
				BEGIN
					INSERT INTO @tmpResultDetail(MatchID,ResourceID,HomeValue,AwayValue,SettlementStatusID)
					SELECT	@MatchID
							,'0'+ CAST(@seti AS VARCHAR(10)) + RIGHT(('0'+ CAST(@gamei AS VARCHAR(10))),2)  -- 0[1-5][01-99]
							,NULL
							,NULL,
							1
				END
				SET @gamei = @gamei + 1 
			END
			FETCH NEXT FROM SelectedSet_Cursor INTO @seti 
		END 
		CLOSE SelectedSet_Cursor
		DEALLOCATE SelectedSet_Cursor

		/*END:Auto Refund Game not selected */
		-- CAL PAGE 
		INSERT INTO @tmpResultDetail(
			 MatchID
			,ResourceID
			,HomeValue
			,AwayValue
			,SettlementStatusID
		)
		SELECT	 @MatchID
				,'0'+ CAST(s.SetIndex AS VARCHAR(10))	--0[1-5]:
				,e.HomeValue
				,e.AwayValue
				,4
		FROM	@tmpEachSet e
				INNER JOIN @tmpSelectedSet s ON e.ID = s.ID
	
		-- Game Result 
		IF ISNULL(@SelectedSet1Game,'') <>'' OR ISNULL(@SelectedSet2Game,'') <>'' OR ISNULL(@SelectedSet3Game,'') <> ''
				OR ISNULL(@SelectedSet4Game,'') <>'' OR ISNULL(@SelectedSet5Game,'') <> ''  
			INSERT INTO @tmpResultDetail(
				 MatchID
				,ResourceID
				,HomeValue
				,AwayValue
				,SettlementStatusID
			)
			SELECT	@MatchID 
					,'0' + CAST(g.SetIndex AS VARCHAR(10)) + RIGHT(('0'+ CAST(g.GameIndex AS VARCHAR(10))),2)  -- 0[1-5][01-99]
					,e.HomeValue
					,e.AwayValue
					,4
			FROM	@tmpEachGamePerSet e 
					INNER JOIN @tmpSelectedGame g ON e.ID = g.ID

		-- Match Result
		IF	@SelectedSet LIKE '%6%'
		BEGIN
			INSERT INTO @tmpResultDetail(
				 MatchID
				,ResourceID
				,HomeValue
				,AwayValue
				,SettlementStatusID
			)
			SELECT	@MatchID
					,'00'
					,@HomeValue
					,@AwayValue
					,4
		END

		UPDATE	@tmpResultDetail 
		SET		HomeValue	= NULL
				,AwayValue	= NULL
				,SettlementStatusID = 1		--Refund 
		WHERE	HomeValue ='N'

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = SOURCE.MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue
					,TARGET.ResultStatusID		= 5								-- Settlement Site 
					,TARGET.SettlementStatusID	= SOURCE.SettlementStatusID		-- Completed|Refund
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 SOURCE.MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue
					,5
					,SOURCE.SettlementStatusID 
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);
	END 
	/* END - @Command = 'NAP_Admin_Settlement_1-CAL' */

	/* START - @Command = 'NAP_Admin_Settlement_1-UNDO' */
	IF @Command = 'NAP_Admin_Settlement_1-UNDO'
	BEGIN
		DELETE FROM ResultDetail WITH (ROWLOCK)
		WHERE	MatchID = @MatchID
				AND 1 = CASE WHEN @SelectedSet LIKE '%1%' AND ResourceID LIKE '01%' THEN 1 
							 WHEN @SelectedSet LIKE '%2%' AND ResourceID LIKE '02%' THEN 1
							 WHEN @SelectedSet LIKE '%3%' AND ResourceID LIKE '03%' THEN 1
							 WHEN @SelectedSet LIKE '%4%' AND ResourceID LIKE '04%' THEN 1
							 WHEN @SelectedSet LIKE '%5%' AND ResourceID LIKE '05%' THEN 1 
							 WHEN @SelectedSet LIKE '%6%' AND ResourceID ='00' THEN 1 
							 ELSE 0 END 
	END
	/* END - @Command = 'NAP_Admin_Settlement_1-UNDO' */

	/* START - @Command = 'NAP_Admin_Settlement_Refund_All' */
	IF @Command ='NAP_Admin_Settlement_Refund_All'
	BEGIN
		INSERT INTO @tmpSelectedSettleFinishedGame(SetIndex)
		SELECT	Val FROM dbo.StrSplit(@SelectedSettleFinishedGame, ',') WHERE @SelectedSettleFinishedGame <>'' 

		--INSERT INTO @tmpEachSet(SetScore,HomeValue,AwayValue) 
		--SELECT val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@SetResult, ',')

		INSERT INTO @tmpSelectedGame(SetIndex, GameIndex)
				  SELECT	1, Val FROM dbo.StrSplit(@SelectedSet1Game, ',') WHERE @SelectedSet1Game <> ''
		UNION ALL SELECT	2, Val FROM dbo.StrSplit(@SelectedSet2Game, ',') WHERE @SelectedSet2Game <> ''
		UNION ALL SELECT	3, Val FROM dbo.StrSplit(@SelectedSet3Game, ',') WHERE @SelectedSet3Game <> '' 
		UNION ALL SELECT	4, Val FROM dbo.StrSplit(@SelectedSet4Game, ',') WHERE @SelectedSet4Game <> ''
		UNION ALL SELECT	5, Val FROM dbo.StrSplit(@SelectedSet5Game, ',') WHERE @SelectedSet5Game <> ''

		INSERT INTO @tmpEachGamePerSet (SetIndex, GameScore,HomeValue,AwayValue)
				   SELECT 1, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult1, ',') WHERE @GameResult1 <>''
		UNION ALL  SELECT 2, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult2, ',') WHERE @GameResult2 <>''
		UNION ALL  SELECT 3, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult3, ',') WHERE @GameResult3 <>''
		UNION ALL  SELECT 4, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult4, ',') WHERE @GameResult4 <>''
		UNION ALL  SELECT 5, Val, LEFT(Val,CHARINDEX('-',Val)-1), RIGHT(Val,LEN(Val) - CHARINDEX('-',Val)) FROM dbo.StrSplit(@GameResult5, ',') WHERE @GameResult5 <>''
	
		/*START:Auto Refund Game not selected */
		SELECT	 @MaxGameSet1 = CASE WHEN SetIndex = 1 AND @MaxGameSet1 < GameIndex THEN GameIndex ELSE @MaxGameSet1 END
				,@MaxGameSet2 = CASE WHEN SetIndex = 2 AND @MaxGameSet2 < GameIndex THEN GameIndex ELSE @MaxGameSet2 END
				,@MaxGameSet3 = CASE WHEN SetIndex = 3 AND @MaxGameSet3 < GameIndex THEN GameIndex ELSE @MaxGameSet3 END
				,@MaxGameSet4 = CASE WHEN SetIndex = 4 AND @MaxGameSet4 < GameIndex THEN GameIndex ELSE @MaxGameSet4 END
				,@MaxGameSet5 = CASE WHEN SetIndex = 5 AND @MaxGameSet5 < GameIndex THEN GameIndex ELSE @MaxGameSet5 END
		FROM	@tmpSelectedGame

		SELECT	 @seti = 0

		DECLARE SelectedSet_Cursor CURSOR
		FOR
		SELECT	SetIndex
		FROM	@tmpSelectedSet
		WHERE	SetIndex < 6 
		OPEN	SelectedSet_Cursor
		FETCH NEXT FROM SelectedSet_Cursor INTO @seti
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			SELECT	@gamei = 1
			SELECT	@gamen = CASE @seti WHEN 1 THEN @MaxGameSet1
										WHEN 2 THEN @MaxGameSet2
										WHEN 3 THEN @MaxGameSet3
										WHEN 4 THEN @MaxGameSet4
										WHEN 5 THEN @MaxGameSet5 
										ELSE 0 END 
			WHILE(@gamei < @gamen + 1)
			BEGIN
				IF NOT EXISTS(SELECT TOP 1 1 FROM @tmpSelectedGame WHERE SetIndex = @seti AND GameIndex = @gamei)
				BEGIN
					INSERT INTO @tmpResultDetail(MatchID,ResourceID,HomeValue,AwayValue,SettlementStatusID)
					SELECT	@MatchID
							,'0'+ CAST(@seti AS VARCHAR(10)) + RIGHT(('0'+ CAST(@gamei AS VARCHAR(10))),2)  -- 0[1-5][01-99]
							,NULL
							,NULL,
							1
				END
				SET @gamei = @gamei + 1 
			END
			FETCH NEXT FROM SelectedSet_Cursor INTO @seti 
		END 
		CLOSE SelectedSet_Cursor
		DEALLOCATE SelectedSet_Cursor

		/*END:Auto Refund Game not selected */
		-- Set Result Refund  
		--INSERT INTO @tmpResultDetail(
		--	 MatchID
		--	,ResourceID
		--	,HomeValue
		--	,AwayValue
		--	,SettlementStatusID
		--)
		--SELECT	 @MatchID
		--		,'0'+ CAST(s.SetIndex AS VARCHAR(10))	--0[1-5]:
		--		,e.HomeValue
		--		,e.AwayValue
		--		,1			--Refund 
		--FROM	@tmpEachSet e
		--		INNER JOIN @tmpSelectedSet s ON e.ID = s.ID

		-- Set Result Refund  
		INSERT INTO @tmpResultDetail(
			 MatchID
			,ResourceID
			,HomeValue
			,AwayValue
			,SettlementStatusID
		)
		SELECT	 @MatchID
				,'0'+ CAST(s.SetIndex AS VARCHAR(10))	--0[1-5]:
				,NULL
				,NULL
				,1			--Refund 
		FROM	@tmpSelectedSet s
		WHERE	SetIndex BETWEEN 1 AND 5 

		UPDATE	t
		SET		HomeValue	= r.HomeValue
				,AwayValue	= r.AwayValue
		FROM	@tmpResultDetail t 
				INNER JOIN ResultDetail r WITH (NOLOCK) ON t.ResourceID = r.ResourceID 
		WHERE	r.MatcHID = @MatchID
				AND r.ResourceID LIKE '0[1-5]'
				AND t.SettlementStatusID = 1 
		
		-- Game Result 
		IF ISNULL(@SelectedSet1Game,'') <>'' OR ISNULL(@SelectedSet2Game,'') <>'' OR ISNULL(@SelectedSet3Game,'') <> ''
				OR ISNULL(@SelectedSet4Game,'') <>'' OR ISNULL(@SelectedSet5Game,'') <> '' 
			INSERT INTO @tmpResultDetail(
				 MatchID
				,ResourceID
				,HomeValue
				,AwayValue
				,SettlementStatusID
			)
			SELECT	@MatchID 
					,'0' + CAST(g.SetIndex AS VARCHAR(10)) + RIGHT(('0'+ CAST(g.GameIndex AS VARCHAR(10))),2)  -- 0[1-5][01-99]
					,e.HomeValue
					,e.AwayValue
					,CASE WHEN f.SetIndex IS NOT NULL AND e.HomeValue <>'N' THEN 4
						  ELSE 1 END 
			FROM	@tmpEachGamePerSet e 
					INNER JOIN @tmpSelectedGame g ON e.ID = g.ID
					LEFT JOIN @tmpSelectedSettleFinishedGame f ON g.SetIndex = f.SetIndex

		-- Match Result
		IF	@SelectedSet LIKE '%6%'
		BEGIN
			INSERT INTO @tmpResultDetail(
				 MatchID
				,ResourceID
				,HomeValue
				,AwayValue
				,SettlementStatusID
			)
			SELECT	@MatchID
					,'00'
					,0
					,0
					,1			--Refund 
		END

		UPDATE	@tmpResultDetail 
		SET		HomeValue	= NULL
				,AwayValue	= NULL
				,SettlementStatusID = 1		--Refund 
		WHERE	HomeValue ='N'

		MERGE	ResultDetail AS TARGET
		USING	@tmpResultDetail AS SOURCE ON (TARGET.MatchID = SOURCE.MatchID AND TARGET.ResourceID = SOURCE.ResourceID)
		WHEN	MATCHED THEN				 
				UPDATE SET
					TARGET.HomeValue			= SOURCE.HomeValue
					,TARGET.AwayValue			= SOURCE.AwayValue
					,TARGET.ResultStatusID		= 5								-- Settlement Site 
					,TARGET.SettlementStatusID	= SOURCE.SettlementStatusID		-- Completed|Refund
					,TARGET.LastModifyBy		= @Creator 
					,TARGET.LastModifyDate		= GETDATE() 
		WHEN	NOT MATCHED BY TARGET THEN 
				INSERT(
					 MatchID
					,ResourceID
					,HomeValue
					,AwayValue
					,ResultStatusID
					,SettlementStatusID
					,CreateBy
					,CreateDate
					,LastModifyBy
					,LastModifyDate
				)
				VALUES(
					 SOURCE.MatchID
					,SOURCE.ResourceID
					,SOURCE.HomeValue
					,SOURCE.AwayValue
					,5
					,SOURCE.SettlementStatusID 
					,@Creator
					,GETDATE()
					,@Creator
					,GETDATE()
				);
	END 
	/* END - @Command = 'NAP_Admin_Settlement_Refund_All' */
END
GO

