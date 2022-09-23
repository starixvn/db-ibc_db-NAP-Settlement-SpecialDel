/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MoveTicketChecking_Event] 
	@MatchId 				INT 
	,@DestinationMatchId	INT
	,@ErrCode 				INT = 0 OUTPUT
	,@ErrMsg 				NVARCHAR(200)	= '' OUTPUT
AS
/*
	Creator: 20220719@Louisa
	Task: Scale out DBTRANS [Redmine:#175251]
	DB: DBPRO/bodb02

	Revisions:
		- 20220719@Louisa: Scale out DBTRANS [Redmine:#175251]

*/

BEGIN

SET NOCOUNT ON
	
	DECLARE @Sporttype		SMALLINT 
 
	SET @Sporttype = 43 -- Currently, apply for ESports only

	DECLARE  @matchcode NVARCHAR(100), @leagueid INT, @homeid INT, @awayid INT, @eventdate DATETIME, @eventstatus NVARCHAR(100)
			 ,@des_leagueid INT, @des_homeid INT, @des_awayid INT, @des_eventdate DATETIME, @des_eventstatus NVARCHAR(100)

	SELECT	 @des_leagueid		= m.leagueid
			, @des_homeid		= m.homeid
			, @des_awayid		= m.awayid
			, @des_eventdate	= m.eventdate
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @DestinationMatchId
		AND m.sporttype = @Sporttype
		AND ISNULL(m.IsDeleted,0) = 0 
	
	SELECT	@ErrCode = CASE WHEN @matchcode IS NULL OR @matchcode LIKE 'betdaq%' OR @des_leagueid IS NULL THEN 1001001
							WHEN @eventstatus NOT IN ('closed','postponed','internal') THEN 1001058
							WHEN @leagueid <> @des_leagueid THEN 1001059
							WHEN @homeid <> @des_homeid OR @awayid <> @des_awayid THEN 1001060
							WHEN @eventdate <> @des_eventdate THEN 1001061
						ELSE NULL
						END
			,@ErrMsg = CASE WHEN @matchcode IS NULL OR @matchcode LIKE 'betdaq%' OR @des_leagueid IS NULL THEN 'Match does not exist!'
							WHEN @eventstatus NOT IN ('closed','postponed','internal') THEN 'WARNING! Cannot continue due to: Status of source match should be closed, postponed or internal'
							WHEN @leagueid <> @des_leagueid THEN  'WARNING! Cannot continue due to: Matches should be in same league'
							WHEN @homeid <> @des_homeid OR @awayid <> @des_awayid THEN 'WARNING! Cannot continue due to: Team names of matches should be the same'
							WHEN @eventdate <> @des_eventdate THEN  'WARNING! Cannot continue due to: Eventdate of matches should be the same'
						ELSE NULL
						END
			
	IF @ErrCode > 0
	RETURN

	IF EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH(NOLOCK) WHERE m.ParentID IS NOT NULL AND m.ParentID = @MatchId AND ISNULL(m.IsDeleted,0)  = 0 )
	BEGIN
		SELECT @ErrCode = 1001062
				, @ErrMsg = 'WARNING! Cannot continue due to: Source Match is having child match'
		RETURN
	END

END
GO