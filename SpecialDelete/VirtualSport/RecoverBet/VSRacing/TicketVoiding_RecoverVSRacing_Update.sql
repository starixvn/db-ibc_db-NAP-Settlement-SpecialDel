/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RecoverVSRacing_Update]
	@MatchID					   INT			= 0
	,@TransInfoJson                 VARCHAR(MAX)    = ''
	,@UserId						INT = 0
	,@IP							VARCHAR(15) = ''
    ,@ErrorMsg						VARCHAR(300)	= ''	OUTPUT
	,@ErrorCode				        INT				= 0		OUTPUT
	,@NegativeBalanceUsers			VARCHAR(MAX)	= ''	OUTPUT
AS
/*  
	Created by: 20250220@Max  
	Task: [TVS] Recover ticket of Virtual Sports 2 [Redmine: #212323]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02	    

	Revisions:  		
		- 20250220@Max: [TVS] Recover ticket of Virtual Sports 2 [Redmine: #212323]
		- 20250324@Max: [TVS] Virtual Sports 7 (Kiron Virtual Sports) [Redmine: #219045]

	Param's Explanation:		
*/
BEGIN
    SET NOCOUNT ON

	DECLARE	 @StepNumber INT = 0
		, @SiteDBGroupID		SMALLINT
		, @transInfo				VARBINARY(MAX) 
		, @TransInfoMaxPO		VARCHAR(MAX)
		, @isITAdmin					  BIT = 0
		
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, transdate DATETIME, comstatus NVARCHAR(40) )
	
	CREATE TABLE #RecoverBet (TransID BIGINT PRIMARY KEY, CustId INT, MatchId INT, bettype SMALLINT)

	INSERT INTO #RecoverBet (TransID, MatchId, CustId, bettype)
	SELECT   t.t AS transId, b.matchid, b.custid, b.bettype
	FROM OPENJSON(@TransInfoJson) WITH (t BIGINT) AS t
	INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.t = b.TransId
 
    BEGIN TRY
		--Update info bettrans, balance
		SET @StepNumber = 1 

        EXEC dbo.TicketVoiding_ReCalculate_Single_Update
            @TransIds = @TransInfoJson
			,@Mode = 'RECOVER-VS'
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
		
		--delete zzzbettrans
		SET @StepNumber = 2 

		DELETE z
			OUTPUT deleted.transid, deleted.matchid, deleted.transdate, deleted.comstatus
			INTO @tmpTransInfo (transid, matchid, transdate, comstatus)
		FROM zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			 INNER JOIN #RecoverBet t 
					 ON	z.transid = t.transid
						AND z.custid = t.custid
						AND z.matchid = t.matchid
						AND z.bettype = t.bettype

		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, transdate AS 'td'
					, comstatus AS 'cst'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
			SELECT 'TVS', 'RecoverVS', 'zzzbettrans', 'D', @matchid, @TransInfo, 's', 1

		END

		----------------Insert Max Payout Queue----------------
		SET @StepNumber = 3
		
		DECLARE @TransIds_MaxPO VARCHAR(MAX) = ''

		SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
				,CASE 
					WHEN dp.custid IS NOT NULL THEN 3 --deposit 
					WHEN s.SiteLabel = '789y' THEN 2 --789y
					ELSE 1 END AS '@sitetype'
				,b.TransId AS '@transid'
				,b.bettype AS '@bettype'
			FROM #RecoverBet b
				INNER JOIN dbo.bettrans main WITH (NOLOCK) ON main.TransId = b.TransID
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
				INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
				LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON main.srecommend = dp.custid
			WHERE b.matchid = @MatchID
			FOR XML PATH('r'), ROOT('root')
		)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Recover
			@MatchId = @MatchID
			,@sporttype = 198 -- hardcode for both 198,177,125,126,127
			,@TransidList = @TransIds_MaxPO

		--> Return data to web	
		SET @StepNumber = 4

		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

		SELECT  r.Stake,
				0 AS AwayId,
				r.BetCheck,
				r.BetId,
				r.BetTeam,
				r.BetType,
				r.CurrencyName AS CurrencyCode,
				r.Hdp1,
				r.Hdp2,
				m.RacerID AS homeid,
				r.liveindicator AS IsLiveIndicator,
				r.LiveAwayScore,
				r.LiveHomeScore,
				r.Odds,
				r.OddsType,
				r.RefNo,
				m.SportType,
				r.Status,
				r.TransDate,
				r.TransDesc,
				r.TransId,
				r.UserName,
				r.WinLost,
				T.GroupName,
				m.showtime,
				m.LeagueId,
				m.matchcode,
				r.modds AS MasterOdds,
				r.matchid,
				NULL AS SubStatus,
				NULL AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubTransdesc,
				r.CustId AS UserId,
				r.recommend AS AgentId,
				ag.UserName AS AgentName,
				r.mrecommend AS MasterId,
				ma.UserName AS MasterName,
				r.srecommend AS SuperId,
				su.Username AS SuperName,
				ci.Site,
				ci.Site AS EmailGroup,
				CURRENT_TIMESTAMP AS [DateTime],
				@isITAdmin AS IsItSupport,
				r.BetFrom 
		FROM #RecoverBet b
			INNER JOIN dbo.bettrans r WITH (NOLOCK) ON r.TransId = b.TransID
			CROSS APPLY (
					SELECT rs.EventStatus, rs.BetStatus, o.EventDate, rs.SportType, o.RacerID, CONVERT(VARCHAR(20), rs.EventTime, 113) AS showtime
							,rs.LeagueID, CONVERT(NVARCHAR(50), o.RacerNum) AS matchcode
					FROM	dbo.VSOutright o WITH (NOLOCK) 
							INNER JOIN dbo.VSRaceInfo rs WITH (NOLOCK) 
							ON rs.EventID = o.EventID
					WHERE o.Orid = r.oddsid
			)m
			LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON r.srecommend = dp.custid
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK)
				ON r.CustId = ci.custid
			LEFT JOIN CustDB.dbo.Customer ag WITH(NOLOCK)
					ON r.recommend = ag.custid
			LEFT JOIN CustDB.dbo.Customer ma WITH(NOLOCK)
					ON r.mrecommend = ma.custid
			LEFT JOIN CustDB.dbo.Customer su WITH(NOLOCK)
					ON r.srecommend = su.custid
			CROSS APPLY (SELECT CASE 
								WHEN dp.custid IS NULL
										AND r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
										AND r.username <> '12EU'  
										AND r.mrecommend NOT IN (105181, 118473, 105183)  
										AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Credit'
								WHEN dp.custid iS NOT NULL  
										AND r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
										AND r.username <> '12EU'  
										AND r.mrecommend NOT IN (105181, 118473, 105183) 
										AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Deposit'																				
								ELSE ''							
								END AS GroupName) AS T
		ORDER BY CASE
					WHEN T.GroupName = 'Credit'	 THEN 0
					WHEN T.GroupName = 'Deposit' THEN 1					
					ELSE 2				
				 END ASC

    END TRY
	BEGIN CATCH
		SELECT @ErrorCode = @StepNumber
			,@ErrorMsg = ERROR_MESSAGE()	
	END CATCH


END