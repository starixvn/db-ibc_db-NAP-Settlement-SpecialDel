/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Checking] 
	@MatchId 				INT = NULL
	, @MatchIds 			VARCHAR(4000) = NULL OUTPUT
	, @Action 				VARCHAR(10) = 'CAL'
	, @Mode 				VARCHAR(20) = 'CAL'
	, @ResourceIDs 			VARCHAR(MAX)	= '' 
	, @IsExcludeCorner 		BIT = 0
	, @IsExcludeFGLG 		BIT = 0
	, @IsAutoCalculatePage 	BIT = 0
	, @xmlData				VARCHAR(MAX) = NULL
	, @SelectedQuarter 		VARCHAR(50) = NULL
	, @SelectedSet			VARCHAR(50)     = NULL 
	, @ErrCode 				INT = 0 OUTPUT
	, @ErrMsg 				NVARCHAR(200)	= '' OUTPUT
AS
/*	Creator: Kathy
	Date: 2015-04-01
	Task: checking ticket status
	DB: DBTXN/BODB02

	Revisions:		
		- 20150415@Kathy: Apply new BetRadar bettypes [Redmine:#27212]
		- 20150605@Jamie: Correct checking for AUTO Bets 
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160315@Patrick: Auto payout [Redmine: #53262]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170522@Kathy: Correct checking waiting tickets for tennis [Redmine:#76931]
		- 20170609@Kathy: Basketball All-in-One Early Settlement [Redmine:#77835]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20181114@Helen:  Second Accept - Processing for Waiting Tickets [Redmine:104755]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190107@Kathy: set ticket running if it is accepted by both auto accept & second accept [Redmine:#107452]
		- 20190124@Sol: Second Accept Process of Parlay Tickets [Redmine #107296]
		- 20190425@Sol: Update SettlementTime col when status/winlost changed  [Redmine:#106901]
		
	Param's Explanation:
		@Mode			@Action
		CAL				CAL, CAL-HT, CAL-FT
		CAL-PS			CAL
		CAL-MP			CAL, REFUND, REFUND-HT, REFUND-FT
		CAL-FGLG		CAL-HT, CAL-FT
		REFUND			REFUND, REFUND-HT, REFUND-FT, BetDaq, BetFair		
		REFUND-FGLG		REFUND, REFUND-HT, REFUND-FT
		CAL-AUTO		CAL, REFUND
		CAL-CORNER		CAL 
		
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistWaitingTicket BIT = 0	
	DECLARE @xml XML
	DECLARE @bettype_22 VARCHAR(20), @bettype_160 VARCHAR(20)
    DECLARE @currentdate DATETIME
    
	DECLARE @Sporttype SMALLINT, @isSettingByProfile BIT = 0
	DECLARE @handle INT
    SET @currentdate = CURRENT_TIMESTAMP
    
	DECLARE	@tmpResourceIDs TABLE(
		ResourceID	VARCHAR(20)
		,Bettype	INT
		,BetID		BIGINT
	)

	SET @bettype_22 = '22'
    SET @bettype_160 = '160'
    
    SELECT @Sporttype = sporttype
    FROM dbo.[match] WITH (NOLOCK)
    WHERE matchid = @matchid
    
    IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
    BEGIN
	    SET @isSettingByProfile = 1
	END
	
	
	
	IF @Mode = 'CAL-AUTO'
	BEGIN
		INSERT INTO @tmpResourceIDs(ResourceID,Bettype)
		SELECT val, CAST(LEFT(val,3) AS INT) FROM strSplit(@ResourceIDs,',')
		
		-- Bettype 22 use the same resource to bettype 160
		IF EXISTS (SELECT 1 FROM @tmpResourceIDs WHERE bettype = 160)
		BEGIN
			INSERT INTO @tmpResourceIDs(ResourceID,Bettype) 
			SELECT  ResourceID,22
			FROM @tmpResourceIDs
			WHERE Bettype = 160
		END
		-- Bettypes: 135,160,22,164,168,169,173,174,175,176,180,192,193,210,211,212,213,214,215,216,217
		IF EXISTS (SELECT TOP 1 1 
					FROM dbo.bettrans b WITH(NOLOCK)
					WHERE b.matchid = @matchid
					AND (b.statusID = 1 -- waiting status
						 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime, @currentdate) > @currentdate))
					
					AND b.bettype IN (SELECT bettype FROM @tmpResourceIDs) 
					AND 1 = CASE 
								WHEN b.bettype = 22 AND CHARINDEX(REPLACE(SUBSTRING(CAST(betID AS VARCHAR(20)),2,5),@bettype_22,@bettype_160),@ResourceIDs)>0 THEN 1 
								WHEN b.bettype IN (160,164,169,180) AND CHARINDEX(SUBSTRING(CAST(betID AS VARCHAR(20)),2,5),@ResourceIDs)>0 THEN 1 
								WHEN b.bettype NOT IN (160,164,169,180,22) THEN 1
								ELSE 0
							END
					AND @Action IN ('CAL', 'REFUND')
				)
			SELECT @isExistWaitingTicket = 1
	END
	IF @Mode ='CAL-CORNER'
	BEGIN
		IF EXISTS (	SELECT TOP 1 1 
					FROM	dbo.bettrans b WITH(NOLOCK)
					WHERE	b.matchid = @matchid
							AND (b.statusID = 1 -- waiting status
								OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate ))
								
							AND ((@Action IN ('CAL') AND b.bettype IN (194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209))
									OR (@Action IN ('CAL-HT') AND b.bettype IN (200,201,202,203,204,205,207,209))
									OR (@Action IN ('CAL-FT') AND b.bettype IN (194,195,196,197,198,199,206,208))
								)
		)
		SELECT @isExistWaitingTicket = 1
	END
	IF @Mode IN ('CAL', 'REFUND')
	BEGIN	
		IF @isSettingByProfile = 1
		BEGIN			
			EXEC sp_xml_preparedocument @handle OUTPUT, @xmlData
		    INSERT INTO @tmpResourceIDs(ResourceID, BetType, BetID)
		    SELECT DISTINCT Id, sp.BetType, sp.BetID
		    FROM OPENXML(@handle,'Resources/Resource',1) WITH (Id VARCHAR(20)) AS tbl
		        INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.Id
		    WHERE sp.SportType = @SportType 
		    EXEC sp_xml_removedocument @handle
	
		    
			IF EXISTS (SELECT TOP 1 1
					   FROM dbo.bettrans b WITH(NOLOCK)
					   WHERE b.matchid = @matchid
					   		AND (b.statusID = 1 -- waiting status
								OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate ))
							AND EXISTS (SELECT 1 
					   					FROM @tmpResourceIDs t
					   					WHERE t.Bettype = b.Bettype AND (t.BetID = 0 OR t.BetID = b.BetID)
					   					)
					)	
				SELECT @isExistWaitingTicket = 1
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN dbo.f_Set_GetGroupBettypes() f
						ON b.bettype = f.BetType
				WHERE b.matchid = @matchid
			
			AND (b.statusID = 1 -- waiting status
				OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
			
				AND f.IsAuto = 0
				AND ((@Action IN ('CAL', 'REFUND'))
					OR (@Action IN ('CAL-HT', 'REFUND-HT')
							AND f.GroupId IN (1,3,5) -- HT, HT FGLG, HT Corner 						
							AND 1 = CASE WHEN @IsExcludeCorner = 1 AND f.GroupId = 5 THEN 0 ELSE 1 END
							AND 1 = CASE WHEN @IsExcludeFGLG = 1 AND f.GroupId = 3 THEN 0 ELSE 1 END)
					OR (@Action IN ('CAL-FT', 'REFUND-FT') 
							AND f.GroupId NOT IN (1,3,5)
							AND 1 = CASE WHEN @IsExcludeCorner = 1 AND f.GroupId = 6 THEN 0 ELSE 1 END
							AND 1 = CASE WHEN @IsExcludeFGLG = 1 AND f.GroupId = 4 THEN 0 ELSE 1 END
							AND 1 = CASE WHEN @IsAutoCalculatePage = 1 AND f.IsUsedGoalRecordValue = 1 THEN 0 ELSE 1 END) --exclude bettype [172] in case auto-payout
					)
				AND 1 = CASE
							WHEN @SelectedQuarter IS NULL THEN 1
							WHEN @SelectedQuarter LIKE '%' + f.GroupName + '%' THEN 1
							WHEN f.GroupId = 10 AND @SelectedQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1
							ELSE 0
						END
				AND 1 = CASE -- tennis
							WHEN @SelectedSet IS NULL THEN 1
							WHEN @SelectedSet LIKE '%6%' AND b.bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
							WHEN b.bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) 
								THEN CASE 
										WHEN @SelectedSet LIKE '%1%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '801' THEN 1
										WHEN @SelectedSet LIKE '%2%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '802' THEN 1
										WHEN @SelectedSet LIKE '%3%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '803' THEN 1
										WHEN @SelectedSet LIKE '%4%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '804' THEN 1
										WHEN @SelectedSet LIKE '%5%' AND LEFT(CAST(b.betid AS VARCHAR),3) = '805' THEN 1
									ELSE 0
								END
							ELSE 0
						END
				
			)
				SELECT @isExistWaitingTicket = 1
		END
		
	END
	--IF @Mode IN ('CAL-FGLG') AND @IsAutoCalculatePage = 1
	--BEGIN
	--	IF EXISTS (SELECT TOP 1 1 
	--			FROM dbo.bettrans b WITH(NOLOCK)
	--				INNER JOIN dbo.f_Set_GetGroupBettypes () f
	--					ON b.bettype = f.BetType
	--			WHERE b.matchid = @matchid
	--			AND (b.statusID = 1 -- waiting status
	--					 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
	--			AND f.IsUsedGoalRecordValue = 1
	--			AND 1 = CASE WHEN @Action = 'CAL-HT' AND f.GroupId = 3 THEN 1
	--							WHEN @Action = 'CAL-FT' AND f.GroupId IN (2,4) THEN 1
	--					ELSE 0 END
	--		)
	--		SELECT @isExistWaitingTicket = 1
	--END
	
	IF @Mode = 'CAL-PS'
	BEGIN
		IF EXISTS (SELECT TOP 1 1 
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE b.matchid = @matchid
				AND (b.statusID = 1 -- waiting status
						 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
				AND b.bettype = 135
						
			)
			SELECT @isExistWaitingTicket = 1
	END
	IF @Mode = 'REFUND'
	BEGIN
		IF @Action = 'BetDaq'
		BEGIN	
			IF EXISTS (SELECT TOP 1 1 
				FROM	dbo.bettrans b WITH(NOLOCK)
					INNER JOIN dbo.f_Set_GetGroupBettypes() f
						ON b.bettype = f.BetType
				WHERE	b.matchid = @matchid
						AND (b.statusID = 1 -- waiting status
						 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
						 
						AND f.GroupId BETWEEN 1 AND 7
						AND b.bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
						AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
							OR recommend = 1688156	)
			)
				SELECT @isExistWaitingTicket = 1
		END		
		
		IF @Action = 'BetFair'
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN dbo.f_Set_GetGroupBettypes() f
						ON b.bettype = f.BetType
				WHERE b.matchid = @matchid
				AND (b.statusID = 1 -- waiting status
						 OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
				AND f.GroupId BETWEEN 1 AND 7
				AND b.bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
				AND custid IN (2331, 1077687, 115770, 15523642)
			)
				SELECT @isExistWaitingTicket = 1
		END	
	END
	IF @Mode = 'CAL-MP'
	BEGIN		
		DECLARE @wtMatch TABLE (matchid INT)
		
		INSERT INTO @wtMatch(matchid)
		SELECT b.matchid
		FROM bettransm b WITH(NOLOCK)
			INNER JOIN dbo.f_Set_GetGroupBettypes() f
				ON b.bettype = f.BetType
		WHERE b.matchid IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@MatchIds, ','))
		AND 
			(
				b.statusID = 1 -- waiting status
				OR (b.statusID = 0 AND b.SecAcceptFlag = 1 AND ISNULL(b.checktime,@currentdate) > @currentdate)
			)
		GROUP BY b.matchid
		
		SET @MatchIds = ''
		
		IF EXISTS(SELECT TOP 1 1 FROM @wtMatch)
		BEGIN
			SELECT @MatchIds = COALESCE(@MatchIds + ',' + CONVERT(VARCHAR(20),matchid), CONVERT(VARCHAR(20),matchid)) -- retrieve matchids have 'waiting' tickets
			FROM @wtMatch
			
			SET @isExistWaitingTicket = 1		
			
		END
		
	END

	IF @Mode = 'CAL-FM'
	BEGIN
		DECLARE @tblBettype TABLE (bettype SMALLINT, position TINYINT)
		
		SET @xml = CONVERT(XML,@xmlData)

		INSERT INTO @tblBettype (bettype, position)
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
		FROM @xml.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
				
		IF EXISTS (SELECT TOP 1 1 
					FROM	dbo.bettrans b WITH(NOLOCK)
						INNER JOIN @tblBettype t
							ON	b.bettype = t.bettype
								AND b.hdp1 = t.position
					WHERE	b.matchid = @matchid
							AND (b.statusID = 1 -- waiting status
							OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
			)
			SELECT @isExistWaitingTicket = 1
	END
	
	IF @Mode = 'CAL-EARLY'
	BEGIN
		IF @isSettingByProfile = 1
		BEGIN
			EXEC sp_xml_preparedocument @handle OUTPUT, @xmlData
		    INSERT INTO @tmpResourceIDs(ResourceID, BetType, BetID)
		    SELECT DISTINCT Id, sp.BetType, sp.BetID
		    FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id    VARCHAR(20)
					                                           ,Home VARCHAR(50)
					                                           ,Away VARCHAR(50)
		                                        ) AS tbl
		        INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.Id
		    WHERE sp.SportType = @SportType 		    
		    EXEC sp_xml_removedocument @handle
	
		    
			IF EXISTS (SELECT TOP 1 1
					   FROM dbo.bettrans b WITH(NOLOCK)
					   		INNER JOIN @tmpResourceIDs t ON b.Bettype = t.Bettype AND (t.BetID = 0 OR t.BetID = b.BetID)
					   WHERE b.matchid = @matchid
					   		AND (b.statusID = 1 -- waiting status
								OR (b.statusID = 0 AND b.SecAcceptFlag = 1 AND ISNULL(b.checktime, @currentdate) > @currentdate)
							)
					)	
				SELECT @isExistWaitingTicket = 1
		END
		ELSE 
		BEGIN
			SET @xml = CONVERT(XML,@xmlData)
			CREATE TABLE #tmpEarlyBettypes (bettype SMALLINT PRIMARY KEY)
			
			INSERT INTO #tmpEarlyBettypes(bettype)
			SELECT	bettype
			FROM	dbo.f_Set_GetEarlyBettypes()
			
			
			INSERT INTO @tmpResourceIDs (ResourceID)
			SELECT	T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
			FROM	@xml.nodes('/Results/Resource') AS T(C)
			
			IF EXISTS(SELECT  TOP 1 1
						FROM	@tmpResourceIDs t
							INNER JOIN (
								SELECT	CAST(CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)),'') AS VARCHAR(20)) AS ResourceId
								FROM	dbo.bettrans b WITH(NOLOCK)
									INNER JOIN #tmpEarlyBettypes t
										ON b.bettype = t.bettype
								WHERE	b.matchid = @matchid
									AND (b.statusID = 1 -- waiting status
									OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
							) b
								ON b.ResourceId = t.ResourceID
				)
				SELECT @isExistWaitingTicket = 1
		END
		
		
	END
	
	IF @isExistWaitingTicket = 1
	BEGIN
		SELECT @ErrCode = 1001013
			,@ErrMsg = 'Cannot proceed as there exists some PENDING tickets in this match. Please contact admin for help.'
			
		RETURN
	END	
END
GO

