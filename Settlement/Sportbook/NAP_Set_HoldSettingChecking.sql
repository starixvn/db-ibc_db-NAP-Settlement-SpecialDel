/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_HoldSettingChecking
	@MatchId	INT
	,@Action	VARCHAR(20) = 'CAL'
	,@IsEarly	BIT = 0
	,@SelectedResources VARCHAR(MAX) = ''
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	VARCHAR(200) = '' OUTPUT
AS
/*
	Created by: 20201111@Louisa
	Task	: Check Hold setting [Redmine:#143441]
	DB		: DBPRO/bodb02

	Revisions:
		-  20201111@Louisa: Check Hold setting [Redmine:#143441]
		-  20201113@Louisa: Check Hold Result [Redmine:#135097]
		-  20210122@Louisa: Cricket AIO [Redmine:#148870]
		-  20210706@Louisa: Letstalk message [Redmine:#157540]
		-  20220629@Louisa: Volleyball AIO [Redmineid:#173862]
		-  20240807@Aries: Add hold match info [Redmineid:#200934]
		- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]
		
	Parameters Explanation:    
		@IsEarly = 0 : Check dbo.Match.SettlementStatus bit[1]-Pending, bit[2]-Undecided, bit[3]-UnderSettlement, bit[5]-MTDHold, bit[7]-Hold Key
		@IsEarly = 1 : Check dbo.Match.SettlementStatus bit 1,2,3,5,7 and check ResultSetting dbo.ResultDetail/ES/OS    

		@SelectedResources
			<Resources>
				<Resource Id="" Home="" Away="" />
				<Resource Id="" Home="" Away="" />
			</Resources>
		
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @SettlementStatus TINYINT
			,@SportType TINYINT
			,@handle INT
			,@ParentMatchId	INT
			,@ResultTable		TINYINT	= 0	

	SELECT @SportType = m.Sporttype 
			,@SettlementStatus = m.SettlementStatus
			,@ParentMatchId = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULl AND m.sporttype IN (8, 50) THEN m.ParentID ELSE NULL END
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.Matchid =  @MatchId
	
	IF @ParentMatchId IS NOT NULL -- child match of cricket
		RETURN

	IF @SettlementStatus & 87 > 0
	BEGIN
		SET	@ErrCode = 1001038	
		SET @ErrMsg = 'WARNING! Cannot continue due to the match is put on hold. Please unhold and try again.	'
	END

	-- Soccer, Basketball, Badminton, and E-Sports.
	ELSE IF @IsEarly = 1 AND ISNULL(@SelectedResources,'') <> ''
	BEGIN	
		
		IF @SportType NOT IN ( 1, 2, 6, 9, 50, 43 )
		RETURN 

		SELECT @ResultTable =  r.ResultTable 
		FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK) 
		WHERE r.Sporttype = @SportType

		DECLARE @tmpResourceID TABLE ( ResourceID VARCHAR(20) )
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

		INSERT INTO @tmpResourceID(ResourceID)
		SELECT DISTINCT Id	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20) ) AS tbl
		EXEC sp_xml_removedocument @handle

		 ----Soccer, Basketball
		IF @ResultTable = 1
		BEGIN
			SELECT @ErrMsg = 'WARNING! Cannot continue due to selected results are on hold. Please recheck and try again. ResourceIDs: ' + STRING_AGG(CONVERT(VARCHAR(MAX),r.ResourceId),',')	
			FROM ResultDetail r WITH(NOLOCK)
				INNER JOIN @tmpResourceID rs
					ON r.ResourceId = rs.ResourceID
			WHERE r.MatchId  = @MatchId
				AND ISNULL(r.ResultSetting,0) & 1 = 1 
		END

		---- Badminton
		ELSE IF @ResultTable = 2
		BEGIN
			SELECT @ErrMsg = 'WARNING! Cannot continue due to selected results are on hold. Please recheck and try again. ResourceIDs: ' + STRING_AGG(CONVERT(VARCHAR(MAX),r.ResourceId),',')	
			FROM ResultDetailOS r WITH(NOLOCK)
				INNER JOIN @tmpResourceID rs
					ON r.ResourceId = rs.ResourceID
			WHERE r.MatchId  = @MatchId
				AND ISNULL(r.ResultSetting,0) & 1 = 1 
		END

		----E-Sports
		ELSE IF @ResultTable = 3
		BEGIN
			SELECT @ErrMsg = 'WARNING! Cannot continue due to selected results are on hold. Please recheck and try again. ResourceIDs: ' + STRING_AGG(CONVERT(VARCHAR(MAX),r.ResourceId),',')	
			FROM ResultDetailES r WITH(NOLOCK)
			INNER JOIN @tmpResourceID rs
				ON r.ResourceId = rs.ResourceID
			WHERE r.MatchId  = @MatchId
				AND ISNULL(r.ResultSetting,0) & 1 = 1 
		END

		IF @ErrMsg IS NOT NULL AND @ErrMsg != ''
		BEGIN
			SET @ErrCode = 1001039 
		END
	END

END
GO