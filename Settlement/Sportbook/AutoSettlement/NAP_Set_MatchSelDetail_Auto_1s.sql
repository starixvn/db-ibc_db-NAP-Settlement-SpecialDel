/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Auto_1s]
    @MatchID        INT
	,@IsSettleAbandonedMatchIBC	BIT = 0 OUTPUT
	
AS
/*    Creator: Jamie
    Date: 20150202
    Task: BetRadar - Auto settlement detail for manual calculation 
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
        - 20161118@Kathy: Changes on Auto Settlement [Redmine:#67328]
		- 20160505@Patrick: Move code select match info to another SP [RedmineId: #56587]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		
    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON 
    
    DECLARE @bettype_22		VARCHAR(20)
			,@bettype_160	VARCHAR(20)
			,@sporttype		SMALLINT
		
    SET @bettype_22 = '22'
    SET @bettype_160 = '160'
            
    DECLARE    @tmpTicketStatus TABLE(
         ResourceID			VARCHAR(20)
        ,BetCount			INT
        ,InRunning			INT
        ,InWaiting			INT
        ,GroupId			SMALLINT
		,betSettledCount	INT
		,betMarkedCount		INT 
    )

    DECLARE    @tmpTicketStatusParlay TABLE(
         ResourceID			VARCHAR(20)
        ,BetCount			INT
        ,InRunning			INT
        ,InWaiting			INT
        ,GroupId			SMALLINT
    )

	DECLARE @tmpAutoBettypes TABLE (bettype SMALLINT PRIMARY KEY, IsDetermined BIT)
	
	CREATE TABLE #tmpBettrans (
		TransId		BIGINT
		,BetType	SMALLINT
		,ResourceId VARCHAR(20) 
		,statusId	TINYINT
		,betid		BIGINT
		,IsMarked	BIT DEFAULT(0)
	)

	INSERT INTO @tmpAutoBettypes (bettype, IsDetermined)
	SELECT	bettype
			,IsDetermined
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId = 8
		
	SELECT	@sporttype = sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchID

    IF EXISTS (
                SELECT TOP 1 1
                FROM bettrans b WITH (NOLOCK)
                    INNER JOIN @tmpAutoBettypes f
                        ON b.bettype = f.BetType
                WHERE    f.IsDetermined = 1
                        AND matchid = @matchid 
						AND statusID NOT IN (101, 102, 103) 
                        AND ruben = 0 
            )
    BEGIN
        SELECT @IsSettleAbandonedMatchIBC = 1
    END
    
	INSERT INTO #tmpBettrans (TransId, BetType, ResourceId, statusId, betid)
	SELECT	b.transid
			,b.bettype
			,CASE
                WHEN b.bettype = 22 THEN  @bettype_160 + SUBSTRING(CAST(betID AS VARCHAR(20)),4,5)
                WHEN b.bettype IN (160, 164, 169, 180) THEN SUBSTRING(CAST(betID AS VARCHAR(20)),2,5) 
                ELSE b.bettype 
            END AS ResourceID
			,b.statusID
			,b.betid
	FROM    dbo.Bettrans b WITH (NOLOCK)
        INNER JOIN @tmpAutoBettypes f
            ON b.bettype = f.BetType
    WHERE    matchID = @MatchID 
		AND b.statusID NOT IN (101,102)

	IF @sporttype = 1
	BEGIN
		UPDATE b 
			SET IsMarked = 1
		FROM	#tmpBettrans b
			INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON b.TransId = mt.TransId
	END

    INSERT INTO @tmpTicketStatus(ResourceID, BetCount, InRunning,InWaiting, betSettledCount, betMarkedCount)
    SELECT    
            b.ResourceId            
            ,SUM(CASE    WHEN StatusID BETWEEN 101 AND 102 THEN 0
                        ELSE 1 END)
             
             -- StatusID = 0: Running, 1: Waiting           
            ,SUM(CASE WHEN StatusID = 0 AND b.IsMarked = 0 THEN 1 ELSE 0 END) AS InRunning  
            ,SUM(CASE WHEN StatusID = 1 AND b.IsMarked = 0 THEN 1 ELSE 0 END) AS InWaiting 
			,SUM(CASE WHEN b.statusID BETWEEN 111 AND 113 OR b.statusID = 103 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN b.statusId BETWEEN 0 AND 1 AND b.IsMarked = 1 THEN 1 ELSE 0 END) AS betMarkedCount
    FROM	#tmpBettrans b
    GROUP BY b.ResourceId

	INSERT INTO @tmpTicketStatusParlay( ResourceID, BetCount, InRunning, InWaiting)
    SELECT  CASE
                WHEN bm.bettype = 22 THEN  REPLACE(SUBSTRING(CAST(bm.betcheck AS VARCHAR(20)),2,5),@bettype_22,@bettype_160)
                WHEN bm.bettype IN (160, 164, 169, 180) THEN SUBSTRING(CAST(bm.betcheck AS VARCHAR(20)),2,5) 
                ELSE bm.bettype 
            END AS ResourceID            
			
			,SUM(CASE    WHEN bm.StatusID BETWEEN 101 AND 102 THEN 0
						ELSE 1 END)
			 -- StatusID = 0: Running, 1: Waiting           
            ,SUM(CASE    WHEN bm.StatusID = 0 THEN 1 ELSE 0 END) AS InRunning  
            ,SUM(CASE    WHEN bm.StatusID = 1 THEN 1 ELSE 0 END) AS InWaiting 
						             
    FROM    dbo.Bettransm bm WITH (NOLOCK)
        INNER JOIN @tmpAutoBettypes f
            ON bm.bettype = f.BetType
    WHERE    matchID = @MatchID 
		AND bm.statusID NOT IN (101,102)
    GROUP BY  CASE
                WHEN bm.bettype = 22 THEN  REPLACE(SUBSTRING(CAST(bm.betcheck AS VARCHAR(20)),2,5),@bettype_22,@bettype_160)
                WHEN bm.bettype IN (160, 164, 169, 180) THEN SUBSTRING(CAST(bm.betcheck AS VARCHAR(20)),2,5) 
                ELSE bm.bettype 
            END
    
	-- Detail 
    SELECT    
		
		 ResourceID = CASE WHEN COALESCE(r.ResourceID,t.ResourceID,p.ResourceID) ='216' THEN '21601' ELSE COALESCE(r.ResourceID,t.ResourceID,p.ResourceID) END 
            ,TicketStatus = CASE 
								WHEN t.InRunning > 0 THEN 'Running'
								WHEN t.InWaiting > 0 AND t.InWaiting = t.BetCount THEN 'Waiting'
								WHEN t.betMarkedCount > 0 THEN 'Marked'
								WHEN ISNULL(t.BetCount,0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
								WHEN ISNULL(t.BetCount,0) = 0 AND p.InWaiting > 0 AND p.BetCount = p.InWaiting THEN 'Parlay Waiting'
                                ELSE 'Calculated'
                            END
             ,HomeValue = CASE WHEN r.ResourceId BETWEEN 214 AND 215 THEN r.AwayValue ELSE r.HomeValue END
            ,r.OtherInfo
            ,r.ResultStatusID
            ,r.SettlementStatusID
    FROM    @tmpTicketStatus t
			FULL JOIN @tmpTicketStatusParlay p	ON t.resourceId = p.ResourceID
           OUTER APPLY( 
						SELECT  r.MatchID  
								,r.ResourceId
								,CASE WHEN r.ResourceID LIKE '216__' THEN '216' ELSE r.ResourceID END AS ResourceID2 
								,r.HomeValue
								,r.AwayValue
								,r.OtherInfo
								,r.ResultStatusID
								,r.SettlementStatusID                      
						FROM    DBPRO.bodb02.dbo.ResultDetail r WITH (NOLOCK)
						WHERE  CASE WHEN r.ResourceID LIKE '216__' THEN '216' ELSE r.ResourceID END  = COALESCE(t.ResourceID,p.ResourceID) AND r.MatchId =  @MatchID
						) AS r
						
    ORDER BY CASE WHEN COALESCE(r.ResourceID,t.ResourceID,p.ResourceID) ='216' THEN '21601' ELSE COALESCE(r.ResourceID,t.ResourceID,p.ResourceID) END  ASC 

	-- number of ticket
	SELECT	8 AS GroupId 
			,SUM(InRunning) AS betRunningCount
			,SUM(betSettledCount) AS betSettledCount
			,SUM(betMarkedCount) AS betMarkedCount
	FROM	@tmpTicketStatus
END
GO