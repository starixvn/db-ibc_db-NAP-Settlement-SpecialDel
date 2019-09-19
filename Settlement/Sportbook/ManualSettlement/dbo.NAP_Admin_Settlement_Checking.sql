/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Checking] 
	@MatchId 				INT = NULL
	, @MatchIds 			VARCHAR(4000) = NULL OUTPUT
	, @Action 				VARCHAR(10) = 'CAL'
	, @Mode 				VARCHAR(20) = 'CAL'
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
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		
	Param's Explanation:
		@Mode			@Action
		CAL				CAL, CAL-HT, CAL-FT
		CAL-PS			CAL
		CAL-MP			CAL, REFUND, REFUND-HT, REFUND-FT
		CAL-FGLG		CAL-HT, CAL-FT
		REFUND			REFUND, REFUND-HT, REFUND-FT, BetDaq, BetFair		
		REFUND-FGLG		REFUND, REFUND-HT, REFUND-FT
		CAL-AUTO		CAL, REFUND
		
		
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistWaitingTicket	BIT
		,@xml						XML
		,@currentdate				DATETIME
		,@Sporttype					SMALLINT
		,@isSettingByProfile		BIT
		,@handle					INT
    
	
	DECLARE	@tmpResourceIDs TABLE(
		ResourceID	VARCHAR(20)
		,Bettype	INT
		,BetID		BIGINT
	)

	SELECT @currentdate = CURRENT_TIMESTAMP
			,@isExistWaitingTicket = 0
			,@isSettingByProfile = 0
    
    SELECT	@Sporttype = sporttype
    FROM	dbo.[match] WITH (NOLOCK)
    WHERE	matchid = @matchid
    
    IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
    BEGIN
	    SET @isSettingByProfile = 1
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
							AND f.GroupId IN (1,3) -- HT, HT FGLG						
						)
					OR (@Action IN ('CAL-FT', 'REFUND-FT') 
							AND f.GroupId NOT IN (1,3)
						) --exclude bettype [172] in case auto-payout
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
		IF @isSettingByProfile = 1 OR @Sporttype = 1
		BEGIN
			EXEC sp_xml_preparedocument @handle OUTPUT, @xmlData
		    INSERT INTO @tmpResourceIDs(ResourceID, BetType, BetID)
		    SELECT DISTINCT tbl.Id, sp.BetType, sp.BetID
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

