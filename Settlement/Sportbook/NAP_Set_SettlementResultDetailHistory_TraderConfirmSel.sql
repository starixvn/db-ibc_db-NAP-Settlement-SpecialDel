/*<info serverAlias="DBTP-bodb02" executers="wsv_nap" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROC [dbo].[NAP_Set_SettlementResultDetailHistory_TraderConfirmSel]
	 @MatchID				INT 
	,@ResourceIDs			VARCHAR(MAX) = ''
	,@LatestRecord			BIT			 = 0
AS
/*
    Created by: 20240307@Aries
    Task: Provider Result Log [Redmine:#201462]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20240307@Aries: Enhance the Provider Result Logs Phase 2 [Redmine: #201480]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @Sporttype				SMALLINT
			,@ResultTable			TINYINT

	CREATE TABLE #tmpResourceID (ResourceID VARCHAR(20), PRIMARY KEY (ResourceId) WITH (IGNORE_DUP_KEY = ON))
	CREATE TABLE #Confirm(ResourceId VARCHAR(20), HomeValue VARCHAR(50),AwayValue VARCHAR(50), CreateDate DATETIME,ResultStatusID TINYINT)

	SELECT @Sporttype = m.Sporttype
	FROM match AS m WITH(NOLOCK)
	WHERE m.matchid = @MatchID

	SELECT @ResultTable			= ResultTable
	FROM SettlementResultTableSetting AS st WITH(NOLOCK)
	WHERE st.Sporttype = @Sporttype


	INSERT INTO #tmpResourceID(ResourceID)
	SELECT f.value
	FROM STRING_SPLIT(@ResourceIDs, ',') AS f 


	IF @ResultTable = 1
	BEGIN
		INSERT INTO #Confirm(ResourceId,HomeValue,AwayValue,CreateDate,ResultStatusID)
		SELECT   rd.ResourceId
				,rd.HomeValue
				,rd.AwayValue
				,rd.LastModifyDate
				,rd.ResultStatusID
		FROM ResultDetail AS rd  WITH(NOLOCK)
			LEFT JOIN  #tmpResourceID AS r ON rd.ResourceID =  r.ResourceID  
		WHERE  rd.matchID = @MatchID
			AND rd.ResultStatusID = 3
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END 
	END
	ELSE IF @ResultTable = 2
	BEGIN
		INSERT INTO #Confirm(ResourceId,HomeValue,AwayValue,CreateDate,ResultStatusID)
		SELECT   rd.ResourceId
				,rd.HomeValue
				,rd.AwayValue
				,rd.LastModifyDate
				,rd.ResultStatusID
		FROM ResultDetailOS AS rd  WITH(NOLOCK)
			LEFT JOIN  #tmpResourceID AS r ON rd.ResourceID =  r.ResourceID
		WHERE rd.matchID = @MatchID
			AND rd.ResultStatusID = 3
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
	END
	ELSE IF @ResultTable = 3
	BEGIN
		INSERT INTO #Confirm(ResourceId,HomeValue,AwayValue,CreateDate,ResultStatusID)
		SELECT   rd.ResourceId
				,rd.HomeValue
				,rd.AwayValue
				,rd.LastModifyDate
				,rd.ResultStatusID
		FROM ResultDetailES AS rd  WITH(NOLOCK)
			LEFT JOIN  #tmpResourceID AS r ON rd.ResourceID =  r.ResourceID
		WHERE rd.matchID = @MatchID
			AND rd.ResultStatusID = 3
			AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						 WHEN r.ResourceID IS NOT NULL		THEN 1
						 ELSE 0
					END
	END

    ;WITH CTE AS (
        SELECT tbl.ResourceId
		      ,tbl.HomeValue
		      ,tbl.AwayValue
		      ,tbl.ResultStatusID
		      ,tbl.CreateDate
              ,ROW_NUMBER() OVER (PARTITION BY tbl.ResourceId ORDER BY tbl.CreateDate DESC)  AS RankNo 
        FROM (
		    SELECT h.ResourceId
			      ,h.NewHomeValue AS HomeValue
			      ,h.NewAwayValue AS AwayValue
			      ,h.NewResultStatusID AS ResultStatusID
			      ,h.NewLastModifiedDate AS CreateDate
		    FROM  SettlementResultDetailHistory AS h WITH(NOLOCK)
			    LEFT JOIN #tmpResourceID AS r ON r.ResourceId = h.ResourceId
		    WHERE h.matchID = @MatchID
			    AND h.NewResultStatusID = 3 
			    AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						     WHEN r.ResourceID IS NOT NULL		THEN 1
						     ELSE 0
					    END 

		    UNION 

		    SELECT h.ResourceId
			      ,h.OldHomeValue AS HomeValue
			      ,h.OldAwayValue AS AwayValue
			      ,h.OldResultStatusID AS ResultStatusID
			      ,h.OldLastModifiedDate AS CreateDate
		    FROM  SettlementResultDetailHistory AS h WITH(NOLOCK)
			    LEFT JOIN #tmpResourceID AS r ON  r.ResourceId = h.ResourceId
		    WHERE h.matchID = @MatchID
			    AND h.OldResultStatusID = 3
			    AND 1 = CASE WHEN ISNULL(@ResourceIDs,'') = ''	THEN 1
						     WHEN r.ResourceID IS NOT NULL		THEN 1
						     ELSE 0
					    END 

		    UNION

		    SELECT c.ResourceId
			      ,c.HomeValue
			      ,c.AwayValue
			      ,c.ResultStatusID
			      ,c.CreateDate
		    FROM  #Confirm AS c WITH(NOLOCK)
	    ) AS tbl 
    )
    SELECT  ResourceId
		   ,HomeValue
		   ,AwayValue
		   ,ResultStatusID
		   ,CreateDate
	FROM CTE
    WHERE 1 = CASE WHEN @LatestRecord  = 1 AND RankNo = 1 THEN 1
				   WHEN @LatestRecord = 0				  THEN 1
				   ELSE 0
			  END
END
GO