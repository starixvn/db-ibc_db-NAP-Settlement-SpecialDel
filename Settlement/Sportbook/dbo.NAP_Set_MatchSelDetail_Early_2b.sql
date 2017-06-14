/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Early_2b]
    @MatchID        INT
AS
/*   Creator: 20170613@Kathy
    Task: BAIO - Early settlement detail
    DB: DBTXN/BODB02
    
    Revisions:
        - 20170613@Kathy: Early Settlement [Redmine:#77835] 
      
    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON 
    
    DECLARE @tmpResultDetail TABLE(
		ResourceId VARCHAR(20)
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
		,ResultStatusId TINYINT
		,SettlementStatusId TINYINT
    )
            
    DECLARE @tmpTicketStatus TABLE(
         ResourceID			VARCHAR(20)
        ,BetCount			INT
        ,InRunning			INT
        ,GroupId			SMALLINT
    )
    
    DECLARE @tmpTicketStatusParlay TABLE(
         ResourceID			VARCHAR(20)
        ,BetCount			INT
        ,InRunning			INT
        ,GroupId			SMALLINT
    )
	
	DECLARE @tmpEarlyBettypes TABLE(
		bettype SMALLINT PRIMARY KEY
	)
	
	INSERT INTO @tmpEarlyBettypes(bettype)
	SELECT	bettype
	FROM	dbo.f_Set_GetEarlyBettypes()
	
	INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue, ResultStatusId, SettlementStatusId)
	SELECT	ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusId
			,SettlementStatusId
	FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
		LEFT JOIN @tmpEarlyBettypes t
			ON	r.ResourceId LIKE CAST(t.bettype as VARCHAR) + '%'
	WHERE	matchid = @MatchId
			AND (r.ResourceId IN ('00','01','OT')
					OR r.ResourceId LIKE 'Q[1-4]'
					OR t.bettype IS NOT NULL
				)			
	
    INSERT INTO @tmpTicketStatus(ResourceID, BetCount, InRunning)
    SELECT    
            CAST(CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)),'') AS VARCHAR(20)) AS ResourceId
            ,SUM(CASE    
					WHEN StatusID BETWEEN 101 AND 102 THEN 0
                    ELSE 1 
                 END)
            ,SUM(CASE    
					WHEN StatusID = 0 THEN 1 
                    ELSE 0 
                 END)   
    FROM    dbo.Bettrans b WITH (NOLOCK)
        INNER JOIN @tmpEarlyBettypes f
            ON b.bettype = f.BetType
    WHERE    matchID = @MatchID 
    GROUP BY CAST(CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)),'') AS VARCHAR(20))
	
	INSERT INTO @tmpTicketStatusParlay(ResourceID, BetCount, InRunning)
    SELECT    
            CAST(CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)),'') AS VARCHAR(20)) AS ResourceId       
            ,SUM(CASE    
					WHEN bm.StatusID BETWEEN 101 AND 102 THEN 0
                    ELSE 1 
                 END)
            ,SUM(CASE    
					WHEN bm.StatusID = 0 THEN 1 
                    ELSE 0 
                 END)        
    FROM    dbo.Bettransm bm WITH (NOLOCK)
        INNER JOIN @tmpEarlyBettypes f
            ON bm.bettype = f.BetType
    WHERE    matchID = @MatchID 
    GROUP BY  CAST(CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)),'') AS VARCHAR(20))
	
    -- Detail 
    SELECT  COALESCE(s.ResourceID, p.ResourceID, r.ResourceID) AS ResourceID
            ,CASE 
				WHEN ISNULL(s.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0 THEN 'No Ticket'
				WHEN s.InRunning > 0 THEN 'Running'
				WHEN ISNULL(s.BetCount, 0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
                ELSE 'Calculated'
            END TicketStatus 
			,ISNULL(r.HomeValue, t.HomeValue) AS HomeValue
			,ISNULL(r.AwayValue, t.AwayValue) AS AwayValue
			,ISNULL(r.ResultStatusID, t.ResultStatusId) AS ResultStatusId
			,ISNULL(r.SettlementStatusID, t.SettlementStatusId) AS SettlementStatusId			
    FROM    @tmpTicketStatus s
		FULL JOIN @tmpTicketStatusParlay p
			ON	s.resourceId = p.ResourceID
		FULL JOIN (
			SELECT	ResourceId
					,HomeValue
					,AwayValue
					,ResultStatusID
					,SettlementStatusID
			FROM	@tmpResultDetail
			WHERE	( ResourceId IN ('00','01', 'OT')
						OR ResourceId LIKE 'Q[1-4]'
					)
			) r
				ON	ISNULL(s.ResourceId, p.ResourceId) = r.ResourceId
          LEFT JOIN @tmpResultDetail t			
			ON	COALESCE(r.ResourceId, s.ResourceId, p.ResourceId) = t.ResourceId
				

END
GO
