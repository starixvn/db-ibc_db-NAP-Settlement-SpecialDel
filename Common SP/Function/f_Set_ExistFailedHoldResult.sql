/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="1"></info>*/
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
    DECLARE @Sporttype INT	
    DECLARE @TEMP TABLE (AutoPayoutResultId INT, ResourceID VARCHAR(20) NULL, TypeId INT NULL)
    DECLARE @IsExistHoldResult INT = 0
    DECLARE @ResourceID VARCHAR(20) = NULL
	DECLARE @TypeId INT = NULL

    SELECT @Sporttype = m.sporttype
    FROM match m WITH (NOLOCK)
    WHERE m.matchid = @Matchid;

    IF @Sporttype = 1
    BEGIN
        ;WITH LatestPerResource AS (
			SELECT
				p.AutoPayoutResultId
				,p.MatchId
				,p.ResourceID
				,p.StatusId
				,p.Remark
				,p.CalculationType
				,ROW_NUMBER() OVER (
					PARTITION BY ( CASE WHEN p.CalculationType IN (1,2) THEN CAST(p.CalculationType AS VARCHAR(10)) ELSE p.ResourceID END)
					ORDER BY p.AutoPayoutResultId DESC
				) AS rn
			FROM AutoPayoutResult p WITH (NOLOCK)
			WHERE p.MatchId = @Matchid
		)
		INSERT INTO @TEMP (AutoPayoutResultId, ResourceID, TypeId)
		SELECT
			AutoPayoutResultId
			,ResourceID
			,CalculationType
		FROM LatestPerResource
		WHERE rn = 1
		  AND StatusId = 3
		  AND Remark LIKE '%HOLD%';
    END
    ELSE IF @Sporttype <> 1
    BEGIN
       ;WITH LatestPerResource AS (
			SELECT
				p.AutoPayoutResultId,
				p.MatchId,
				p.ResourceID,
				p.StatusId,
				p.Remark,
				ROW_NUMBER() OVER (
					PARTITION BY p.ResourceID
					ORDER BY p.AutoPayoutResultId DESC
				) AS rn
			FROM AutoPayoutResultOS p WITH (NOLOCK)
			WHERE p.MatchId = @Matchid
		)
		INSERT INTO @TEMP (AutoPayoutResultId, ResourceID)
		SELECT
			AutoPayoutResultId,
			ResourceID
		FROM LatestPerResource
		WHERE rn = 1
		  AND StatusId = 3
		  AND Remark LIKE '%HOLD%';
    END

    IF EXISTS (SELECT 1 FROM @TEMP)
    BEGIN
        SELECT
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
	SELECT @Matchid, @IsExistHoldResult, a.ResourceID, a.TypeId
	FROM @TEMP a

    RETURN;
END
GO
