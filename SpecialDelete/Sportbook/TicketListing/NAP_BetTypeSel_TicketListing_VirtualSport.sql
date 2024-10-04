/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_BetTypeSel_TicketListing_VirtualSport] 
     @MatchId    INT = 0 
    ,@BetTypes   VARCHAR(MAX) = NULL
    ,@ErrMsg	 NVARCHAR(200) = '' OUTPUT
    ,@ErrCode    INT = 0 OUTPUT
AS
/*  
    Created: 20240219@July  
    Task : Ticket Listing - Merge VS1, VS2, VS3 and VS4 into Virtual Sports  [Redmine: #200317]
    DB: DBPRO/bodb02
	
	Revisions: 
		- 20240219@July: Create new SP - [Redmine: #200317]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]

*/
BEGIN
    SET NOCOUNT ON

    DECLARE @ProductId INT    
        
	SELECT @ProductId = (
		SELECT DISTINCT s.ProductID
		FROM dbo.SportBettypeMatrix s WITH (NOLOCK)
			CROSS APPLY(
				SELECT TOP 1 m.sporttype
				FROM dbo.match m WITH (NOLOCK) 
				WHERE s.SportType = m.sporttype AND m.matchid = @MatchId
				UNION ALL
				SELECT TOP 1 r.SportType
				FROM dbo.VSOutright o WITH (NOLOCK)
					INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) ON r.EventID = o.EventID
				WHERE s.SportType = r.sporttype AND o.Orid = @MatchId
					 AND r.sporttype BETWEEN 181 AND 185 -- Inspired VS 181	
				UNION ALL	 
				SELECT TOP 1 m.sporttype
				FROM dbo.Match3rd m WITH (NOLOCK) 
				WHERE s.SportType = m.sporttype AND m.Match3rdId = @MatchId
				UNION ALL
				SELECT TOP 1 r.SportType
				FROM dbo.VSRaceInfo r WITH (NOLOCK)
				WHERE s.SportType = r.sporttype AND r.EventID = @MatchId
					 AND r.sporttype IN (177,198) --Virtual Horse Racing & Virtual Dog Racing
			)m
		WHERE s.ProductID IN (5,27,77,83,88)
		)
        
    IF @ProductId IS NULL
    BEGIN 
        SET @ErrCode = 100
        SET @ErrMsg ='Invalid MatchId.' 
        RETURN
    END 
    
    CREATE TABLE #betTypesTemp (bettype SMALLINT PRIMARY KEY)

    INSERT INTO #betTypesTemp (bettype)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@BetTypes, ',')
	WHERE value <> ''
		
	IF @ProductId = 27 --VS2
		 INSERT INTO #betTypesTemp (bettype) VALUES (2799)
	IF @ProductId = 83 --VS4
		 INSERT INTO #betTypesTemp (bettype) VALUES (10449)
	IF @ProductId = 88 --VS5
		INSERT INTO #betTypesTemp (bettype) VALUES (11099)
		
    SELECT b.typeid AS Id
         , b.typenamee AS Name
    FROM #betTypesTemp tb
		INNER JOIN bettype b WITH(NOLOCK) ON tb.bettype = b.typeid    
    GROUP BY b.typeid, b.typenamee
    ORDER BY b.typenamee

    DROP TABLE #betTypesTemp
END
GO