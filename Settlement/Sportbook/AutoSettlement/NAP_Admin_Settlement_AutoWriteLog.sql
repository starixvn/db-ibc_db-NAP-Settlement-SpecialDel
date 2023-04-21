/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin,Dot_CoreAPI,Dot_Intg,Dot_Casino" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_AutoWriteLog] 
	 @AdminId			INT				= 148		-- calculated by system (default)
	,@MatchId			INT
	,@ResourceIDs		VARCHAR(MAX)	= '' 
	,@Results			VARCHAR(MAX)	= ''
	,@Action			VARCHAR(10)		= 'CAL'
	,@IsAuto			BIT				= 1
	,@IP				VARCHAR(15)		= ''
	,@IsSuccess			BIT				= 1
	,@Remark			VARCHAR(MAX)	= ''
	,@Product			VARCHAR(50)		= 'BetRadar'
AS
/*	Creator: Kathy
	Date: 20140711
	Task: Write log for Penalty Shootout [Redmine:#17142]
	DB: DBTXN/BODB02

	Revisions:		
		- 20150507@Jamie: Betradar2 
		- 20161116@Kathy: Fast Market [Redmine:#56367]
		- 20170113@Kathy: Enhancement for Fast Market [Redmine:#69951]
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		- 20210428@Kathy: Allow to settle directly for bettype 228 [Redmine:#153155]
		- 20210514@Kathy: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20210518@Louisa: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		
	Param's Explanation:
		@Product: BetRadar
				  FastMarket
				  BetBuilder
				  PinGoal
				  
		For FastMarket: 
			@Result = '<BetTypes>
							<BetType Id="">
								<Item Position=""/>
								<Item Position=""/>
							</BetType>
	
						</BetTypes>'
		For BetBuilder
			@ResourceIDs = '<Resources>
					            <rsc m="1"/>
					            <rsc m="2"/>
					            <rsc m="3"/>
					            <rsc m="4"/>
					            <rsc m="5"/>
					         </Resources>'
		For PinGoal:
			@ResourceIDs =  '<Resources>
								<Resource Id="00" Home="1" Away="3" />
							</Resources>'
		
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE  @actionid INT
			,@fth INT
			,@fta INT
			,@hth INT
			,@hta INT
			,@goalrecord NVARCHAR(50)
			,@logdata NVARCHAR(MAX)

	-- For FastMarket & Betradar
	SET @actionid = CASE WHEN @IsSuccess = 1 then 143 
						 ELSE 144
					END
	
	IF @Product = 'FastMarket'
	BEGIN
		DECLARE @tblResultDetail TABLE (
			bettype		SMALLINT	
			,DisplayPosition VARCHAR(10)
		)
		
		DECLARE @resultString VARCHAR(MAX) = ''
				,@xmlData XML
		
		SET @xmlData = CAST(@Results AS XML)
		
		SELECT   @fth = finalhomescore
				,@fta = finalawayscore
				,@hth = hthomescore
				,@hta = htawayscore
				,@goalrecord = GoalRecord
		FROM	dbo.match with(NOLOCK)
		WHERE 	matchid = @matchid
		
		;WITH TmpData AS (
			SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
				,X.C.value('@Position','TINYINT') as Position
			FROM @xmlData.nodes('/BetTypes/BetType') AS T(C)
				CROSS APPLY
					C.nodes('Item') AS X(C)
		)
		INSERT INTO @tblResultDetail (bettype, DisplayPosition)
		SELECT	bettype
				,CASE 
					WHEN bettype IN (228,229) AND Position = 45 THEN '44+'
					WHEN bettype IN (228,229) AND Position > 45 THEN CAST(Position -1 AS VARCHAR)
					ELSE CAST(Position AS VARCHAR)
				END
		FROM TmpData
		
		SELECT @resultString = @resultString 
			+ 'Bettype: ' + CAST(t.bettype AS VARCHAR) 
			+ '; Interval: ' + STUFF((SELECT	',' + DisplayPosition FROM @tblResultDetail r WHERE	r.bettype = t.bettype FOR XML PATH('')),1,1,'') +'</br>' 
		FROM @tblResultDetail t
		GROUP BY bettype
		
		SET @Remark = 'NAP: ' + @Product + '</br>'
						+ 'IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
						+ ' Action:' + @Action + '<br/>'
						+ @resultString 
						+ @remark
		
	END
	ELSE IF @Product = 'BetBuilder'
	BEGIN
		CREATE TABLE #tblMarket (marketID VARCHAR(20))
		DECLARE @xml XML
				,@totalMarketIDs INT			= 0
				,@totalSettledMarketIDs INT		= 0
				,@listMarketIDs VARCHAR(MAX) 	
				,@maxResultShowed INT			= 1000
		
		SET @xml = CAST(@ResourceIDs AS XML)
				
		;WITH TmpData AS (
			SELECT T.C.value('@m', 'VARCHAR(20)') AS MarketID
			FROM @xml.nodes('/Resources/rsc') AS T(C)
		)
		INSERT INTO #tblMarket (marketID)
		SELECT 	MarketID
		FROM	TmpData d
		
		SET @totalMarketIDs = @@ROWCOUNT
		
		SELECT	@listMarketIDs = COALESCE(@listMarketIDs + ',' + MarketID, MarketID)
		FROM 	#tblMarket
		
		IF ISNULL(@Remark,'') <> ''
		BEGIN
			SELECT	@totalSettledMarketIDs = COUNT(*)
			FROM	STRING_SPLIT(@Remark,',')
		END
		
		-- Add new log action for BetBuilder
		SET @actionid = CASE WHEN @IsSuccess = 1 then 81013 
						 ELSE 81014
					END
		
		SET @Remark = 'NAP: ' + @Product + '</br>'
						+ ' MatchID: ' + CAST(@MatchId AS VARCHAR) + '; IsAuto: ' + CAST(@IsAuto AS VARCHAR) + '; Action: ' + @Action 
						+ '<br/>'
						+ CASE WHEN @totalMarketIDs <= @maxResultShowed THEN 'MarketIDs: ' + @listMarketIDs ELSE ' Total MarketIDs: ' + CAST(@totalMarketIDs AS VARCHAR) END
						+ CASE  WHEN @totalSettledMarketIDs = 0 THEN ''
								WHEN @totalSettledMarketIDs <= @maxResultShowed THEN '<br/>Settled MarketIDs: ' + @Remark 
								ELSE '<br/> Total Settled MarketIDs:' + CAST(@totalSettledMarketIDs AS VARCHAR) END
	END
	ELSE IF @Product = 'PinGoal'
	BEGIN
		DECLARE @resultPinGoal VARCHAR(MAX) = ''
				,@xmlstr XML
		
		SET @xmlstr = CAST(@ResourceIDs AS XML)

		;WITH TmpData AS (
			SELECT T.C.value('@Id', 'VARCHAR(20)') AS ResourceID
				  ,T.C.value('@Home', 'VARCHAR(50)') AS Home
				  ,T.C.value('@Away', 'VARCHAR(50)') AS Away
			FROM @xmlstr.nodes('/Resources/Resource') AS T(C)
		)
		
		SELECT @resultPinGoal = @resultPinGoal + ',' + ResourceID	
								+ CASE WHEN ISNULL(Home,'') <> '' AND ISNULL(Away,'') <> '' 
									   THEN '(' + Home + '-' + Away + ')'
									   ELSE '' END
		FROM TmpData


		SELECT @resultPinGoal = STUFF(@resultPinGoal, 1, 1, '')

		SELECT	@Remark = 'NAP:ResourceIDs:' + @resultPinGoal +  ' <br/> ' 
							+ 'IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
							+ ' Action:' + @Action +  ' <br/> ' 
							+ @Remark


	END
	ELSE
	BEGIN
		SELECT	@Remark = 'NAP:ResourceIDs:' + @ResourceIDs +  ' <br/> ' 
							+ 'IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
							+ 'Action:' + @Action +  ' <br/> ' 
							+ @Remark
	END
	
	EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle @userid = @AdminId
		,@matchid = @matchid
		,@actionid = @actionid
		,@finalhomescore = @fth
		,@finalawayscore = @fta
		,@hthomescore = @hth
		,@htawayscore = @hta
		,@GoalRecord = @goalrecord
		,@betstatus = NULL
		,@remark = @Remark
		,@ip = @IP
	
END

GO
