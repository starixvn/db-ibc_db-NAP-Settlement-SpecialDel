/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_MP
(
	 @matchids		VARCHAR(500) = ''
	,@Action		VARCHAR(10)
	,@Mode			VARCHAR(10)
	,@ErrCode		INT		= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''   OUTPUT
	,@MatchIdsOutPut	VARCHAR(500) = '' OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before call SP MP_Push  [Redmine:#175251]

	Param's Explanation:

*/

BEGIN
SET NOCOUNT ON

			DECLARE @NotAllowCalculating VARCHAR(200)
			,@HaveWaitingTicket VARCHAR(200)
			,@matchcode nvarchar(50)

			,@MovingMatchIds VARCHAR(MAX) 
			,@InvalidMatchIds VARCHAR(MAX) = ''
			,@HoldSettingMatchIds VARCHAR(200) = ''
			,@ParentIds VARCHAR(MAX) = ''
								 
		Create table #Match (matchid INT
							  ,matchcode NVARCHAR(50)
							  ,sporttype SMALLINT
							  ,SettlementStatus	TINYINT
							  ,ParentId INT )

		INSERT INTO #Match ( matchid, matchcode, sporttype, SettlementStatus, ParentId)
		SELECT matchid
			,matchcode
			,sporttype
			,ISNULL(SettlementStatus,0) SettlementStatus
			,CASE WHEN ISNULL(ChildMatchType,0) = 200 AND m.ParentId IS NOT NULL AND m.sporttype = 50 THEN m.ParentId ELSE m.MatchId END ParentId
		FROM DBPRO.bodb02.dbo.Match m WITH (NOLOCK)
			INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , ',')) tm
				ON m.matchid = tm.value		

		SELECT @ParentIds =  COALESCE(@ParentIds + ',' + CAST(m.ParentId AS varchar),  CAST(ParentId AS varchar)) from #Match m 	
		SELECT @ParentIds = STUFF(@ParentIds, 1, 1, '')

		SELECT @HoldSettingMatchIds = COALESCE(@HoldSettingMatchIds + ',' + m.matchcode, m.matchcode)
		FROM	#Match m
		WHERE m.SettlementStatus & 87 > 0

		DELETE FROM #Match
		WHERE	SettlementStatus & 87 > 0

		IF EXISTS (SELECT 1
				FROM #Match
				WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1))
				OR matchid IN (SELECT matchid from Parlay_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1)) )
		BEGIN
			SELECT @NotAllowCalculating = COALESCE(@NotAllowCalculating + ',' + matchcode, matchcode)
			FROM #Match 
			WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
			OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 

			-- exclude matches were not allow to calculate
			DELETE
			FROM #Match
			WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
			OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 
		END

		-- check movebet day MP
		EXEC dbo.NAP_Admin_Settlement_CheckingMoveBetDay
			@MatchIds =  @matchids 
			,@MovingMatchIds = @InvalidMatchIds OUTPUT
	
		SELECT	@MovingMatchIds = COALESCE(@MovingMatchIds + ',' + m.matchcode, m.matchcode)
		FROM	dbo.match m WITH(NOLOCK)
					INNER JOIN (SELECT [value] FROM STRING_SPLIT(@InvalidMatchIds, ',')) tm
						ON m.matchid = tm.value 
	
		DELETE FROM #Match
		WHERE	matchid IN (SELECT [value] FROM STRING_SPLIT(@InvalidMatchIds, ','))

		-- check waiting ticket
		EXEC [NAP_Admin_Settlement_Checking] 		@MatchIds = @MatchIds	OUTPUT
			,@Action = @Action
			,@Mode = 'CAL-MP'	
	
		SELECT @HaveWaitingTicket = COALESCE(@HaveWaitingTicket + ',' + m.matchcode, m.matchcode)
		FROM dbo.match m WITH(NOLOCK)
				INNER JOIN (SELECT [value] FROM STRING_SPLIT(@MatchIds, ',')) tm
					ON m.matchid = tm.value
	
		DELETE FROM #Match
		WHERE matchid IN (SELECT [value] FROM STRING_SPLIT(@MatchIds, ','))
	
		IF ( ISNULL(@HoldSettingMatchIds,'') <> '' or ISNULL(@NotAllowCalculating,'') <> '' OR ISNULL(@HaveWaitingTicket,'') <> '' OR ISNULL(@MovingMatchIds,'') <> '' )
		BEGIN
			SELECT   @ErrCode = 1001011
					,@ErrMsg = 'All matches are being calculated, except following matches ' 
								+ CASE WHEN ISNULL(@HoldSettingMatchIds, '') <> ''
										THEN '(on hold): ' + STUFF(@HoldSettingMatchIds, 1, 1, '')
										ELSE ''
									END
								+ CASE when ISNULL(@NotAllowCalculating,'') <> ''
										THEN  ' (being calculated by another user): ' + @NotAllowCalculating
										ELSE ''
									END 
								+ CASE WHEN ISNULL(@HaveWaitingTicket, '') <> ''
										THEN ' (existing some PENDING tickets): ' + @HaveWaitingTicket
										ELSE ''
									END			
								+ CASE WHEN ISNULL(@MovingMatchIds, '') <> ''
										THEN ' (during move-bet progress): ' + @MovingMatchIds + '. Please contact Starix IT for further support!'
										ELSE ''
									END

							
			END

	SELECT @MatchIdsOutPut =  @MatchIdsOutPut + ',' + Matchid FROM #Match
	SET @MatchIdsOutPut = SUBSTRING(@MatchIdsOutPut, 2, LEN(@MatchIdsOutPut))

END
GO