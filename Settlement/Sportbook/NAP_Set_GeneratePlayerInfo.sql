/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_GeneratePlayerInfo
	@MatchId	  INT
	,@ResourceIds VARCHAR(MAX) =''
	,@ErrCode	  INT				= 0		OUTPUT
	,@ErrMsg	  NVARCHAR(200)	= ''	OUTPUT
AS
/*
    Created by: 20250822@Louisa
    Task: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
    
    Revisions:            
		- 20250822@Louisa: Generate result for bettype player of basketball if not exists data in odds_flex [Redmine:#233012]

*/
BEGIN

	SET NOCOUNT ON 

	DECLARE @sporttype SMALLINT 

	SELECT @sporttype = m.sporttype FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId
	
	IF @Sporttype <> 2
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = 'Invalid sporttype!'
	RETURN
	END

	DECLARE @tmp_ResourceWeb TABLE(ResourceID VARCHAR(50))
	DECLARE @tmp_ResourceFormat TABLE (ResourceName VARCHAR(20), ResourceFormat VARCHAR(3) )
	DECLARE @tmp_Offer TABLE ( ResourceID VARCHAR(50), RelatedBettype VARCHAR(200), PlayerId VARCHAR(20), TeamId VARCHAR(20), PlayerRank TINYINT, OddsInfo VARCHAR(500) )
	DECLARE @tmp_MainResource TABLE ( MainResourceID VARCHAR(50), RelatedBettype VARCHAR(3), PlayerId VARCHAR(20), TeamId VARCHAR(20), PlayerRank TINYINT, OddsInfo VARCHAR(500) )
	DECLARE @tmp_Generate TABLE ( ResourceID VARCHAR(50), OtherInfo VARCHAR(50) )

	INSERT INTO  @tmp_ResourceWeb (ResourceID )
	SELECT DISTINCT v.value FROM string_split(@ResourceIds,',')v

	INSERT INTO @tmp_ResourceFormat (ResourceName, ResourceFormat)
	VALUES ( '"points"'		 , '653')
		  ,( '"assists"'	 , '656')
		  ,( '"rebounds"'	 , '659')
		  ,( '"three_points"', '662')
		  ,( '"blocks"'		 , '665')
		  ,( '"steals"'		 , '667')

	BEGIN TRY
		---Offer
		;WITH cte_offer (ResourceID, RelatedBettype, PlayerId, TeamId, OddsInfo)
		AS (SELECT	DISTINCT s.ResourceID
				,JSON_VALUE(s.APSetting,'$."relatedBettype"') AS RelatedBettype
				,JSON_VALUE(f.OddsInfo,'$."pid"') AS PlayerId 
				,JSON_VALUE(f.OddsInfo,'$."tid"') AS TeamId 
				,f.OddsInfo
			FROM	dbo.odds o WITH(NOLOCK)
				INNER JOIN dbo.odds_flex f WITH(NOLOCK)
					ON o.oddsid = f.oddsid
				INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCk)
						ON o.bettype = s.BetType
			WHERE	s.SportType = 2
					AND s.SettleType = 'EAR'
					AND (s.betid = 0 
							OR ( s.bettype NOT IN (675,676,678 ) AND s.ResourceID LIKE '%' + CAST(o.Resourceid AS VARCHAR)) 
							OR ( s.bettype IN (675,676,678 ) AND s.ResourceID = CAST(o.bettype AS VARCHAR(3)) + o.ResourceID + f.betChoice )
						)
					AND	o.matchid = @MatchId
					AND ISNULL(o.IsDeleted,0) = 0
					AND ISNULL(f.IsDeleted,0) = 0
		)

		INSERT INTO @tmp_Offer ( ResourceID, RelatedBettype, PlayerId, TeamId, PlayerRank, OddsInfo)
		SELECT ResourceID, RelatedBettype, PlayerId, TeamId
			  ,DENSE_RANK() OVER(ORDER BY cte.PlayerId ASC)
			  ,OddsInfo
		FROM cte_offer cte
		
		---keep base bettype has ticket and related bettype
		DELETE o
		FROM @tmp_Offer o 
				LEFT JOIN @tmp_ResourceWeb w
				ON o.ResourceID =w.ResourceID
		WHERE w.ResourceID IS NULL AND ISNULL(o.RelatedBettype,'') <> '' 
	
		--bettype has related			
		INSERT INTO @tmp_MainResource ( MainResourceID, RelatedBettype, PlayerId, TeamId, PlayerRank, OddsInfo )	
		SELECT DISTINCT o.ResourceID	
				,v.RelatedBettype	
				,o.PlayerId 
				,o.TeamId
				,PlayerRank
				,o.OddsInfo
		FROM @tmp_Offer o
			CROSS APPLY (SELECT v.value AS RelatedBettype FROM STRING_SPLIT(RelatedBettype, ',')v)v
		WHERE ISNULL(o.RelatedBettype,'') <> ''

		DELETE m
		FROM @tmp_MainResource m
		WHERE m.RelatedBettype = 0 ---fulltime
			OR EXISTS (SELECT 1 FROM @tmp_Offer o WHERE ISNULL(o.RelatedBettype,'') = '' AND o.PlayerId = m.PlayerId AND LEFT(o.ResourceID,3) = m.RelatedBettype  )
	 
		DELETE m
		FROM @tmp_MainResource m
			LEFT JOIN @tmp_ResourceFormat f
				ON m.RelatedBettype = f.ResourceFormat
					AND CASE WHEN m.MainResourceID lIKE '680__' THEN  '"points"'	
							 WHEN m.MainResourceID lIKE '681__' THEN  '"rebounds"'
							 WHEN m.MainResourceID lIKE '682__' THEN '"steals"'
							 WHEN m.MainResourceID lIKE '683__' THEN '"assists"'
							 WHEN m.MainResourceID lIKE '684__' THEN '"three_points"'
							 WHEN m.MainResourceID lIKE '677__' OR m.MainResourceID lIKE '679__' THEN  '"points","rebounds","steals","assists","blocks"'
							 WHEN m.MainResourceID lIKE '669__' THEN  '"points","rebounds","assists"'
							 WHEN m.MainResourceID lIKE '671__' THEN  '"rebounds","assists"'
							 WHEN m.MainResourceID lIKE '673__' THEN  '"points","rebounds"'
							 WHEN m.MainResourceID lIKE '674__' THEN  '"steals","blocks"'
							ELSE m.OddsInfo
							END LIKE '%' + f.ResourceName +'%'
		WHERE f.ResourceFormat IS NULL

		INSERT INTO @tmp_Generate	 ( ResourceID, OtherInfo)
		SELECT DISTINCT m.RelatedBettype + CAST(41-PlayerRank AS VARCHAR(2) ), PlayerId +',' + TeamId
		FROM @tmp_MainResource m
	
		INSERT INTO ResultDetail (MatchId,ResourceId,HomeValue,AwayValue,ResultStatusID,SettlementStatusID,CreateDate,LastModifyDate,CreateBy,LastModifyBy,OtherInfo	)
		SELECT @MatchId,tmp.ResourceId,NULL,NULL,0,0,GETDATE(),GETDATE(),0,0,tmp.OtherInfo
		FROM @tmp_Generate tmp
			LEFT JOIN dbo.ResultDetail r WITH(NOLOCK) 
				ON  r.MatchId = @matchid AND r.ResourceId = tmp.ResourceId
		WHERE r.ResourceId IS NULL

	END TRY

	BEGIN CATCH
		SELECT  @ErrMsg	= ISNULL(ERROR_MESSAGE(),'')
				,@ErrCode= ERROR_MESSAGE()
				
	END CATCH
END
 