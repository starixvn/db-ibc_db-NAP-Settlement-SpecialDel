/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER FUNCTION dbo.f_Set_ExistFailedHoldResult(@Matchid INT)
RETURNS @Result TABLE
(
    matchid INT
    ,IsExistHoldResult INT
    ,ResourceID VARCHAR(20) NULL
	,TypeId INT NULL
)
AS
/*	Creator: 20251024@Hughie
	Task: Retry the Auto/Direct Payout flow for these failed matches after untick hold key
	DB: DBPRO/BODB02
	
	Revisions:
		- 20251024@Hughie: Create [Redmine:#240174]

	Param's Explanation:
 
*/
BEGIN
    DECLARE @Sporttype INT;		
    DECLARE @TEMP TABLE (AutoPayoutResultId INT, ResourceID VARCHAR(20) NULL, TypeId INT NULL);
    DECLARE @IsExistHoldResult INT = 0;
    DECLARE @ResourceID VARCHAR(20) = NULL;
	DECLARE @TypeId INT = NULL

    SELECT @Sporttype = m.sporttype
    FROM match m WITH (NOLOCK)
    WHERE m.matchid = @Matchid;

    IF @Sporttype = 1
    BEGIN
        INSERT INTO @TEMP (AutoPayoutResultId, TypeId, ResourceID)
        SELECT TOP 1 p.AutoPayoutResultId, p.CalculationType, p.ResourceId
        FROM AutoPayoutResult p WITH (NOLOCK)
        WHERE p.StatusId = 3
          AND p.Remark LIKE '%HOLD%'
          AND p.MatchId = @Matchid
        ORDER BY p.AutoPayoutResultId DESC;
    END
    ELSE IF @Sporttype <> 1
    BEGIN
        INSERT INTO @TEMP (AutoPayoutResultId, ResourceID)
        SELECT TOP 1 p.AutoPayoutResultId, p.ResourceID
        FROM AutoPayoutResultOS p WITH (NOLOCK)
        WHERE p.StatusId = 3
          AND p.Remark LIKE '%HOLD%'
          AND p.MatchId = @Matchid
        ORDER BY p.AutoPayoutResultId DESC;
    END

    IF EXISTS (SELECT 1 FROM @TEMP)
    BEGIN
        SELECT TOP 1 
            @IsExistHoldResult = 1
            ,@ResourceID = ResourceID
			,@TypeId = TypeId
        FROM @TEMP;
    END
    ELSE
    BEGIN
        SET @IsExistHoldResult = 0;
        SET @ResourceID = NULL;
		SET @TypeId = NULL;
    END

    INSERT INTO @Result (matchid, IsExistHoldResult, ResourceID, TypeId)
    VALUES (@Matchid, @IsExistHoldResult, @ResourceID, @TypeId);

    RETURN;
END
GO
