/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ResultSettingChecking
	@MatchId	INT
	,@Action	VARCHAR(20)
	,@SelectedResources VARCHAR(MAX) = ''
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	VARCHAR(200) = '' OUTPUT
AS
/*
	Created by: 20210811@Louisa
	Task	: Check Confirm Refund setting [Redmine:#159270]
	DB		: DBPRO/bodb02
	Param's Explanation:
		  @SelectedResources: <Resources>
						    	<Resource Id="M1" Home="1" Away="3" />
						    	<Resource Id="M2" Home="2" Away="4" />
						      </Resources>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Sporttype TINYINT
			,@handle INT
			,@ResultTable	TINYINT	= 0


	DECLARE @tmpResourceID	  TABLE ( ResourceID VARCHAR(20) )
	DECLARE @tmpResultSetting TABLE ( ResultSetting VARCHAR(20) )

	SELECT @Sporttype	= m.Sporttype FROM dbo.match m WITH(NOLOCK) where m.matchid = @MatchId
	SELECT @ResultTable = f.ResultTable FROM [dbo].[f_Set_SettingByProfile] (@Sporttype) f

	
	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

	INSERT INTO @tmpResourceID(ResourceID)
	SELECT DISTINCT Id	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20) ) AS tbl
	EXEC sp_xml_removedocument @handle

	IF @ResultTable = 1
	BEGIN
		
		INSERT INTO @tmpResultSetting (ResultSetting)
		SELECT DISTINCT r.ResultSetting
		FROM dbo.ResultDetail r WITH(NOLOCK)
			INNER JOIN @tmpResourceID tmp
				ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchId

	END
	
	IF @ResultTable = 2
	BEGIN
		
		INSERT INTO @tmpResultSetting (ResultSetting)
		SELECT DISTINCT r.ResultSetting
		FROM dbo.ResultDetailOS r WITH(NOLOCK)
			INNER JOIN @tmpResourceID tmp
				ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchId

	END

	IF @ResultTable = 3
	BEGIN
		
		INSERT INTO @tmpResultSetting (ResultSetting)
		SELECT DISTINCT r.ResultSetting
		FROM dbo.ResultDetailES r WITH(NOLOCK)
			INNER JOIN @tmpResourceID tmp
				ON r.ResourceId = tmp.ResourceID
		WHERE r.MatchId = @MatchId

	END

	IF @Action  LIKE 'Refund%'
		SELECT @ErrCode = 1001055
			 , @ErrMsg	= 'WARNING! Cannot continue due to selected results are not confirmed to refund. Please confirm refund and try again.'
		FROM @tmpResultSetting r WHERE r.ResultSetting & 2 = 0

	ELSE IF @Action LIKE 'CAL%'
		SELECT @ErrCode = 1001056
			 , @ErrMsg  = 'WARNING! Cannot continue due to selected results are confirmed to refund. Please undo-confirm refund and try again.'
		FROM @tmpResultSetting r WHERE r.ResultSetting & 2 = 2


END
GO